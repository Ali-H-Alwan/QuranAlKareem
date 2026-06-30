namespace QuranAlKareem.Core.Models;

/// <summary>سورة من سور القرآن الكريم.</summary>
public sealed class Surah
{
    public int Number { get; init; }
    public string Name { get; init; } = string.Empty;
    public int AyahCount { get; init; }

    public override string ToString() => $"{Number}. {Name}";
}
