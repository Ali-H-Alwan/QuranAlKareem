import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../core/arabic_text.dart';
import 'ayah_sheet.dart';

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);
const _target = Color(0xFFFBEBB6);
const _paper = Color(0xFFFFFDF6);

/// شاشة المصحف: تقليب 604 صفحات (سحب أفقي RTL) بنص مبرَّر مثل المصحف الحقيقي.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key});

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  PageController? _controller;
  double _fontSize = 22;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(currentPageProvider);
    _controller ??= PageController(initialPage: page - 1);

    // الانتقال من البحث: اقفز للصفحة المطلوبة إن تغيّرت من الخارج.
    ref.listen(currentPageProvider, (prev, next) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.hasClients && (ctrl.page?.round() ?? 0) != next - 1) {
        ctrl.jumpToPage(next - 1);
      }
    });

    return Column(
      children: [
        // ترويسة: رقم الصفحة + حجم الخط
        Container(
          color: _green,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(14, 40)),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(14, 40)),
              ),
              const Spacer(),
              Text('صفحة ${toArabicDigits(page)} / ${toArabicDigits(QuranRepositoryInfo.pageCount)}',
                  style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),

        Expanded(
          child: PageView.builder(
            controller: _controller,
            reverse: false, // RTL يقلب الاتجاه تلقائياً داخل Directionality
            itemCount: QuranRepositoryInfo.pageCount,
            onPageChanged: (i) => ref.read(currentPageProvider.notifier).state = i + 1,
            itemBuilder: (_, i) => _MushafPage(page: i + 1, fontSize: _fontSize),
          ),
        ),
      ],
    );
  }
}

/// ثابت عدد الصفحات (لتجنّب استيراد المستودع في الواجهة).
class QuranRepositoryInfo {
  static const int pageCount = 604;
}

class _MushafPage extends ConsumerWidget {
  const _MushafPage({required this.page, required this.fontSize});
  final int page;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayahsAsync = ref.watch(pageAyahsProvider(page));
    final target = ref.watch(targetAyahProvider);

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
            final isTarget =
                target != null && target.$1 == a.surahNumber && target.$2 == a.numberInSurah;
            spans.add(TextSpan(
              text: '${a.text} ',
              style: isTarget ? const TextStyle(backgroundColor: _target) : null,
              recognizer: TapGestureRecognizer()
                ..onTap = () => showAyahSheet(context, ref, a),
            ));
            spans.add(TextSpan(
              text: ' ﴿${toArabicDigits(a.numberInSurah)}﴾ ',
              style: TextStyle(
                  color: _green,
                  fontWeight: FontWeight.bold,
                  backgroundColor: isTarget ? _target : null),
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
                      fontFamily: 'UthmanicHafs',
                      fontSize: fontSize,
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
