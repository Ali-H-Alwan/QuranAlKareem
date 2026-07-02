namespace QuranAlKareem.Core.Models;

/// <summary>آية واحدة من القرآن الكريم.</summary>
public sealed class Ayah
{
    public int SurahNumber { get; init; }
    public string SurahName { get; init; } = string.Empty;
    public int NumberInSurah { get; init; }
    public string Text { get; init; } = string.Empty;

    /// <summary>
    /// الرسم الإملائي البسيط بلا تشكيل (عمود LightText من quran-simple) —
    /// للعرض والنسخ «بلا تشكيل». تجريدُ العثماني بحذف علاماته يكسر كلماتٍ
    /// مثل «إِبْرَٰهِۦمَ» (تصير إبرهۦم)، بينما البسيط يعطي «إبراهيم» سليمة.
    /// </summary>
    public string SimpleText { get; init; } = string.Empty;

    public int Page { get; init; }
}
