import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/arabic_text.dart';
import '../../ui/app_colors.dart';
import '../qibla/qibla_screen.dart';
import 'cities.dart';
import 'prayer_controller.dart';
import 'prayer_service.dart';

// ألوان العلامة الثابتة (بطاقة الخيارات الخضراء وبطاقة الصلاة القادمة الذهبية).
const _green = AppColors.brandGreen;
const _gold = AppColors.gold;

/// شاشة مواقيت الصلاة: المدينة + المصدر + الطريقة + الصلاة القادمة + أجراس التنبيه.
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // تحديث العدّاد التنازلي كل ثانية.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmt(DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? 'ص' : 'م';
    return '${toArabicDigits(h12)}:${padDigits(t.minute, 2)} $suffix';
  }

  String _countdown(DateTime t) {
    final d = t.difference(DateTime.now());
    if (d.isNegative) return '';
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${toArabicDigits(h)}:${padDigits(m, 2)}:${padDigits(s, 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(prayerProvider);
    final ctrl = ref.read(prayerProvider.notifier);
    final next = st.nextPrayer();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── الخيارات ──
        Card(
          color: _green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: _gold, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButton<String>(
                        value: st.city.name,
                        isExpanded: true,
                        dropdownColor: _green,
                        underline: const SizedBox.shrink(),
                        iconEnabledColor: _gold,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        items: [
                          for (final c in City.all)
                            DropdownMenuItem(
                                value: c.name, child: Text('${c.name} (${c.country})')),
                        ],
                        onChanged: (v) { if (v != null) ctrl.setCity(City.byName(v)); },
                      ),
                    ),
                    IconButton(
                      tooltip: 'اتجاه القبلة',
                      icon: const Icon(Icons.explore, color: _gold),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const QiblaScreen())),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── الصلاة القادمة ──
        if (next != null)
          Card(
            color: _gold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text('الصلاة القادمة: ${prayerNamesAr[next.$1]}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_fmt(next.$2),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30)),
                  Text('باقي ${_countdown(next.$2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),

        // ── جدول اليوم ──
        if (st.error.isNotEmpty)
          Card(
            color: AppColors.dangerCard(context),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(st.error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.danger(context), fontSize: 13)),
                  TextButton(
                      onPressed: () => ref.read(prayerProvider.notifier).refresh(),
                      child: const Text('إعادة المحاولة',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          )
        else if (st.loading)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.green(context))),
          )
        else if (st.today != null) ...[
          for (final p in Prayer.values)
            Card(
              // الصلاة القادمة بتظليل ذهبي، والبقية على سطح البطاقات.
              color: next != null && next.$1 == p
                  ? AppColors.highlight(context)
                  : AppColors.card(context),
              margin: const EdgeInsets.symmetric(vertical: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppColors.border(context)),
              ),
              child: ListTile(
                dense: true,
                leading: p == Prayer.sunrise
                    ? const Icon(Icons.wb_sunny_outlined, color: _gold)
                    : IconButton(
                        icon: Icon(
                          st.notify.contains(p)
                              ? Icons.notifications_active
                              : Icons.notifications_off_outlined,
                          color: st.notify.contains(p)
                              ? AppColors.green(context)
                              : Colors.grey,
                        ),
                        tooltip: 'تنبيه ${prayerNamesAr[p]}',
                        onPressed: () => ctrl.toggleNotify(p),
                      ),
                title: Text(prayerNamesAr[p]!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                trailing: Text(_fmt(st.today!.times[p]!),
                    style: TextStyle(
                        color: AppColors.green(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'المصدر: ${st.today!.sourceLabel} • اضغط الجرس لتفعيل/إيقاف تنبيه كل صلاة',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}
