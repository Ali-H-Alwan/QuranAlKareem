import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app/prefs.dart';
import '../core/arabic_text.dart';
import '../data/models.dart';
import '../data/reciters.dart';
import '../data/surah_reciters.dart';

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
      // مصدر بوسم MediaItem: يُظهر التلاوة بإشعار الوسائط ويبقيها والشاشة مطفأة.
      await _player.setAudioSource(AudioSource.uri(
        Uri.file(path),
        tag: MediaItem(
          id: '${a.surahNumber}:${a.numberInSurah}',
          album: 'الباحث القرآني',
          title: '${a.surahName} — الآية ${toArabicDigits(a.numberInSurah)}',
          artist: _reciter.name,
        ),
      ));
      state = state.copyWith(
          busy: false,
          status: 'يُتلى: ${a.surahName} ﴿${toArabicDigits(a.numberInSurah)}﴾');
      _prefetchAhead(); // حمّل الآيات التالية أثناء التلاوة — انتقال بلا انقطاع
      await _player.play();
    } catch (_) {
      if (session != _session) return;
      state = state.copyWith(
          busy: false, playing: false, clearCurrent: true,
          status: 'تعذّر تحميل الصوت — تحقّق من الإنترنت');
    }
  }

  /// يحمّل الآيات التالية مسبقاً بالخلفية أثناء التلاوة —
  /// فيكون ملف الآية القادمة جاهزاً لحظة انتهاء الحالية (بلا انقطاع).
  void _prefetchAhead({int count = 2}) {
    for (var i = _idx + 1; i <= _idx + count && i < _queue.length; i++) {
      final a = _queue[i];
      _ensure(_reciter, a.surahNumber, a.numberInSurah).ignore();
    }
  }

  Future<void> _next() async {
    if (_queue.isEmpty) {
      await stop(message: 'انتهت السورة'); // وضع السورة الكاملة
      return;
    }
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

  // ═══ وضع «السورة الكاملة» (MP3Quran) ═══

  /// يشغّل السورة كاملة: بثّ فوري مع تخزين أثناء التشغيل (يعمل أوفلاين لاحقاً).
  Future<void> playSurah(int surah, String surahName) async {
    _queue = const [];
    _session++;
    final r = SurahReciter.byName(ref.read(prefsProvider).surahReciterName);
    state = state.copyWith(
        busy: true, playing: true, clearCurrent: true,
        status: 'سورة كاملة: $surahName — ${r.name}');
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'audio_surah', r.cacheFolder));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final cache = File(p.join(dir.path, '${surah.toString().padLeft(3, '0')}.mp3'));

      // ignore: experimental_member_use — آلية التخزين أثناء البثّ الموثّقة في just_audio
      await _player.setAudioSource(LockCachingAudioSource(
        Uri.parse(r.urlFor(surah)),
        cacheFile: cache,
        tag: MediaItem(
          id: 'surah:$surah',
          album: 'الباحث القرآني',
          title: 'سورة $surahName',
          artist: r.name,
        ),
      ));
      state = state.copyWith(busy: false);
      await _player.play();
    } catch (_) {
      state = state.copyWith(
          busy: false, playing: false,
          status: 'تعذّر تشغيل السورة — تحقّق من الإنترنت');
    }
  }
}

final audioProvider = NotifierProvider<AudioController, AudioState>(AudioController.new);
