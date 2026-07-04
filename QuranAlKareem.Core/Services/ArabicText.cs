using System.Globalization;
using System.Text;

namespace QuranAlKareem.Core.Services;

/// <summary>أدوات تطبيع النص العربي لتسهيل المطابقة والبحث الاحترافي.</summary>
public static class ArabicText
{
    /// <summary>
    /// يوحّد النص للبحث: يزيل كل التشكيل وعلامات الوقف القرآنية والتطويل،
    /// ويوحّد أشكال الألف (أ إ آ ٱ ٯ → ا) والياء (ى ئ → ي) والواو (ؤ → و) والتاء (ة → ه).
    /// </summary>
    public static string Normalize(string? text)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;

        var sb = new StringBuilder(text.Length);
        foreach (var ch in text)
        {
            // أزل كل العلامات غير المتباعدة (حركات، تنوين، شدّة، سكون،
            // ألف خنجرية، وكل علامات الضبط/الوقف المصحفية)،
            // وكذلك محارف التنسيق غير المرئية (BOM، فواصل صفرية العرض).
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category is UnicodeCategory.NonSpacingMark or UnicodeCategory.Format)
                continue;

            switch (ch)
            {
                case 'ـ':                       // التطويل (الكشيدة)
                    continue;
                case 'آ' or 'أ' or 'إ' or 'ٱ' or 'ٲ' or 'ٳ':
                    sb.Append('ا'); break;       // أشكال الألف → ا
                case 'ى' or 'ئ' or 'ي':         // الألف المقصورة والياء بالهمزة → ي
                    sb.Append('ي'); break;
                case 'ؤ':
                    sb.Append('و'); break;       // الواو بالهمزة → و
                case 'ة':
                    sb.Append('ه'); break;       // التاء المربوطة → ه
                case 'ء':
                    continue;                    // أزل الهمزة المفردة
                default:
                    sb.Append(ch); break;
            }
        }
        return sb.ToString().Trim();
    }

    /// <summary>
    /// تهيئة النص العثماني للعرض فقط (لا يغيّر المخزّن): الياء الصغيرة
    /// المنفصلة وسط الكلمة (ۦ في إِبْرَٰهِۦمَ والنَّبِيِّۦنَ…) تقطع اتصال
    /// الحروف في معظم الخطوط، فتُستبدل بتطويلة تعلوها ياء صغيرة مركّبة
    /// (ـۧ) كما تُرسم في المصحف المطبوع.
    /// </summary>
    public static string ForDisplay(string? text) =>
        string.IsNullOrEmpty(text)
            ? string.Empty
            : System.Text.RegularExpressions.Regex.Replace(
                text, "ۦ(?=[ء-ي])", "ـۧ");

    /// <summary>
    /// عرض إملائي واضح مع الإبقاء على الحركات (لنتائج البحث): يحوّل الرسم
    /// العثماني إلى إملاء مقروء دون حذف التشكيل — ألف الوصل والألف الخنجرية
    /// إلى ألف عادية، والياء/الواو الصغيرة المعلّقة إلى ي/و. فتظهر
    /// «إِبْرَاهِيمَ» و«دَاوُودَ» بدل «إِبْرَٰهِۦمَ».
    /// </summary>
    public static string ForReading(string? text)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        var sb = new StringBuilder(text.Length);
        foreach (var ch in text)
        {
            switch (ch)
            {
                case 'ٱ' or 'ٰ': sb.Append('ا'); continue;  // ألف الوصل/الخنجرية → ا
                case 'ۦ': sb.Append('ي'); continue;         // ياء صغيرة معلّقة → ي
                case 'ۥ': sb.Append('و'); continue;         // واو صغيرة معلّقة → و
            }
            // احذف علامات الوقف/التجويد الصغيرة العليا (صلى، قلى، ميم صغيرة…):
            // الخطوط العادية لا تدعمها فتظهر دوائر. الحركات الأساسية تبقى.
            if (ch is >= 'ؕ' and <= 'ؚ'
                    or >= 'ۖ' and <= 'ۭ'
                    or >= '࣓' and <= 'ࣿ')
                continue;
            sb.Append(ch);
        }
        return sb.ToString();
    }

    /// <summary>
    /// تطبيع خفيف للبحث «حسب المكتوب»: يزيل التشكيل وعلامات الوقف والتطويل
    /// فقط، دون توحيد الحروف (تبقى ة و ه، أ و ا، ى و ي مختلفة).
    /// </summary>
    public static string NormalizeLight(string? text)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;

        var sb = new StringBuilder(text.Length);
        foreach (var ch in text)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category is UnicodeCategory.NonSpacingMark or UnicodeCategory.Format)
                continue;
            if (ch == 'ـ') continue; // التطويل
            sb.Append(ch);
        }
        return sb.ToString().Trim();
    }
}
