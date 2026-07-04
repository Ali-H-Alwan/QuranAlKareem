import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import 'cities.dart';
import 'prayer_service.dart';

bool _adhanOn(SharedPreferences? sp) => sp?.getBool('adhanEnabled') ?? true;

class PrayerState {
  final City city;
  final Set<Prayer> notify;
  final PrayerDay? today;
  final PrayerDay? tomorrow;
  final bool loading;
  final String error;

  const PrayerState({
    required this.city,
    this.notify = const {},
    this.today,
    this.tomorrow,
    this.loading = true,
    this.error = '',
  });

  PrayerState copyWith({
    City? city,
    Set<Prayer>? notify,
    PrayerDay? today,
    PrayerDay? tomorrow,
    bool? loading,
    String? error,
  }) =>
      PrayerState(
        city: city ?? this.city,
        notify: notify ?? this.notify,
        today: today ?? this.today,
        tomorrow: tomorrow ?? this.tomorrow,
        loading: loading ?? this.loading,
        error: error ?? this.error,
      );

  /// الصلاة القادمة (اليوم أو فجر الغد) مع وقتها.
  (Prayer, DateTime)? nextPrayer() {
    final now = DateTime.now();
    final t = today;
    if (t == null) return null;
    for (final p in [
      Prayer.fajr, Prayer.sunrise, Prayer.dhuhr,
      Prayer.asr, Prayer.maghrib, Prayer.isha
    ]) {
      final time = t.times[p];
      if (time != null && time.isAfter(now)) return (p, time);
    }
    final fajr = tomorrow?.times[Prayer.fajr];
    return fajr == null ? null : (Prayer.fajr, fajr);
  }
}

class PrayerController extends Notifier<PrayerState> {
  final _service = PrayerTimesService();
  SharedPreferences? _sp;

  @override
  PrayerState build() {
    _init();
    return PrayerState(city: City.all.first);
  }

  Future<void> _init() async {
    _sp = await SharedPreferences.getInstance();
    final notify = (_sp!.getStringList('pNotify') ?? ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
        .map((n) => Prayer.values.firstWhere((p) => p.name == n, orElse: () => Prayer.fajr))
        .toSet();
    state = state.copyWith(
      city: City.byName(_sp!.getString('pCity')),
      notify: notify,
    );
    await refresh();
  }

  /// يجلب مواقيت اليوم والغد من الإنترنت ويعيد جدولة التنبيهات.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      final d1 = await _service.getDay(state.city, today);
      final d2 = await _service.getDay(state.city, today.add(const Duration(days: 1)));
      state = state.copyWith(today: d1, tomorrow: d2, loading: false);
      // جدولة يومين مقدماً (تتجدد عند كل فتح للتطبيق).
      await NotificationService.reschedule([d1, d2], state.notify, adhan: _adhanOn(_sp));
    } catch (e) {
      state = state.copyWith(
          loading: false,
          error: 'تعذّر جلب المواقيت — تحقّق من الإنترنت ثم أعد المحاولة');
    }
  }

  void setCity(City c) {
    _sp?.setString('pCity', c.name);
    state = state.copyWith(city: c);
    refresh();
  }

  void toggleNotify(Prayer p) {
    final n = Set<Prayer>.from(state.notify);
    if (!n.remove(p)) n.add(p);
    _sp?.setStringList('pNotify', n.map((e) => e.name).toList());
    state = state.copyWith(notify: n);
    // إعادة الجدولة فقط (بلا إعادة جلب المواقيت).
    final d1 = state.today, d2 = state.tomorrow;
    if (d1 != null && d2 != null) NotificationService.reschedule([d1, d2], n, adhan: _adhanOn(_sp));
  }
}

final prayerProvider = NotifierProvider<PrayerController, PrayerState>(PrayerController.new);
