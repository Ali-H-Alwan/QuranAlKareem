import 'dart:math';

import 'cities.dart';
import 'prayer_service.dart';

/// حساب فلكي محلي للمواقيت بطريقة العتبة العباسية المقدسة (الكفيل):
/// الفجر 18°، المغرب 4° بعد الغروب (ذهاب الحمرة المشرقية)، العشاء 14°،
/// والعصر بظلّ المثل. الزوايا مُعايَرة على قيم api الكفيل لكربلاء —
/// مطابقة بالدقيقة (فجر 03:21، شروق 05:01، مغرب 19:33 في 2026-07-04).
/// خوارزمية praytimes.org — يعمل بلا إنترنت إطلاقاً.
class LocalPrayerCalc {
  static const _fajrAngle = 18.0;
  static const _maghribAngle = 4.0;
  static const _ishaAngle = 14.0;
  // انكسار الضوء + نصف قطر قرص الشمس عند الشروق/الغروب.
  static const _sunriseAngle = 0.833;

  /// مواقيت اليوم [date] لمدينة [city] بتوقيتها المحلي (utcOffsetHours).
  static Map<Prayer, DateTime> compute(City city, DateTime date) {
    final tz = city.utcOffsetHours.toDouble();

    // تقديرات أولية (ساعة UTC) ثم تكرار لتقييم ميل الشمس عند وقت كل صلاة.
    var noon = 12.0 - tz, fajr = noon - 5, sunrise = noon - 6;
    var asr = noon + 3.5, maghrib = noon + 6, isha = noon + 7;
    for (var i = 0; i < 2; i++) {
      noon = _noonUtc(date, city.lng, noon);
      fajr = _noonUtc(date, city.lng, fajr) -
          _hourAngle(date, fajr, city.lat, _fajrAngle);
      sunrise = _noonUtc(date, city.lng, sunrise) -
          _hourAngle(date, sunrise, city.lat, _sunriseAngle);
      asr = _noonUtc(date, city.lng, asr) + _asrHourAngle(date, asr, city.lat);
      maghrib = _noonUtc(date, city.lng, maghrib) +
          _hourAngle(date, maghrib, city.lat, _maghribAngle);
      isha = _noonUtc(date, city.lng, isha) +
          _hourAngle(date, isha, city.lat, _ishaAngle);
    }

    DateTime local(double utcHours) {
      final total = ((utcHours + tz) * 60).round(); // لأقرب دقيقة
      return DateTime(date.year, date.month, date.day)
          .add(Duration(minutes: total));
    }

    return {
      Prayer.fajr: local(fajr),
      Prayer.sunrise: local(sunrise),
      Prayer.dhuhr: local(noon),
      Prayer.asr: local(asr),
      Prayer.maghrib: local(maghrib),
      Prayer.isha: local(isha),
    };
  }

  /// موقع الشمس (الميل بالدرجات، معادلة الزمن بالساعات) عند لحظة UTC معيّنة.
  static (double decl, double eqt) _sun(DateTime date, double utcHours) {
    final jd = _julian(date.year, date.month, date.day) + utcHours / 24.0;
    final d = jd - 2451545.0;
    final g = _rad(_fixAngle(357.529 + 0.98560028 * d));
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _rad(_fixAngle(q + 1.915 * sin(g) + 0.020 * sin(2 * g)));
    final e = _rad(23.439 - 0.00000036 * d);
    final ra = _deg(atan2(cos(e) * sin(l), cos(l))) / 15.0;
    final decl = _deg(asin(sin(e) * sin(l)));
    final eqt = q / 15.0 - _fixHour(ra);
    return (decl, eqt);
  }

  /// الزوال (الظهر) بساعة UTC؛ [approx] لحظة تقييم موقع الشمس.
  static double _noonUtc(DateTime date, double lng, double approx) {
    final (_, eqt) = _sun(date, approx);
    return _fixHour(12.0 - eqt) - lng / 15.0;
  }

  /// نصف القوس الزمني (بالساعات) لبلوغ الشمس انخفاض [angle] درجة تحت الأفق.
  static double _hourAngle(
      DateTime date, double approx, double lat, double angle) {
    final (decl, _) = _sun(date, approx);
    final c = (-sin(_rad(angle)) - sin(_rad(decl)) * sin(_rad(lat))) /
        (cos(_rad(decl)) * cos(_rad(lat)));
    return _deg(acos(c.clamp(-1.0, 1.0))) / 15.0;
  }

  /// قوس العصر: ارتفاع الشمس حين يساوي الظلُّ ظلَّ المثل (عامل 1).
  static double _asrHourAngle(DateTime date, double approx, double lat) {
    final (decl, _) = _sun(date, approx);
    final alt = _deg(atan(1.0 / (1.0 + tan(_rad((lat - decl).abs())))));
    final c = (sin(_rad(alt)) - sin(_rad(decl)) * sin(_rad(lat))) /
        (cos(_rad(decl)) * cos(_rad(lat)));
    return _deg(acos(c.clamp(-1.0, 1.0))) / 15.0;
  }

  static double _julian(int year, int month, int day) {
    var y = year, m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static double _rad(double d) => d * pi / 180.0;
  static double _deg(double r) => r * 180.0 / pi;
  static double _fixAngle(double a) => a - 360.0 * (a / 360.0).floor();
  static double _fixHour(double h) => h - 24.0 * (h / 24.0).floor();
}
