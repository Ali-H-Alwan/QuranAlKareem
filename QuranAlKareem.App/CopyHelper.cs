using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App;

/// <summary>
/// مساعد ثابت (Static) مسؤول عن تجهيز نص الآية المراد نسخه إلى الحافظة (Clipboard).
/// يقرأ إعدادات النسخ المحفوظة في <see cref="AppSettings"/> ويبني النص النهائي وفقها:
/// <list type="bullet">
///   <item><description>
///     <c>CopyWithoutTashkil</c>: عند تفعيله يُجرَّد النص من التشكيل عبر
///     <see cref="ArabicText.NormalizeLight"/>، وإلا يُنسخ النص الأصلي كما هو.
///   </description></item>
///   <item><description>
///     <c>CopyFullInfo</c>: عند تفعيله تُلحَق بالنص معلومات الآية
///     (رقمها داخل السورة، واسم السورة، ورقم الصفحة)، وإلا يُنسخ نص الآية فقط.
///   </description></item>
/// </list>
/// تُستدعى عادةً من أمر «نسخ الآية» (<c>CopyAyahCommand</c>) في
/// <see cref="ViewModels.MainViewModel"/>.
/// </summary>
public static class CopyHelper
{
    /// <summary>
    /// يبني النص النهائي للآية المُمرَّرة جاهزاً للنسخ، مطبِّقاً إعدادات
    /// التشكيل والمعلومات المحفوظة لحظة الاستدعاء.
    /// </summary>
    /// <param name="ayah">الآية المراد نسخها.</param>
    /// <returns>نص الآية (مع/دون تشكيل، ومع/دون معلومات) حسب الإعدادات.</returns>
    public static string Build(Ayah ayah)
    {
        var s = AppSettings.Load();
        var body = s.CopyWithoutTashkil ? ArabicText.NormalizeLight(ayah.Text) : ayah.Text;
        return s.CopyFullInfo
            ? $"{body} ﴿{ayah.NumberInSurah}﴾ — سورة {ayah.SurahName} (صفحة {ayah.Page})"
            : body;
    }
}
