import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

const int kQuranPages = 604;

/// خطّة ختمة: مدّة بالأيام + تتبّع الصفحات المقروءة + تذكير يومي.
class KhatmaState {
  final bool active;
  final int days;        // مدّة الختمة
  final int startMs;     // تاريخ البدء
  final int pagesRead;   // ما أُنجز من الصفحات
  final int reminderHour; // ساعة التذكير اليومي (0-23)

  const KhatmaState({
    this.active = false,
    this.days = 30,
    this.startMs = 0,
    this.pagesRead = 0,
    this.reminderHour = 20,
  });

  /// الورد اليومي (صفحات) = إجمالي المصحف ÷ المدّة.
  int get dailyPages => (kQuranPages / days).ceil();

  /// رقم اليوم الحالي منذ البدء (يبدأ من ١).
  int get dayNumber {
    if (startMs == 0) return 1;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final now = DateTime.now();
    final d0 = DateTime(start.year, start.month, start.day);
    final d1 = DateTime(now.year, now.month, now.day);
    return d1.difference(d0).inDays + 1;
  }

  /// ما ينبغي إنجازه حتى نهاية اليوم الحالي.
  int get expectedPages => min(kQuranPages, dayNumber * dailyPages);

  /// الصفحة التالية التي يُستأنف منها.
  int get nextPage => min(kQuranPages, pagesRead + 1);

  bool get finished => pagesRead >= kQuranPages;
  double get progress => pagesRead / kQuranPages;
  int get remainingToday => max(0, expectedPages - pagesRead);

  KhatmaState copyWith({bool? active, int? days, int? startMs, int? pagesRead, int? reminderHour}) =>
      KhatmaState(
        active: active ?? this.active,
        days: days ?? this.days,
        startMs: startMs ?? this.startMs,
        pagesRead: pagesRead ?? this.pagesRead,
        reminderHour: reminderHour ?? this.reminderHour,
      );
}

class KhatmaNotifier extends Notifier<KhatmaState> {
  SharedPreferences? _sp;

  @override
  KhatmaState build() {
    _load();
    return const KhatmaState();
  }

  Future<void> _load() async {
    _sp = await SharedPreferences.getInstance();
    state = KhatmaState(
      active: _sp!.getBool('k_active') ?? false,
      days: _sp!.getInt('k_days') ?? 30,
      startMs: _sp!.getInt('k_start') ?? 0,
      pagesRead: _sp!.getInt('k_read') ?? 0,
      reminderHour: _sp!.getInt('k_hour') ?? 20,
    );
  }

  void _persist() {
    _sp?..setBool('k_active', state.active)
      ..setInt('k_days', state.days)
      ..setInt('k_start', state.startMs)
      ..setInt('k_read', state.pagesRead)
      ..setInt('k_hour', state.reminderHour);
  }

  /// يبدأ ختمة جديدة بمدّة وساعة تذكير.
  void start(int days, int reminderHour) {
    state = KhatmaState(
      active: true,
      days: days,
      startMs: DateTime.now().millisecondsSinceEpoch,
      pagesRead: 0,
      reminderHour: reminderHour,
    );
    _persist();
    NotificationService.scheduleDailyKhatma(reminderHour, state.dailyPages);
  }

  /// يسجّل إنجاز ورد اليوم (يزيد المقروء بمقدار الورد اليومي).
  void markTodayDone() {
    final np = min(kQuranPages, state.pagesRead + state.dailyPages);
    state = state.copyWith(pagesRead: np);
    _persist();
  }

  /// يضبط المقروء يدوياً إلى صفحة معيّنة (عند القراءة من المصحف).
  void setPagesRead(int pages) {
    state = state.copyWith(pagesRead: pages.clamp(0, kQuranPages));
    _persist();
  }

  void setReminderHour(int hour) {
    state = state.copyWith(reminderHour: hour);
    _persist();
    if (state.active) NotificationService.scheduleDailyKhatma(hour, state.dailyPages);
  }

  void cancel() {
    state = const KhatmaState();
    _persist();
    NotificationService.cancelKhatma();
  }
}

final khatmaProvider = NotifierProvider<KhatmaNotifier, KhatmaState>(KhatmaNotifier.new);
