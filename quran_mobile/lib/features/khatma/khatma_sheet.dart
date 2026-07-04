import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/arabic_text.dart';
import '../../ui/app_colors.dart';
import 'khatma.dart';

// ألوان العلامة الثابتة (بطاقة التقدّم الخضراء وأزرارها).
const _green = AppColors.brandGreen;
const _gold = AppColors.gold;

/// ورقة خطّة الختمة: بدء/متابعة، تقدّم، ورد اليوم، تذكير.
void showKhatmaSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card(context),
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
                Row(children: [
                  const Icon(Icons.menu_book, color: _gold),
                  const SizedBox(width: 8),
                  Text('خطّة الختمة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.green(context))),
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
        Text('مدّة الختمة:',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.green(context))),
        Wrap(
          spacing: 8,
          children: [
            for (final d in [7, 15, 30, 60, 90])
              ChoiceChip(
                label: Text('$d يوم'),
                selected: _days == d,
                selectedColor: _gold,
                labelStyle: TextStyle(
                    color: _days == d ? Colors.white : AppColors.green(context),
                    fontWeight: FontWeight.bold),
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('الورد اليومي: $daily صفحة تقريباً',
            style: TextStyle(
                color: AppColors.green(context), fontWeight: FontWeight.bold)),
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
            // نص أبيض صريح كي لا يعتم في الوضع الليلي.
            style: FilledButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white),
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
          Card(
            color: AppColors.successCard(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('🎉 مبارك، أتممت الختمة! تقبّل الله.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.green(context),
                      fontSize: 16)),
            ),
          )
        else ...[
          _row(context, 'اليوم', 'اليوم ${k.dayNumber} من ${k.days}'),
          _row(context, 'الورد اليومي', '${k.dailyPages} صفحة'),
          _row(context, 'المتبقّي اليوم',
              behind ? '${k.remainingToday} صفحة' : 'أنجزت وردك ✅',
              color: behind
                  ? AppColors.danger(context)
                  : AppColors.green(context)),
          _row(context, 'ابدأ من', 'صفحة ${k.nextPage}'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                // نص أبيض صريح كي لا يعتم في الوضع الليلي.
                style: FilledButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white),
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
                icon: Icon(Icons.check, color: AppColors.green(context)),
                label: Text('أنجزت وردي',
                    style: TextStyle(color: AppColors.green(context))),
                onPressed: () => ctrl.markTodayDone(),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(Icons.delete_outline, color: AppColors.danger(context)),
          label: Text('إلغاء الختمة',
              style: TextStyle(color: AppColors.danger(context))),
          onPressed: () => ctrl.cancel(),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value,
          {Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color ?? AppColors.green(context))),
          ],
        ),
      );
}

String _fmtHour(int h) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final s = h < 12 ? 'ص' : 'م';
  return '${toArabicDigits(h12)} $s';
}
