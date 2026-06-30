namespace QuranAlKareem.Core.Models;

/// <summary>معلومات وإحصائيات صفحة من المصحف (من القرآن الكريم فقط).</summary>
public sealed class PageInfo
{
    public int Page { get; init; }
    public IReadOnlyList<string> Juz { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> Surahs { get; init; } = Array.Empty<string>();
    public int AyahCount { get; init; }
    public int WordCount { get; init; }
    public int LetterCount { get; init; }
    public int SajdaCount { get; init; }

    /// <summary>أرباع الأحزاب الواقعة في الصفحة (1..240 → الحزب والربع).</summary>
    public IReadOnlyList<string> HizbQuarters { get; init; } = Array.Empty<string>();
}
