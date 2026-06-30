namespace QuranAlKareem.Core.Models;

/// <summary>آية واحدة من القرآن الكريم.</summary>
public sealed class Ayah
{
    public int SurahNumber { get; init; }
    public string SurahName { get; init; } = string.Empty;
    public int NumberInSurah { get; init; }
    public string Text { get; init; } = string.Empty;
    public int Page { get; init; }
}
