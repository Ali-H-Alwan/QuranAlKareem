namespace QuranAlKareem.App.Audio;

/// <summary>قارئ تلاوة (ترتيل) مع فولدر الصوت على everyayah.com.</summary>
public sealed class Reciter
{
    public string Name { get; init; } = string.Empty;
    public string Folder { get; init; } = string.Empty;

    public override string ToString() => Name;

    /// <summary>القرّاء المشهورون المتاحون (ترتيل).</summary>
    public static readonly IReadOnlyList<Reciter> All = new[]
    {
        new Reciter { Name = "محمود خليل الحُصَري",      Folder = "Husary_128kbps" },
        new Reciter { Name = "محمد صديق المِنشاوي",      Folder = "Minshawy_Murattal_128kbps" },
        new Reciter { Name = "عبد الباسط عبد الصمد",     Folder = "Abdul_Basit_Murattal_192kbps" },
        new Reciter { Name = "عبد الرحمن السُّدَيس",       Folder = "Abdurrahmaan_As-Sudais_192kbps" },
    };

    public static Reciter ByName(string? name) =>
        All.FirstOrDefault(r => r.Name == name) ?? All[0];
}
