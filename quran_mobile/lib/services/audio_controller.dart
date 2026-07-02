import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app/prefs.dart';
import '../core/arabic_text.dart';
import '../data/models.dart';
import '../data/reciters.dart';

/// حالة التلاوة.
class AudioState {
  final bool playing;
  final bool busy; // جاري تحميل الملف
  final (int surah, int ayah)? current;
  final String status;

  const AudioState({
    this.playing = false,
    this.busy = false,
    this.current,
    this.status = '',
  });

  AudioState copyWith({
    bool? playing,
    bool? busy,
    (int, int)? current,
    bool clearCurrent = false,
    String? status,
  }) =>
      AudioState(
        playing: playing ?? this.playing,
        busy: busy ?? this.busy,
        current: clearCurrent ? null : (current ?? this.current),
        status: status ?? this.status,
      );
}

/// مشغّل التلاوة: تحميل مسبق لملف الآية ثم تشغيل محلي (أوفلاين بعد أول مرة)،
/// متسلسل عبر آيات الصفحة — نفس سلوك سطح المكتب.
class AudioController extends Notifier<AudioState> {
  final _player = AudioPlayer();
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
  List<Ayah> _queue = const [];
  int _idx = 0;
  int _session = 0; // يبطل التشغيلات القديمة عند إيقاف/تغيير

  @override
  AudioState build() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _next();
    });
    ref.onDispose(() => _player.dispose());
    return const AudioState();
  }

  Reciter get _reciter => Reciter.byName(ref.read(prefsProvider).reciterName);

  Future<String> _audioDir(String folder) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'audio', folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  /// يضمن وجود ملف الآية محلياً (ينزّله إن لزم) ويرجع مساره.
  Future<String> _ensure(Reciter r, int surah, int ayah) async {
    final dir = await _audioDir(r.folder);
    final path = p.join(dir,
        '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3');
    final f = File(path);
    if (!f.existsSync() || f.lengthSync() == 0) {
      await _dio.download(r.urlFor(surah, ayah), path);
    }
    return path;
  }

  /// يشغّل آيات الصفحة من آية معيّنة (الافتراضي: أولها).
  Future<void> playAyahs(List<Ayah> ayahs, {int startIndex = 0}) async {
    if (ayahs.isEmpty) return;
    _queue = List.of(ayahs);
    _idx = startIndex.clamp(0, ayahs.length - 1);
    _session++;
    await _playCurrent();
  }

  /// أثناء التلاوة: الانتقال لآية ضمن قائمة التشغيل الحالية.
  Future<void> jumpTo(int surah, int ayah) async {
    if (!state.playing && !state.busy) return;
    final i = _queue.indexWhere(
        (a) => a.surahNumber == surah && a.numberInSurah == ayah);
    if (i < 0) return;
    _idx = i;
    _session++;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final session = _session;
    final a = _queue[_idx];
    state = state.copyWith(
      busy: true,
      playing: true,
      current: (a.surahNumber, a.numberInSurah),
      status: 'جاري تحميل ${a.surahName} ${a.numberInSurah}…',
    );
    try {
      final path = await _ensure(_reciter, a.surahNumber, a.numberInSurah);
      if (session != _session) return; // أُلغي أثناء التحميل
      await _player.setFilePath(path);
      state = state.copyWith(
          busy: false,
          status: 'يُتلى: ${a.surahName} ﴿${toArabicDigits(a.numberInSurah)}﴾');
      await _player.play();
    } catch (_) {
      if (session != _session) return;
      state = state.copyWith(
          busy: false, playing: false, clearCurrent: true,
          status: 'تعذّر تحميل الصوت — تحقّق من الإنترنت');
    }
  }

  Future<void> _next() async {
    if (_idx + 1 >= _queue.length) {
      await stop(message: 'انتهت تلاوة الصفحة');
      return;
    }
    _idx++;
    _session++;
    await _playCurrent();
  }

  Future<void> stop({String message = ''}) async {
    _session++;
    await _player.stop();
    state = AudioState(status: message);
  }
}

final audioProvider = NotifierProvider<AudioController, AudioState>(AudioController.new);
