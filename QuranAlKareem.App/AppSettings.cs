using System.IO;
using System.Text.Json;

namespace QuranAlKareem.App;

/// <summary>إعدادات النظام المحفوظة بين الجلسات.</summary>
public sealed class AppSettings
{
    public bool FoldLetters { get; set; } = true;
    public bool BothRasm { get; set; } = true;
    /// <summary>تظليل الكلمة/الجزء/الجذر المطابق داخل نص الآية في النتائج.</summary>
    public bool HighlightMatches { get; set; } = true;
    /// <summary>عند النسخ: true = نص الآية مع معلوماتها، false = نص الآية فقط.</summary>
    public bool CopyFullInfo { get; set; } = true;
    /// <summary>عند النسخ: true = نص صريح بدون تشكيل، false = مع الحركات.</summary>
    public bool CopyWithoutTashkil { get; set; } = false;
    /// <summary>عرض المصحف صفحتين متقابلتين (true) أو صفحة واحدة (false).</summary>
    public bool MushafTwoPages { get; set; } = false;
    public string Reciter { get; set; } = "محمود خليل الحُصَري";
    public string SelectedFont { get; set; } = "Amiri Quran";
    public double FontSize { get; set; } = 26;

    private static string FilePath
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "QuranAlKareem");
            Directory.CreateDirectory(dir);
            return Path.Combine(dir, "settings.json");
        }
    }

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath)) ?? new AppSettings();
        }
        catch { /* تجاهل الملف التالف واستخدم الافتراضي */ }
        return new AppSettings();
    }

    public void Save()
    {
        try
        {
            File.WriteAllText(FilePath,
                JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* تجاهل أخطاء الحفظ */ }
    }
}
