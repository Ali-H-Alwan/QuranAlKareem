import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/arabic_text.dart';
import 'khatma.dart';

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);

/// ورقة خطّة الختمة: بدء/متابعة، تقدّم، ورد اليوم، تذكير.
void showKhatmaSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFBF8F1),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (context, scroll) => Consumer(
          builder: (context, ref, _) {
            final k = ref.watch(khatmaProvider);
            final ctrl = ref.read(khatmaProvider.notifier);
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                const Row(children: [
                  Icon(Icons.menu_book, color: _gold),
                  SizedBox(width: 8),
                  Text('خطّة الختمة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: _green)),
                ]),
                const SizedBox(height: 16),
                if (!k.active)
                  _Setup(ctrl: ctrl)
                else
                  _Progress(k: k, ctrl: ctrl),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Setup extends StatefulWidget {
  const _Setup({required this.ctrl});
  final KhatmaNotifier ctrl;
  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  int _days = 30;
  int _hour = 20;

  @override
  Widget build(BuildContext context) {
    final daily = (kQuranPages / _days).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مدّة الختمة:',
            style: TextStyle(fontWeight: FontWeight.bold, color: _green)),
        Wrap(
          spacing: 8,
          children: [
            for (final d in [7, 15, 30, 60, 90])
              ChoiceChip(
                label: Text('$d يوم'),
                selected: _days == d,
                selectedColor: _gold,
                labelStyle: TextStyle(
                    color: _days == d ? Colors.white : _green,
                    fontWeight: FontWeight.bold),
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('الورد اليومي: $daily صفحة تقريباً',
            style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          const Text('تذكير يومي الساعة:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _hour,
            items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(_fmtHour(h)))],
            onChanged: (v) => setState(() => _hour = v ?? 20),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _green),
            icon: const Icon(Icons.play_arrow),
            label: const Text('ابدأ الختمة'),
            onPressed: () {
              widget.ctrl.start(_days, _hour);
            },
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.k, required this.ctrl});
  final KhatmaState k;
  final KhatmaNotifier ctrl;

  @override
  Widget build(BuildContext context) {
    final behind = k.pagesRead < k.expectedPages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // شريط التقدّم
        Card(
          color: _green,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('${(k.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: _gold, fontWeight: FontWeight.bold, fontSize: 34)),
              Text('قرأت ${k.pagesRead} من $kQuranPages صفحة',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: k.progress,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(_gold),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (k.finished)
          const Card(
            color: Color(0xFFE8F5E9),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('🎉 مبارك، أتممت الختمة! تقبّل الله.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: _green, fontSize: 16)),
            ),
          )
        else ...[
          _row('اليوم', 'اليوم ${k.dayNumber} من ${k.days}'),
          _row('الورد اليومي', '${k.dailyPages} صفحة'),
          _row('المتبقّي اليوم', behind ? '${k.remainingToday} صفحة' : 'أنجزت وردك ✅',
              color: behind ? const Color(0xFF9A4A3A) : _green),
          _row('ابدأ من', 'صفحة ${k.nextPage}'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _green),
                icon: const Icon(Icons.menu_book),
                label: const Text('اقرأ الآن'),
                onPressed: () {
                  ProviderScope.containerOf(context)
                      .read(currentPageProvider.notifier)
                      .state = k.nextPage;
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check, color: _green),
                label: const Text('أنجزت وردي', style: TextStyle(color: _green)),
                onPressed: () => ctrl.markTodayDone(),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline, color: Color(0xFF9A4A3A)),
          label: const Text('إلغاء الختمة', style: TextStyle(color: Color(0xFF9A4A3A))),
          onPressed: () => ctrl.cancel(),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {Color color = _green}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}

String _fmtHour(int h) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final s = h < 12 ? 'ص' : 'م';
  return '${toArabicDigits(h12)} $s';
}
