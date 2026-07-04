import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/prefs.dart';
import '../app/providers.dart';
import '../core/arabic_text.dart';
import '../data/models.dart';
import '../data/reciters.dart';
import '../data/surah_reciters.dart';
import '../features/bookmarks/bookmarks_sheet.dart';
import '../features/khatma/khatma_sheet.dart';
import '../services/audio_controller.dart';
import 'app_colors.dart';
import 'ayah_sheet.dart';

// ألوان العلامة الثابتة (ترويسة خضراء بنص أبيض/ذهبي في الوضعين).
const _green = AppColors.brandGreen;
const _gold = AppColors.gold;

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
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'المفضّلة',
                icon: const Icon(Icons.bookmarks, color: _gold, size: 20),
                onPressed: () => showBookmarksSheet(context, ref),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'خطّة الختمة',
                icon: const Icon(Icons.event_note, color: _gold, size: 20),
                onPressed: () => showKhatmaSheet(context, ref),
              ),
              const Spacer(),
              // اسم السورة + رقم الصفحة (في الشريط لا داخل الصفحة)
              ref.watch(pageAyahsProvider(page)).maybeWhen(
                    data: (ayahs) => Text(
                      ayahs.isEmpty
                          ? 'صفحة ${toArabicDigits(page)} / ${toArabicDigits(604)}'
                          : '${ayahs.first.surahName}  —  صفحة ${toArabicDigits(page)} / ${toArabicDigits(604)}',
                      style: const TextStyle(
                          color: _gold, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    orElse: () => Text('صفحة ${toArabicDigits(page)} / ${toArabicDigits(604)}',
                        style: const TextStyle(
                            color: _gold, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
            ],
          ),
        ),

        // شريط التلاوة: وضع (آية آية / سورة كاملة) + قارئ الوضع + تشغيل
        Container(
          color: const Color(0xFF0A3F2A),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8)),
                  backgroundColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected) ? _gold : Colors.white),
                  foregroundColor: WidgetStateProperty.resolveWith((s) =>
                      s.contains(WidgetState.selected) ? Colors.white : _green),
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('آية آية')),
                  ButtonSegment(value: true, label: Text('سورة')),
                ],
                selected: {prefs.surahMode},
                onSelectionChanged: (s) {
                  ref.read(audioProvider.notifier).stop();
                  ref.read(prefsProvider.notifier).setSurahMode(s.first);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: prefs.surahMode
                    ? DropdownButton<String>(
                        value: SurahReciter.byName(prefs.surahReciterName).name,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0A3F2A),
                        iconEnabledColor: _gold,
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: [
                          for (final r in SurahReciter.all)
                            DropdownMenuItem(value: r.name, child: Text(r.name)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(prefsProvider.notifier).setSurahReciter(v);
                          }
                        },
                      )
                    : DropdownButton<String>(
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
                          if (v != null) {
                            ref.read(prefsProvider.notifier).setReciter(v);
                          }
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
                  tooltip: audio.playing
                      ? 'إيقاف'
                      : (prefs.surahMode ? 'تشغيل السورة كاملة' : 'تلاوة الصفحة'),
                  icon: Icon(audio.playing ? Icons.stop_circle : Icons.play_circle,
                      color: _gold, size: 30),
                  onPressed: () async {
                    final notifier = ref.read(audioProvider.notifier);
                    if (audio.playing) {
                      await notifier.stop();
                    } else {
                      final ayahs =
                          await ref.read(pageAyahsProvider(page).future);
                      if (ayahs.isEmpty) return;
                      if (prefs.surahMode) {
                        await notifier.playSurah(
                            ayahs.first.surahNumber, ayahs.first.surahName);
                      } else {
                        await notifier.playAyahs(ayahs);
                      }
                    }
                  },
                ),
            ],
          ),
        ),
        if (audio.status.isNotEmpty)
          Container(
            width: double.infinity,
            // شريط الحالة: كريمي نهاراً وداكن ليلاً.
            color: AppColors.isDark(context)
                ? const Color(0xFF1E241E)
                : const Color(0xFFEFE7D2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Text(audio.status,
                style: TextStyle(
                    color: AppColors.green(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),

        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: 604,
            onPageChanged: (i) {
              ref.read(currentPageProvider.notifier).state = i + 1;
              ref.read(prefsProvider.notifier).saveLastPage(i + 1); // للرجوع عند الإقلاع
            },
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
        color: AppColors.page(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pageBorder(context), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: ayahsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.green(context))),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (ayahs) {
          final spans = <InlineSpan>[];
          // مدى محارف كل آية داخل النص — لتحديد الآية المضغوطة مطوّلاً.
          final ranges = <(int start, int end, Ayah ayah)>[];
          var offset = 0;

          for (final a in ayahs) {
            final isTarget = target != null &&
                target.$1 == a.surahNumber && target.$2 == a.numberInSurah;
            final isPlaying = audio.current != null &&
                audio.current!.$1 == a.surahNumber &&
                audio.current!.$2 == a.numberInSurah;
            final bg = isPlaying
                ? AppColors.playing(context)
                : (isTarget ? AppColors.highlight(context) : null);

            final body = '${forDisplay(a.text)} ';
            final orn = ' ﴿${toArabicDigits(a.numberInSurah)}﴾ ';
            ranges.add((offset, offset + body.length + orn.length, a));
            offset += body.length + orn.length;

            spans.add(TextSpan(
              text: body,
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
              text: orn,
              style: TextStyle(
                  color: AppColors.green(context),
                  fontWeight: FontWeight.bold,
                  backgroundColor: bg),
            ));
          }

          final textKey = GlobalKey();
          return SingleChildScrollView(
            child: GestureDetector(
              // ضغطة مطوّلة على آية: تأشيرها ونسخها مباشرة.
              onLongPressStart: (details) {
                final para = textKey.currentContext?.findRenderObject();
                if (para is! RenderParagraph) return;
                final local = para.globalToLocal(details.globalPosition);
                final pos = para.getPositionForOffset(local);
                for (final (start, end, a) in ranges) {
                  if (pos.offset >= start && pos.offset < end) {
                    Clipboard.setData(ClipboardData(
                        text: '﴿${forReading(a.text)}﴾ [${a.surahName}: ${a.numberInSurah}]'));
                    ref.read(targetAyahProvider.notifier).state =
                        (a.surahNumber, a.numberInSurah);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                            'تم نسخ الآية ﴿${toArabicDigits(a.numberInSurah)}﴾ من ${a.surahName}')));
                    break;
                  }
                }
              },
              child: Text.rich(
                TextSpan(children: spans),
                key: textKey,
                textAlign: TextAlign.justify,
                style: TextStyle(
                    fontFamily: prefs.fontFamily,
                    fontSize: prefs.fontSize,
                    height: 1.9,
                    color: AppColors.text(context)),
              ),
            ),
          );
        },
      ),
    );
  }
}
