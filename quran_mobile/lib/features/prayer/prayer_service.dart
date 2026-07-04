import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cities.dart';
import 'local_prayer_calc.dart';

/// الصلوات المعروضة (الشروق للعرض فقط — بلا تنبيه).
enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

const prayerNamesAr = {
  Prayer.fajr: 'الفجر',
  Prayer.sunrise: 'الشروق',
  Prayer.dhuhr: 'الظهر',
  Prayer.asr: 'العصر',
  Prayer.maghrib: 'المغرب',
  Prayer.isha: 'العشاء',
};

/// مواقيت يوم واحد لمدينة.
class PrayerDay {
  final City city;
  final DateTime date;
  final Map<Prayer, DateTime> times;
  final String sourceLabel;
  const PrayerDay(this.city, this.date, this.times, this.sourceLabel);
}

/// خدمة المواقيت بطريقة العتبة العباسية المقدسة (الكفيل):
/// لكربلاء اليومَ تُجلب من api الكفيل الرسمي (مع كاش لنفس اليوم)،
/// ولبقية المدن/الأيام حساب فلكي محلي بنفس معايير الكفيل — فلا تفشل أبداً.
class PrayerTimesService {
  static const _alkafeelUrl =
      'https://alkafeel.net/alkafeel_back_test/api/v1/salaDate';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  String _cacheKey(City c, DateTime d) =>
      'ptcache:alkafeel:${c.name}:${d.year}-${d.month}-${d.day}';

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// مواقيت يوم لمدينة. كربلاء اليوم: من api الكفيل ثم الكاش ثم الحساب
  /// المحلي؛ غيرها: حساب محلي مباشرة (نفس طريقة الكفيل، بلا إنترنت).
  Future<PrayerDay> getDay(City city, DateTime date) async {
    if (city.name == 'كربلاء' && _isToday(date)) {
      final sp = await SharedPreferences.getInstance();
      final key = _cacheKey(city, date);
      try {
        final res = await _dio.get(_alkafeelUrl);
        final row = ((res.data is String ? jsonDecode(res.data as String) : res.data)
                as List)
            .first as Map;
        final day = _fromAlkafeel(city, date, row, 'العتبة العباسية (الكفيل)');
        await sp.setString(key, jsonEncode(row.cast<String, dynamic>()));
        return day;
      } catch (_) {
        final cached = sp.getString(key);
        if (cached != null) {
          return _fromAlkafeel(city, date, jsonDecode(cached) as Map,
              'العتبة العباسية (من الذاكرة)');
        }
      }
    }
    return PrayerDay(city, date, LocalPrayerCalc.compute(city, date),
        'حساب فلكي بطريقة الكفيل (بلا إنترنت)');
  }

  /// يحوّل صف الكفيل {fajer, rise, noon, ghrob} إلى مواقيت اليوم.
  /// الساعات 12-ساعية بلا ص/م: الفجر والشروق صباحاً، الظهر حول الزوال،
  /// والمغرب مساءً. العصر والعشاء لا يوفّرهما الكفيل — من الحساب المحلي.
  PrayerDay _fromAlkafeel(
      City city, DateTime date, Map<dynamic, dynamic> row, String label) {
    DateTime parse(String v, {bool pm = false}) {
      final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(v)!;
      var h = int.parse(m.group(1)!);
      if (pm && h < 12) h += 12;
      return DateTime(date.year, date.month, date.day, h, int.parse(m.group(2)!));
    }

    final local = LocalPrayerCalc.compute(city, date);
    return PrayerDay(city, date, {
      Prayer.fajr: parse(row['fajer'] as String),
      Prayer.sunrise: parse(row['rise'] as String),
      // الزوال بين 11 و12 — لا يُزاد عليه 12.
      Prayer.dhuhr: parse(row['noon'] as String),
      Prayer.asr: local[Prayer.asr]!,
      Prayer.maghrib: parse(row['ghrob'] as String, pm: true),
      Prayer.isha: local[Prayer.isha]!,
    }, label);
  }
}
