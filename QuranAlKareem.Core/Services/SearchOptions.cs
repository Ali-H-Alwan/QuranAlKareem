namespace QuranAlKareem.Core.Services;

/// <summary>خيارات البحث النصّي القابلة للضبط من إعدادات النظام.</summary>
public sealed class SearchOptions
{
    /// <summary>توحيد الحروف المتشابهة (ة=ه، أ إ آ ا، ى=ي…). الافتراضي مُفعّل.</summary>
    public bool FoldLetters { get; init; } = true;

    /// <summary>البحث بالرسمين الإملائي والعثماني معاً. عند الإيقاف: حسب المكتوب فقط.</summary>
    public bool BothRasm { get; init; } = true;

    public static readonly SearchOptions Default = new();
}
