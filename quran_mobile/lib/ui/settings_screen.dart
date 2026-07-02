import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app/prefs.dart';
import '../data/reciters.dart';
import '../services/audio_controller.dart';

const _green = Color(0xFF0E5A3C);

/// شاشة الإعدادات: الخط والحجم والقارئ وإدارة الصوت المحمَّل.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  (int files, double mb)? _audioStats;

  @override
  void initState() {
    super.initState();
    _refreshAudioStats();
  }

  Future<void> _refreshAudioStats() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'audio'));
    var files = 0;
    var bytes = 0;
    if (dir.existsSync()) {
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        files++;
        bytes += f.lengthSync();
      }
    }
    if (mounted) setState(() => _audioStats = (files, bytes / 1048576));
  }

  Future<void> _clearAudio() async {
    await ref.read(audioProvider.notifier).stop();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'audio'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await _refreshAudioStats();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف كل ملفات الصوت')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── الخط ──
        _card(
          title: '🖋 خط المصحف',
          child: Column(
            children: [
              for (final e in quranFonts.entries)
                RadioListTile<String>(
                  value: e.value,
                  // ignore: deprecated_member_use
                  groupValue: prefs.fontFamily,
                  activeColor: _green,
                  title: Text(e.key, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                    style: TextStyle(fontFamily: e.value, fontSize: 20, height: 1.8),
                  ),
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v != null) ref.read(prefsProvider.notifier).setFont(v);
                  },
                ),
              Row(
                children: [
                  const Text('حجم الخط:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: prefs.fontSize,
                      min: 14, max: 40, divisions: 13,
                      activeColor: _green,
                      label: prefs.fontSize.round().toString(),
                      onChanged: (v) => ref.read(prefsProvider.notifier).setFontSize(v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── الأرقام ──
        _card(
          title: '🔢 نمط الأرقام',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أرقام الآيات والصفحات والمواقيت في كل التطبيق:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('عربية  ٠١٢٣٤٥')),
                  ButtonSegment(value: false, label: Text('إنكليزية  012345')),
                ],
                selected: {prefs.arabicDigits},
                onSelectionChanged: (s) =>
                    ref.read(prefsProvider.notifier).setArabicDigits(s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _green,
                  selectedForegroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // ── التلاوة ──
        _card(
          title: '🎧 التلاوة',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('القارئ الافتراضي:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              DropdownButton<String>(
                value: Reciter.byName(prefs.reciterName).name,
                isExpanded: true,
                items: [
                  for (final r in Reciter.all)
                    DropdownMenuItem(value: r.name, child: Text(r.name)),
                ],
                onChanged: (v) {
                  if (v != null) ref.read(prefsProvider.notifier).setReciter(v);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _audioStats == null
                    ? 'جاري حساب الصوت المحمَّل…'
                    : 'الصوت المحمَّل: ${_audioStats!.$1} ملفاً (${_audioStats!.$2.toStringAsFixed(1)} م.ب)',
                style: const TextStyle(color: _green, fontSize: 12),
              ),
              const SizedBox(height: 6),
              FilledButton.tonal(
                onPressed: _clearAudio,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9A4A3A),
                    foregroundColor: Colors.white),
                child: const Text('🗑 حذف كل الصوت المحمَّل'),
              ),
              const SizedBox(height: 4),
              const Text(
                'يُحمَّل صوت كل آية أول مرة ثم يُشغَّل بدون إنترنت.\nالمصدر: everyayah.com',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),

        // ── حول ──
        _card(
          title: 'ℹ حول البرنامج',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الباحث القرآني — الإصدار 1.0.0',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _green)),
              SizedBox(height: 4),
              Text('تطوير: شركة الرائد للحلول البرمجية',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 4),
              Text('النص: مصحف المدينة (رواية حفص) • التفسير: الميسَّر • الإعراب: Quranic Arabic Corpus',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) => Card(
        color: const Color(0xFFFBF8F1),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE6D9B8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: _green)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );
}
