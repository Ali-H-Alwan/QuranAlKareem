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
        new Reciter { Name = "محمود خليل الحُصَري (مرتّل)",   Folder = "Husary_128kbps" },
        new Reciter { Name = "محمود خليل الحُصَري (مجوّد)",   Folder = "Husary_Mujawwad_128kbps" },
        new Reciter { Name = "محمد صديق المِنشاوي (مرتّل)",   Folder = "Minshawy_Murattal_128kbps" },
        new Reciter { Name = "محمد صديق المِنشاوي (مجوّد)",   Folder = "Minshawy_Mujawwad_192kbps" },
        new Reciter { Name = "عبد الباسط عبد الصمد (مرتّل)",  Folder = "Abdul_Basit_Murattal_192kbps" },
        new Reciter { Name = "عبد الباسط عبد الصمد (مجوّد)",  Folder = "Abdul_Basit_Mujawwad_128kbps" },
        new Reciter { Name = "عبد الرحمن السُّدَيس",           Folder = "Abdurrahmaan_As-Sudais_192kbps" },
        new Reciter { Name = "سعود الشُّرَيم",                 Folder = "Saood_ash-Shuraym_128kbps" },
        new Reciter { Name = "مشاري راشد العفاسي",           Folder = "Alafasy_128kbps" },
        new Reciter { Name = "ماهر المُعَيْقلي",               Folder = "Maher_AlMuaiqly_64kbps" },
        new Reciter { Name = "أبو بكر الشاطري",              Folder = "Abu_Bakr_Ash-Shaatree_128kbps" },
        new Reciter { Name = "سعد الغامدي",                  Folder = "Ghamadi_40kbps" },
        new Reciter { Name = "علي الحُذَيْفي",                 Folder = "Hudhaify_128kbps" },
        new Reciter { Name = "هاني الرِّفاعي",                 Folder = "Hani_Rifai_192kbps" },
        new Reciter { Name = "محمد أيوب",                    Folder = "Muhammad_Ayyoub_128kbps" },
        new Reciter { Name = "محمد جبريل",                   Folder = "Muhammad_Jibreel_128kbps" },
        new Reciter { Name = "عبد الله بَصْفَر",               Folder = "Abdullah_Basfar_192kbps" },
        new Reciter { Name = "ناصر القَطَامي",                Folder = "Nasser_Alqatami_128kbps" },
        new Reciter { Name = "أحمد بن علي العجمي",           Folder = "ahmed_ibn_ali_al_ajamy_128kbps" },
        new Reciter { Name = "ياسر الدوسري",                 Folder = "Yasser_Ad-Dussary_128kbps" },
        new Reciter { Name = "فارس عبّاد",                   Folder = "Fares_Abbad_64kbps" },
        new Reciter { Name = "محمود علي البنّا",              Folder = "mahmoud_ali_al_banna_32kbps" },
    };

    public static Reciter ByName(string? name) =>
        All.FirstOrDefault(r => r.Name == name) ?? All[0];
}
