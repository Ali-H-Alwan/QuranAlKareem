using System.Collections.Generic;
using QuranAlKareem.Core.Models;

namespace QuranAlKareem.App.ViewModels;

/// <summary>آية معروضة مع كلماتها القابلة للنقر (لإظهار الإعراب).</summary>
public sealed class AyahItem
{
    public required Ayah Ayah { get; init; }
    public IReadOnlyList<QuranWord> Words { get; init; } = new List<QuranWord>();

    /// <summary>وسم المطابقة (الجذر أو كلمة البحث) يظهر أولاً في بطاقة النتيجة.</summary>
    public string MatchLabel { get; init; } = string.Empty;
    public bool HasMatchLabel => !string.IsNullOrEmpty(MatchLabel);

    public string Text => Ayah.Text;
    public string SurahName => Ayah.SurahName;
    public int NumberInSurah => Ayah.NumberInSurah;
    public int Page => Ayah.Page;
}
