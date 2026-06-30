namespace QuranAlKareem.Core.Models;

/// <summary>كلمة قرآنية قابلة للنقر (لعرض الإعراب).</summary>
public sealed class QuranWord
{
    public int SurahNumber { get; init; }
    public int Ayah { get; init; }
    public int WordIndex { get; init; }
    public string Form { get; init; } = string.Empty;
}
