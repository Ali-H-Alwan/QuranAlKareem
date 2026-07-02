import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق المحفوظة (خط العرض، الحجم، القارئ).
class AppPrefs {
  final String fontFamily;
  final double fontSize;
  final String reciterName;

  const AppPrefs({
    this.fontFamily = 'UthmanicHafs',
    this.fontSize = 22,
    this.reciterName = '',
  });

  AppPrefs copyWith({String? fontFamily, double? fontSize, String? reciterName}) =>
      AppPrefs(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        reciterName: reciterName ?? this.reciterName,
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
    state = AppPrefs(
      fontFamily: _sp!.getString('fontFamily') ?? 'UthmanicHafs',
      fontSize: _sp!.getDouble('fontSize') ?? 22,
      reciterName: _sp!.getString('reciter') ?? '',
    );
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
