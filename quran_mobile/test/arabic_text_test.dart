import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_alkareem/core/arabic_text.dart';

/// اختبار تطابق التطبيع: نتيجة Dart يجب أن تطابق عمود NormText
/// المخزّن في quran.db (المبني بمنطق C# في سطح المكتب) حرفاً بحرف.
void main() {
  test('normalize يطابق NormText المبني بـ C#', () {
    final cases = jsonDecode(
        File('test/norm_cases.json').readAsStringSync()) as List;
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final text = c['text'] as String;
      final expected = c['norm'] as String;
      expect(normalize(text), expected,
          reason: 'فشل تطبيع: ${text.substring(0, text.length.clamp(0, 40))}…');
    }
  });

  test('حالات الجذر الكاذب السابقة', () {
    // بِخَلْقِ (الباء + خلق) — تُطبَّع إلى بخلق وتبقى مختلفة عن بخل
    expect(normalize('بِخَلْقِ'), 'بخلق');
    // طه لا تتغيّر (حرفان بلا تشكيل)
    expect(normalize('طه'), 'طه');
    // توحيد الحروف: طة = طه
    expect(normalize('طة'), 'طه');
  });

  test('toArabicDigits', () {
    expect(toArabicDigits(255), '٢٥٥');
    expect(toArabicDigits(7), '٧');
  });
}
