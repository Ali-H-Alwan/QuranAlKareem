import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/arabic_text.dart';
import '../features/prayer/prayer_service.dart';

/// تنبيهات أوقات الصلاة: جدولة محلية (تعمل والتطبيق مغلق) للصلوات المختارة.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
    }
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {/* غير متاح على بعض الأجهزة */}
    _ready = true;
  }

  /// تفاصيل إشعار عادي (نغمة النظام).
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_times',
      'تنبيهات الصلاة',
      channelDescription: 'إشعار عند دخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  /// تفاصيل إشعار بصوت الأذان (الشيعي) — قناة مستقلّة بصوتها الخاص.
  /// (صوت القناة يُثبَّت عند أول إنشاء؛ نُصدِر إصداراً جديداً للقناة عند
  /// تغيير ملف الأذان مستقبلاً بزيادة الرقم في المعرّف.)
  static const _adhanDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_adhan_v1',
      'الأذان',
      channelDescription: 'تشغيل الأذان عند دخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('adhan'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true, sound: 'adhan.caf'),
  );

  /// يعيد جدولة كل التنبيهات: للصلوات المفعَّلة في الأيام المعطاة.
  /// adhan=true يشغّل الأذان بدل نغمة الإشعار.
  static Future<void> reschedule(
      List<PrayerDay> days, Set<Prayer> enabled, {bool adhan = true}) async {
    await init();
    await _plugin.cancelAll();
    final details = adhan ? _adhanDetails : _details;
    final now = DateTime.now();
    var id = 1;
    for (final day in days) {
      for (final p in enabled) {
        if (p == Prayer.sunrise) continue; // الشروق ليس صلاة
        final t = day.times[p];
        if (t == null || t.isBefore(now)) continue;
        final when = tz.TZDateTime(
            tz.local, t.year, t.month, t.day, t.hour, t.minute);
        try {
          await _plugin.zonedSchedule(
            id++,
            'حان الآن وقت صلاة ${prayerNamesAr[p]}',
            '${day.city.name} — ${_fmt(t)}',
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (_) {
          // إن رُفض المنبّه الدقيق نجدول تقريبياً بدل الفشل.
          await _plugin.zonedSchedule(
            id++,
            'حان الآن وقت صلاة ${prayerNamesAr[p]}',
            '${day.city.name} — ${_fmt(t)}',
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    }
  }

  static String _fmt(DateTime t) => '${toArabicDigits(t.hour)}:${padDigits(t.minute, 2)}';
}
