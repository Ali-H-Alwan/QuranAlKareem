import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import 'cities.dart';
import 'prayer_service.dart';

class PrayerState {
  final City city;
  final PrayerSource source;
  final CalcMethodDef method;
  final bool hanafi;
  final Set<Prayer> notify;
  final PrayerDay? today;
  final PrayerDay? tomorrow;
  final bool loading;

  const PrayerState({
    required this.city,
    this.source = PrayerSource.offline,
    required this.method,
    this.hanafi = false,
    this.notify = const {},
    this.today,
    this.tomorrow,
    this.loading = true,
  });

  PrayerState copyWith({
    City? city,
    PrayerSource? source,
    CalcMethodDef? method,
    bool? hanafi,
    Set<Prayer>? notify,
    PrayerDay? today,
    PrayerDay? tomorrow,
    bool? loading,
  }) =>
      PrayerState(
        city: city ?? this.city,
        source: source ?? this.source,
        method: method ?? this.method,
        hanafi: hanafi ?? this.hanafi,
        notify: notify ?? this.notify,
        today: today ?? this.today,
        tomorrow: tomorrow ?? this.tomorrow,
        loading: loading ?? this.loading,
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
    return PrayerState(city: City.all.first, method: CalcMethodDef.all.first);
  }

  Future<void> _init() async {
    _sp = await SharedPreferences.getInstance();
    final notify = (_sp!.getStringList('pNotify') ?? ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
        .map((n) => Prayer.values.firstWhere((p) => p.name == n, orElse: () => Prayer.fajr))
        .toSet();
    state = state.copyWith(
      city: City.byName(_sp!.getString('pCity')),
      source: _sp!.getString('pSource') == 'online' ? PrayerSource.online : PrayerSource.offline,
      method: CalcMethodDef.byKey(_sp!.getString('pMethod')),
      hanafi: _sp!.getBool('pHanafi') ?? false,
      notify: notify,
    );
    await refresh();
  }

  /// يعيد حساب مواقيت اليوم والغد ويعيد جدولة التنبيهات.
  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d1 = await _service.getDay(state.source, state.city, today, state.method, state.hanafi);
    final d2 = await _service.getDay(
        state.source, state.city, today.add(const Duration(days: 1)), state.method, state.hanafi);
    state = state.copyWith(today: d1, tomorrow: d2, loading: false);
    // جدولة يومين مقدماً (تتجدد عند كل فتح للتطبيق).
    await NotificationService.reschedule([d1, d2], state.notify);
  }

  void setCity(City c) {
    _sp?.setString('pCity', c.name);
    state = state.copyWith(city: c);
    refresh();
  }

  void setSource(PrayerSource s) {
    _sp?.setString('pSource', s.name);
    state = state.copyWith(source: s);
    refresh();
  }

  void setMethod(CalcMethodDef m) {
    _sp?.setString('pMethod', m.key);
    state = state.copyWith(method: m);
    refresh();
  }

  void setHanafi(bool v) {
    _sp?.setBool('pHanafi', v);
    state = state.copyWith(hanafi: v);
    refresh();
  }

  void toggleNotify(Prayer p) {
    final n = Set<Prayer>.from(state.notify);
    if (!n.remove(p)) n.add(p);
    _sp?.setStringList('pNotify', n.map((e) => e.name).toList());
    state = state.copyWith(notify: n);
    // إعادة الجدولة فقط (بلا إعادة جلب المواقيت).
    final d1 = state.today, d2 = state.tomorrow;
    if (d1 != null && d2 != null) NotificationService.reschedule([d1, d2], n);
  }
}

final prayerProvider = NotifierProvider<PrayerController, PrayerState>(PrayerController.new);
