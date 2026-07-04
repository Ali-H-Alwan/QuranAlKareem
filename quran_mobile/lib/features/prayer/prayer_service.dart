import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cities.dart';

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

/// خدمة المواقيت: من الإنترنت (Aladhan) بالإعدادات الافتراضية للموقع،
/// مع كاش محلي يُستخدم عند انقطاع النت.
class PrayerTimesService {
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  String _cacheKey(City c, DateTime d) =>
      'ptcache:jafari:${c.name}:${d.year}-${d.month}-${d.day}';

  /// يجلب مواقيت يوم من Aladhan؛ عند الفشل يرجع آخر نتيجة مخزّنة لنفس اليوم،
  /// وإلا يرمي خطأً واضحاً.
  Future<PrayerDay> getDay(City city, DateTime date) async {
    final sp = await SharedPreferences.getInstance();
    final key = _cacheKey(city, date);
    try {
      final dd =
          '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      final res = await _dio.get(
        'https://api.aladhan.com/v1/timings/$dd',
        // method=0: الطريقة الجعفرية (الشيعة الإثنا عشرية، معهد ليفا/قم) —
        // المغرب بعد الغروب بذهاب الحمرة المشرقية، لا عند الغروب كأهل السنة.
        queryParameters: {'latitude': city.lat, 'longitude': city.lng, 'method': 0},
      );
      final timings = (res.data['data']['timings'] as Map).cast<String, dynamic>();
      await sp.setString(key, jsonEncode(timings));
      return _fromTimings(city, date, timings, 'Aladhan (أونلاين)');
    } catch (_) {
      final cached = sp.getString(key);
      if (cached != null) {
        return _fromTimings(city, date,
            (jsonDecode(cached) as Map).cast<String, dynamic>(), 'أونلاين (من الذاكرة)');
      }
      throw Exception('تعذّر جلب المواقيت — تحقّق من الإنترنت');
    }
  }

  PrayerDay _fromTimings(
      City city, DateTime date, Map<String, dynamic> t, String label) {
    DateTime parse(String v) {
      final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(v)!;
      return DateTime(date.year, date.month, date.day,
          int.parse(m.group(1)!), int.parse(m.group(2)!));
    }

    return PrayerDay(city, date, {
      Prayer.fajr: parse(t['Fajr'] as String),
      Prayer.sunrise: parse(t['Sunrise'] as String),
      Prayer.dhuhr: parse(t['Dhuhr'] as String),
      Prayer.asr: parse(t['Asr'] as String),
      Prayer.maghrib: parse(t['Maghrib'] as String),
      Prayer.isha: parse(t['Isha'] as String),
    }, label);
  }
}
