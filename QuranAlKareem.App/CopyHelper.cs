using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App;

/// <summary>يبني نص نسخ الآية حسب إعدادات النسخ (معلومات/تشكيل).</summary>
public static class CopyHelper
{
    public static string Build(Ayah ayah)
    {
        var s = AppSettings.Load();
        var body = s.CopyWithoutTashkil ? ArabicText.NormalizeLight(ayah.Text) : ayah.Text;
        return s.CopyFullInfo
            ? $"{body} ﴿{ayah.NumberInSurah}﴾ — سورة {ayah.SurahName} (صفحة {ayah.Page})"
            : body;
    }
}
