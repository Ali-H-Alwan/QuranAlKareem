import 'package:flutter_test/flutter_test.dart';
import 'package:quran_alkareem/features/prayer/cities.dart';
import 'package:quran_alkareem/features/prayer/local_prayer_calc.dart';
import 'package:quran_alkareem/features/prayer/prayer_service.dart';

/// مقارنة الحساب الفلكي المحلي بطريقة الكفيل (فجر 18°، مغرب 4°، عشاء 14°)
/// بمصدرين مستقلين جُلبا في 2026-07-04:
/// - api الكفيل الرسمي لكربلاء (salaDate).
/// - Aladhan بنفس الزوايا (method=99&methodSettings=18,4,14) لبقية المدن.
/// التفاوت المقبول ±3 دقائق.
void main() {
  const tolMinutes = 3;

  void check(String cityName, DateTime date, Map<Prayer, String> expected) {
    final city = City.byName(cityName);
    expect(city.name, cityName, reason: 'المدينة غير موجودة في القائمة');
    final got = LocalPrayerCalc.compute(city, date);
    for (final e in expected.entries) {
      final parts = e.value.split(':');
      final want = DateTime(date.year, date.month, date.day,
          int.parse(parts[0]), int.parse(parts[1]));
      final diff = got[e.key]!.difference(want).inMinutes.abs();
      expect(diff, lessThanOrEqualTo(tolMinutes),
          reason: '$cityName $date ${e.key}: '
              'got ${got[e.key]}, want $want (Δ$diff min)');
    }
  }

  test('كربلاء — مطابقة api الكفيل الرسمي', () {
    check('كربلاء', DateTime(2026, 7, 4), {
      Prayer.fajr: '03:21',
      Prayer.sunrise: '05:01',
      Prayer.dhuhr: '12:09',
      Prayer.maghrib: '19:33',
    });
  });

  test('بغداد صيفاً', () {
    check('بغداد', DateTime(2026, 7, 4), {
      Prayer.fajr: '03:16',
      Prayer.sunrise: '04:58',
      Prayer.dhuhr: '12:07',
      Prayer.asr: '15:51',
      Prayer.maghrib: '19:33',
      Prayer.isha: '20:32',
    });
  });

  test('بغداد شتاءً', () {
    check('بغداد', DateTime(2026, 1, 15), {
      Prayer.fajr: '05:39',
      Prayer.sunrise: '07:06',
      Prayer.dhuhr: '12:12',
      Prayer.asr: '14:58',
      Prayer.maghrib: '17:34',
      Prayer.isha: '18:25',
    });
  });

  test('بغداد اعتدال ربيعي', () {
    check('بغداد', DateTime(2026, 3, 20), {
      Prayer.fajr: '04:44',
      Prayer.sunrise: '06:07',
      Prayer.dhuhr: '12:10',
      Prayer.asr: '15:36',
      Prayer.maghrib: '18:29',
      Prayer.isha: '19:17',
    });
  });

  test('البصرة صيفاً', () {
    check('البصرة', DateTime(2026, 7, 4), {
      Prayer.fajr: '03:15',
      Prayer.sunrise: '04:51',
      Prayer.dhuhr: '11:53',
      Prayer.asr: '15:30',
      Prayer.maghrib: '19:12',
      Prayer.isha: '20:08',
    });
  });

  test('الموصل صيفاً', () {
    check('الموصل', DateTime(2026, 7, 4), {
      Prayer.fajr: '03:05',
      Prayer.sunrise: '04:55',
      Prayer.dhuhr: '12:12',
      Prayer.asr: '16:03',
      Prayer.maghrib: '19:47',
      Prayer.isha: '20:50',
    });
  });

  test('دبي صيفاً (توقيت +4)', () {
    check('دبي', DateTime(2026, 7, 4), {
      Prayer.fajr: '04:04',
      Prayer.sunrise: '05:33',
      Prayer.dhuhr: '12:23',
      Prayer.asr: '15:47',
      Prayer.maghrib: '19:29',
      Prayer.isha: '20:20',
    });
  });

  test('اسطنبول شتاءً (عرض 41°)', () {
    check('اسطنبول', DateTime(2026, 1, 15), {
      Prayer.fajr: '06:50',
      Prayer.sunrise: '08:27',
      Prayer.dhuhr: '13:13',
      Prayer.asr: '15:40',
      Prayer.maghrib: '18:19',
      Prayer.isha: '19:16',
    });
  });
}
