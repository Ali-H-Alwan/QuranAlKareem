import 'package:flutter/material.dart';

/// ألوان التطبيق الموحّدة: قيمة فاتحة وقيمة داكنة لكل لون حسب وضع السمة.
/// الوضع الفاتح يطابق القيم الأصلية تماماً — التغيير يخصّ الوضع الليلي فقط.
class AppColors {
  AppColors._();

  /// هل السمة الحالية داكنة؟
  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // ── ألوان العلامة الثابتة (نفسها في الوضعين) ──

  /// أخضر العلامة الغامق: خلفيات (ترويسات/أزرار/دوائر) نصّها أبيض دائماً.
  static const brandGreen = Color(0xFF0E5A3C);

  /// ذهبي العلامة: أزرار وأيقونات مميّزة، مقروء على الفاتح والداكن.
  static const gold = Color(0xFFC9A24B);

  // ── ألوان متكيّفة مع الوضع ──

  /// أخضر النصوص والأيقونات المميّزة (يفتح ليلاً ليبقى مقروءاً).
  static Color green(BuildContext c) =>
      isDark(c) ? const Color(0xFF6FBF97) : const Color(0xFF0E5A3C);

  /// سطح البطاقات الرئيس (كريمي نهاراً / داكن ليلاً).
  static Color card(BuildContext c) =>
      isDark(c) ? const Color(0xFF1E241E) : const Color(0xFFFBF8F1);

  /// سطح ثانوي أفتح قليلاً (بطاقات داخلية كانت بيضاء).
  static Color surface(BuildContext c) =>
      isDark(c) ? const Color(0xFF262C26) : Colors.white;

  /// حدود البطاقات الرقيقة.
  static Color border(BuildContext c) =>
      isDark(c) ? const Color(0xFF3A443A) : const Color(0xFFE6D9B8);

  /// حد أرقّ للبطاقات الداخلية.
  static Color borderSubtle(BuildContext c) =>
      isDark(c) ? const Color(0xFF333B33) : const Color(0xFFEFE7D2);

  /// خلفية صفحة المصحف (ورقي نهاراً / أخضر داكن مريح ليلاً).
  static Color page(BuildContext c) =>
      isDark(c) ? const Color(0xFF1A201A) : const Color(0xFFFFFDF6);

  /// إطار صفحة المصحف الذهبي (يُخفَّف ليلاً كي لا يبهر).
  static Color pageBorder(BuildContext c) =>
      isDark(c) ? const Color(0xFF8A7434) : const Color(0xFFC9A24B);

  /// نص القراءة الرئيس (آيات ومتون).
  static Color text(BuildContext c) =>
      isDark(c) ? const Color(0xFFE8E4D8) : const Color(0xFF1A1A1A);

  /// نص ثانوي أنعم (شروح داخل الحوارات).
  static Color textSoft(BuildContext c) =>
      isDark(c) ? const Color(0xFFCFCCC2) : Colors.black87;

  /// تظليل ذهبي: الآية المستهدفة / الكلمة المطابقة / الصلاة القادمة.
  static Color highlight(BuildContext c) =>
      isDark(c) ? const Color(0xFF52431A) : const Color(0xFFFBEBB6);

  /// تظليل الآية الجاري تشغيلها صوتياً.
  static Color playing(BuildContext c) =>
      isDark(c) ? const Color(0xFF23472F) : const Color(0xFFCFE9D6);

  /// أحمر التحذير والحذف (نصوص وأيقونات).
  static Color danger(BuildContext c) =>
      isDark(c) ? const Color(0xFFD08770) : const Color(0xFF9A4A3A);

  /// خلفية بطاقة الخطأ.
  static Color dangerCard(BuildContext c) =>
      isDark(c) ? const Color(0xFF3A2523) : const Color(0xFFFDECEA);

  /// خلفية بطاقة النجاح (إتمام الختمة).
  static Color successCard(BuildContext c) =>
      isDark(c) ? const Color(0xFF1E3326) : const Color(0xFFE8F5E9);

  /// نص الملاحظة فوق الخلفية الذهبية الشفافة.
  static Color noteText(BuildContext c) =>
      isDark(c) ? const Color(0xFFD9C083) : const Color(0xFF8A6D1F);
}
