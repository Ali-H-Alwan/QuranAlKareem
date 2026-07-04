import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/arabic_text.dart';

/// إعدادات التطبيق المحفوظة (خط العرض، الحجم، القارئ، نمط الأرقام).
class AppPrefs {
  final String fontFamily;
  final double fontSize;
  final String reciterName;
  final bool arabicDigits;

  /// وضع الاستماع: آية-آية (everyayah) أو سورة كاملة (MP3Quran).
  final bool surahMode;
  final String surahReciterName;

  /// تشغيل الأذان (الشيعي) صوتاً عند دخول وقت الصلوات المفعّل تنبيهها.
  final bool adhanEnabled;

  const AppPrefs({
    this.fontFamily = 'UthmanicHafs',
    this.fontSize = 22,
    this.reciterName = '',
    this.arabicDigits = true,
    this.surahMode = false,
    this.surahReciterName = '',
    this.adhanEnabled = true,
  });

  AppPrefs copyWith(
          {String? fontFamily,
          double? fontSize,
          String? reciterName,
          bool? arabicDigits,
          bool? surahMode,
          String? surahReciterName,
          bool? adhanEnabled}) =>
      AppPrefs(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        reciterName: reciterName ?? this.reciterName,
        arabicDigits: arabicDigits ?? this.arabicDigits,
        surahMode: surahMode ?? this.surahMode,
        surahReciterName: surahReciterName ?? this.surahReciterName,
        adhanEnabled: adhanEnabled ?? this.adhanEnabled,
      );
}

/// الخطوط المتاحة (المشحونة مع التطبيق) — الاسم المعروض ↦ عائلة الخط.
const quranFonts = {
  'خط المصحف (مجمع الملك فهد)': 'UthmanicHafs',
  'أميري قرآن': 'AmiriQuran',
  'شهرزاد الجديد': 'ScheherazadeNew',
};

class PrefsNotifier extends Notifier<AppPrefs> {
  SharedPreferences? _sp;

  @override
  AppPrefs build() {
    _load();
    return const AppPrefs();
  }

  Future<void> _load() async {
    _sp = await SharedPreferences.getInstance();
    final arabic = _sp!.getBool('arabicDigits') ?? true;
    useArabicDigits = arabic; // النمط العالمي المقروء من كل دوال التنسيق
    state = AppPrefs(
      fontFamily: _sp!.getString('fontFamily') ?? 'UthmanicHafs',
      fontSize: _sp!.getDouble('fontSize') ?? 22,
      reciterName: _sp!.getString('reciter') ?? '',
      arabicDigits: arabic,
      surahMode: _sp!.getBool('surahMode') ?? false,
      surahReciterName: _sp!.getString('surahReciter') ?? '',
      adhanEnabled: _sp!.getBool('adhanEnabled') ?? true,
    );
  }

  void setAdhanEnabled(bool v) {
    state = state.copyWith(adhanEnabled: v);
    _sp?.setBool('adhanEnabled', v);
  }

  void setSurahMode(bool v) {
    state = state.copyWith(surahMode: v);
    _sp?.setBool('surahMode', v);
  }

  void setSurahReciter(String name) {
    state = state.copyWith(surahReciterName: name);
    _sp?.setString('surahReciter', name);
  }

  void setArabicDigits(bool v) {
    useArabicDigits = v;
    state = state.copyWith(arabicDigits: v);
    _sp?.setBool('arabicDigits', v);
  }

  void setFont(String family) {
    state = state.copyWith(fontFamily: family);
    _sp?.setString('fontFamily', family);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _sp?.setDouble('fontSize', size);
  }

  void setReciter(String name) {
    state = state.copyWith(reciterName: name);
    _sp?.setString('reciter', name);
  }
}

final prefsProvider = NotifierProvider<PrefsNotifier, AppPrefs>(PrefsNotifier.new);
