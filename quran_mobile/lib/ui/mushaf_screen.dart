import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/prefs.dart';
import '../app/providers.dart';
import '../core/arabic_text.dart';
import '../data/reciters.dart';
import '../services/audio_controller.dart';
import 'ayah_sheet.dart';

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);
const _target = Color(0xFFFBEBB6);
const _playing = Color(0xFFCFE9D6);
const _paper = Color(0xFFFFFDF6);

/// شاشة المصحف: تقليب 604 صفحات بنص مبرَّر + تلاوة صوتية مع تمييز الآية الجارية.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key});

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  PageController? _controller;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(currentPageProvider);
    final audio = ref.watch(audioProvider);
    final prefs = ref.watch(prefsProvider);
    _controller ??= PageController(initialPage: page - 1);

    ref.listen(currentPageProvider, (prev, next) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.hasClients && (ctrl.page?.round() ?? 0) != next - 1) {
        ctrl.jumpToPage(next - 1);
      }
    });

    return Column(
      children: [
        // ترويسة: حجم الخط + رقم الصفحة
        Container(
          color: _green,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                onPressed: () => ref
                    .read(prefsProvider.notifier)
                    .setFontSize((prefs.fontSize - 2).clamp(14, 40)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                onPressed: () => ref
                    .read(prefsProvider.notifier)
                    .setFontSize((prefs.fontSize + 2).clamp(14, 40)),
              ),
              const Spacer(),
              Text('صفحة ${toArabicDigits(page)} / ${toArabicDigits(604)}',
                  style: const TextStyle(
                      color: _gold, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),

        // شريط التلاوة
        Container(
          color: const Color(0xFF0A3F2A),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: Reciter.byName(prefs.reciterName).name,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0A3F2A),
                  iconEnabledColor: _gold,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: [
                    for (final r in Reciter.all)
                      DropdownMenuItem(value: r.name, child: Text(r.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(prefsProvider.notifier).setReciter(v);
                  },
                ),
              ),
              if (audio.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
                )
              else
                IconButton(
                  tooltip: audio.playing ? 'إيقاف' : 'تلاوة الصفحة',
                  icon: Icon(audio.playing ? Icons.stop_circle : Icons.play_circle,
                      color: _gold, size: 30),
                  onPressed: () async {
                    final notifier = ref.read(audioProvider.notifier);
                    if (audio.playing) {
                      await notifier.stop();
                    } else {
                      final ayahs =
                          await ref.read(pageAyahsProvider(page).future);
                      await notifier.playAyahs(ayahs);
                    }
                  },
                ),
            ],
          ),
        ),
        if (audio.status.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFFEFE7D2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Text(audio.status,
                style: const TextStyle(
                    color: _green, fontSize: 11, fontWeight: FontWeight.bold)),
          ),

        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: 604,
            onPageChanged: (i) => ref.read(currentPageProvider.notifier).state = i + 1,
            itemBuilder: (_, i) => _MushafPage(page: i + 1),
          ),
        ),
      ],
    );
  }
}

class _MushafPage extends ConsumerWidget {
  const _MushafPage({required this.page});
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayahsAsync = ref.watch(pageAyahsProvider(page));
    final target = ref.watch(targetAyahProvider);
    final audio = ref.watch(audioProvider);
    final prefs = ref.watch(prefsProvider);

    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: ayahsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _green)),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (ayahs) {
          final spans = <InlineSpan>[];
          for (final a in ayahs) {
            final isTarget = target != null &&
                target.$1 == a.surahNumber && target.$2 == a.numberInSurah;
            final isPlaying = audio.current != null &&
                audio.current!.$1 == a.surahNumber &&
                audio.current!.$2 == a.numberInSurah;
            final bg = isPlaying ? _playing : (isTarget ? _target : null);

            spans.add(TextSpan(
              text: '${a.text} ',
              style: bg == null ? null : TextStyle(backgroundColor: bg),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // أثناء التلاوة: النقر ينقل الصوت إلى الآية (مثل سطح المكتب).
                  if (audio.playing || audio.busy) {
                    ref.read(audioProvider.notifier)
                        .jumpTo(a.surahNumber, a.numberInSurah);
                  } else {
                    showAyahSheet(context, ref, a);
                  }
                },
            ));
            spans.add(TextSpan(
              text: ' ﴿${toArabicDigits(a.numberInSurah)}﴾ ',
              style: TextStyle(
                  color: _green, fontWeight: FontWeight.bold, backgroundColor: bg),
            ));
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                if (ayahs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(ayahs.first.surahName,
                        style: const TextStyle(
                            color: _gold, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                Text.rich(
                  TextSpan(children: spans),
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                      fontFamily: prefs.fontFamily,
                      fontSize: prefs.fontSize,
                      height: 1.9,
                      color: const Color(0xFF1A1A1A)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
