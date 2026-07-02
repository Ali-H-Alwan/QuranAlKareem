/// أدوات تطبيع النص العربي — منقولة حرفياً من ArabicText.cs في نسخة سطح المكتب.
/// يجب أن تطابق نتائجها نتائج C# تماماً، لأن أعمدة الفهرسة في quran.db
/// بُنيت بذلك المنطق.
library;

/// هل المحرف علامة غير متباعدة (Mn) أو محرف تنسيق (Cf)؟
/// (Dart لا يوفّر فئات يونيكود؛ نغطي المديات الواردة فعلياً في النص العربي/القرآني.)
bool _isMarkOrFormat(int c) {
  return (c >= 0x0610 && c <= 0x061A) || // علامات عربية
      c == 0x061C || // علامة اتجاه عربية (Cf)
      (c >= 0x064B && c <= 0x065F) || // التشكيل والتنوين
      c == 0x0670 || // الألف الخنجرية
      (c >= 0x06D6 && c <= 0x06DC) || // علامات وقف قرآنية
      (c >= 0x06DF && c <= 0x06E4) ||
      (c >= 0x06E7 && c <= 0x06E8) ||
      (c >= 0x06EA && c <= 0x06ED) ||
      (c >= 0x08D3 && c <= 0x08FF) || // امتدادات عربية (علامات)
      (c >= 0x0300 && c <= 0x036F) || // علامات لاتينية مركّبة (احتياط)
      (c >= 0x200B && c <= 0x200F) || // فواصل صفرية/اتجاه (Cf)
      (c >= 0x202A && c <= 0x202E) ||
      (c >= 0x2060 && c <= 0x2064) ||
      c == 0x00AD || // شرطة اختيارية
      c == 0xFEFF; // BOM
}

/// يوحّد النص للبحث: يزيل التشكيل وعلامات الوقف والتطويل والهمزة المفردة،
/// ويوحّد الألف (أ إ آ ٱ ٲ ٳ → ا) والياء (ى ئ → ي) والواو (ؤ → و) والتاء (ة → ه).
String normalize(String? text) {
  if (text == null || text.isEmpty) return '';
  final sb = StringBuffer();
  for (final c in text.runes) {
    if (_isMarkOrFormat(c)) continue;
    switch (c) {
      case 0x0640: // التطويل (الكشيدة)
        continue;
      case 0x0622: // آ
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0671: // ٱ
      case 0x0672: // ٲ
      case 0x0673: // ٳ
        sb.writeCharCode(0x0627); // ا
      case 0x0649: // ى
      case 0x0626: // ئ
      case 0x064A: // ي
        sb.writeCharCode(0x064A); // ي
      case 0x0624: // ؤ
        sb.writeCharCode(0x0648); // و
      case 0x0629: // ة
        sb.writeCharCode(0x0647); // ه
      case 0x0621: // ء — تُحذف
        continue;
      default:
        sb.writeCharCode(c);
    }
  }
  return sb.toString().trim();
}

/// تطبيع خفيف «حسب المكتوب»: يزيل التشكيل والتطويل فقط دون توحيد الحروف.
String normalizeLight(String? text) {
  if (text == null || text.isEmpty) return '';
  final sb = StringBuffer();
  for (final c in text.runes) {
    if (_isMarkOrFormat(c)) continue;
    if (c == 0x0640) continue;
    sb.writeCharCode(c);
  }
  return sb.toString().trim();
}

/// يحوّل رقماً إلى أرقام هندية (٠١٢…).
String toArabicDigits(int n) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((d) {
    final i = d.codeUnitAt(0) - 0x30;
    return (i >= 0 && i <= 9) ? ar[i] : d;
  }).join();
}
