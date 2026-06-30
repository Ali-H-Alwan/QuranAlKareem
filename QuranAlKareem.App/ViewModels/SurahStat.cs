namespace QuranAlKareem.App.ViewModels;

/// <summary>سطر في إحصائية البحث: عدد النتائج في سورة معيّنة.</summary>
public sealed class SurahStat
{
    public string SurahName { get; init; } = string.Empty;
    public int Count { get; init; }

    /// <summary>نسبة العرض (0..1) لشريط التقدّم.</summary>
    public double Ratio { get; init; }
}
