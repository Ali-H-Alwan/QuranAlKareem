import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cities.dart';

/// مصدر حساب المواقيت.
enum PrayerSource { offline, online }

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

/// طريقة حساب: اسمها + رقمها في Aladhan + مُعاملات adhan للحساب المحلي.
class CalcMethodDef {
  final String key;
  final String nameAr;
  final int aladhanId;
  final CalculationParameters Function() offlineParams;
  const CalcMethodDef(this.key, this.nameAr, this.aladhanId, this.offlineParams);

  static final List<CalcMethodDef> all = [
    CalcMethodDef('mwl', 'رابطة العالم الإسلامي', 3,
        () => CalculationMethod.muslim_world_league.getParameters()),
    CalcMethodDef('umm_al_qura', 'أم القرى (مكة)', 4,
        () => CalculationMethod.umm_al_qura.getParameters()),
    CalcMethodDef('egyptian', 'الهيئة المصرية العامة', 5,
        () => CalculationMethod.egyptian.getParameters()),
    CalcMethodDef('karachi', 'جامعة كراتشي', 1,
        () => CalculationMethod.karachi.getParameters()),
    CalcMethodDef('isna', 'ISNA (أمريكا الشمالية)', 2,
        () => CalculationMethod.north_america.getParameters()),
    CalcMethodDef('tehran', 'جيوفيزياء طهران', 7, () {
      // فجر 17.7° وعشاء 14°، والمغرب متأخر عن الغروب (تقريب +17 دقيقة).
      final p = CalculationParameters(fajrAngle: 17.7, ishaAngle: 14.0);
      p.adjustments.maghrib = 17;
      return p;
    }),
    CalcMethodDef('jafari', 'الجعفري (ليفا/قم)', 0, () {
      // فجر 16° وعشاء 14°، والمغرب بعد الغروب (تقريب +17 دقيقة).
      final p = CalculationParameters(fajrAngle: 16.0, ishaAngle: 14.0);
      p.adjustments.maghrib = 17;
      return p;
    }),
  ];

  static CalcMethodDef byKey(String? key) =>
      all.firstWhere((m) => m.key == key, orElse: () => all.first);
}

/// مواقيت يوم واحد لمدينة.
class PrayerDay {
  final City city;
  final DateTime date; // تاريخ اليوم (بدون وقت)
  final Map<Prayer, DateTime> times;
  final String sourceLabel;
  const PrayerDay(this.city, this.date, this.times, this.sourceLabel);
}

/// خدمة المواقيت: حساب محلي (adhan) أو أونلاين (Aladhan) مع كاش للأونلاين.
class PrayerTimesService {
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  /// حساب محلي 100% — بلا إنترنت.
  PrayerDay computeOffline(City city, DateTime date, CalcMethodDef method, bool hanafi) {
    final params = method.offlineParams()
      ..madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    final t = PrayerTimes(
      Coordinates(city.lat, city.lng),
      DateComponents(date.year, date.month, date.day),
      params,
      utcOffset: Duration(hours: city.utcOffsetHours),
    );
    // نعيد بناء الأوقات بتاريخ اليوم المطلوب كتوقيت حائطي محلي.
    DateTime wall(DateTime d) =>
        DateTime(date.year, date.month, date.day, d.hour, d.minute);
    return PrayerDay(city, date, {
      Prayer.fajr: wall(t.fajr),
      Prayer.sunrise: wall(t.sunrise),
      Prayer.dhuhr: wall(t.dhuhr),
      Prayer.asr: wall(t.asr),
      Prayer.maghrib: wall(t.maghrib),
      Prayer.isha: wall(t.isha),
    }, 'حساب محلي (أوفلاين)');
  }

  String _cacheKey(City c, DateTime d, CalcMethodDef m, bool hanafi) =>
      'ptcache:${c.name}:${d.year}-${d.month}-${d.day}:${m.key}:${hanafi ? 1 : 0}';

  /// أونلاين من Aladhan مع تخزين النتيجة؛ عند الفشل: الكاش ثم الحساب المحلي.
  Future<PrayerDay> fetchOnline(
      City city, DateTime date, CalcMethodDef method, bool hanafi) async {
    final sp = await SharedPreferences.getInstance();
    final key = _cacheKey(city, date, method, hanafi);
    try {
      final dd =
          '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
      final res = await _dio.get(
        'https://api.aladhan.com/v1/timings/$dd',
        queryParameters: {
          'latitude': city.lat,
          'longitude': city.lng,
          'method': method.aladhanId,
          'school': hanafi ? 1 : 0,
        },
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
      // لا إنترنت ولا كاش — نرجع للحساب المحلي حتى لا يبقى المستخدم بلا مواقيت.
      final off = computeOffline(city, date, method, hanafi);
      return PrayerDay(city, date, off.times, 'حساب محلي (تعذّر الاتصال)');
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

  /// يجلب مواقيت يوم بحسب المصدر المختار.
  Future<PrayerDay> getDay(PrayerSource source, City city, DateTime date,
      CalcMethodDef method, bool hanafi) {
    if (source == PrayerSource.offline) {
      return Future.value(computeOffline(city, date, method, hanafi));
    }
    return fetchOnline(city, date, method, hanafi);
  }
}
