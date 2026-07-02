import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../core/arabic_text.dart';
import '../data/models.dart';

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);

/// يعرض تفاصيل آية: نصّها + نسخ + التفسير الميسَّر + كلماتها (نقر = إعراب).
Future<void> showAyahSheet(BuildContext context, WidgetRef ref, Ayah ayah) {
  final repo = ref.read(repositoryProvider);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFBF8F1),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ayah.surahName} — الآية ${toArabicDigits(ayah.numberInSurah)} — صفحة ${ayah.page}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _green),
                  ),
                ),
                IconButton(
                  tooltip: 'نسخ الآية',
                  icon: const Icon(Icons.copy, color: _gold, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text:
                            '﴿${ayah.text}﴾ [${ayah.surahName}: ${ayah.numberInSurah}]'));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الآية')));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(forDisplay(ayah.text),
                textAlign: TextAlign.justify,
                style: const TextStyle(
                    fontFamily: 'UthmanicHafs', fontSize: 22, height: 2.0)),
            const Divider(height: 24),

            // التفسير
            const Text('التفسير الميسَّر',
                style: TextStyle(fontWeight: FontWeight.bold, color: _green)),
            FutureBuilder<String?>(
              future: repo.tafsir(ayah.surahNumber, ayah.numberInSurah),
              builder: (_, snap) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(snap.data ?? '…',
                    style: const TextStyle(fontSize: 15, height: 1.8)),
              ),
            ),
            const Divider(height: 24),

            // الكلمات (نقر = إعراب)
            const Text('اضغط كلمة لعرض إعرابها',
                style: TextStyle(fontWeight: FontWeight.bold, color: _green)),
            const SizedBox(height: 8),
            FutureBuilder<List<QuranWord>>(
              future: repo.wordsOf(ayah.surahNumber, ayah.numberInSurah),
              builder: (_, snap) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in snap.data ?? const <QuranWord>[])
                    ActionChip(
                      label: Text(w.form,
                          style: const TextStyle(
                              fontFamily: 'UthmanicHafs', fontSize: 18)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE6D9B8)),
                      onPressed: () => _showAnalysis(context, ref, w),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showAnalysis(BuildContext context, WidgetRef ref, QuranWord w) async {
  final segments =
      await ref.read(repositoryProvider).analysisOf(w.surahNumber, w.ayah, w.wordIndex);
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFBF8F1),
        title: Text('إعراب: ${w.form}',
            style: const TextStyle(
                fontFamily: 'UthmanicHafs', color: _green, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (w.root.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('الجذر: ${w.root}',
                    style: const TextStyle(
                        color: _gold, fontWeight: FontWeight.bold)),
              ),
            for (final s in segments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.form,
                        style: const TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 18,
                            color: _green)),
                    Text(s.description,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    ),
  );
}
