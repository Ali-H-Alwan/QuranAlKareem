namespace QuranAlKareem.Core.Models;

/// <summary>التحليل الصرفي/النحوي لكلمة قرآنية (للإعراب).</summary>
public sealed class WordAnalysis
{
    public string Form { get; init; } = string.Empty;
    public string Root { get; init; } = string.Empty;
    public string Lemma { get; init; } = string.Empty;
    public IReadOnlyList<SegmentInfo> Segments { get; init; } = Array.Empty<SegmentInfo>();
}

/// <summary>مقطع صرفي واحد داخل الكلمة مع وصفه الإعرابي.</summary>
public sealed class SegmentInfo
{
    public string Form { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string Features { get; init; } = string.Empty;
}
