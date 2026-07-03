using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App.ViewModels;

/// <summary>هدف الانتقال إلى صفحة المصحف مع تمييز آية بعينها.</summary>
public readonly record struct PageTarget(int Page, int SurahNumber, int AyahNumber);

/// <summary>
/// واجهة بحث احترافية: صفحة واحدة تعرض كل النتائج بشكل مرتّب،
/// بلا تشكيل (إعراب) وبلا أسماء سور — فقط نص الآية مع تمييز كلمة البحث.
/// </summary>
public sealed partial class SearchResultsViewModel : ObservableObject
{
    private readonly IQuranRepository _repository;
    private readonly AppSettings _settings;

    public ObservableCollection<AyahItem> Results { get; } = new();

    /// <summary>الخطوط المتاحة لعرض نص الآيات.</summary>
    public IReadOnlyList<string> Fonts { get; } = Services.FontInstaller.DisplayNames;

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    [ObservableProperty]
    private SearchMode _mode = SearchMode.Word;

    [ObservableProperty]
    private bool _highlightMatches = true;

    [ObservableProperty]
    private string _selectedFont = "Amiri Quran";

    [ObservableProperty]
    private double _fontSize = 24;

    [ObservableProperty]
    private string _statusText = "اكتب كلمة ثم اضغط بحث لعرض كل النتائج في صفحة واحدة.";

    [ObservableProperty]
    private int _resultCount;

    [ObservableProperty]
    private bool _hasResults;

    // ── معطيات التظليل داخل نص الآية (تُحسب لحظة البحث، تُقرأ عند بناء البطاقات) ──
    /// <summary>الكلمات المطبّعة المطلوب تظليلها (للكلمة/الجزء، قد تكون عدّة كلمات).</summary>
    public IReadOnlyList<string> HighlightNorms { get; private set; } = Array.Empty<string>();
    /// <summary>وضع الجزء: يُظلَّل أي كلمة تحتوي النص (لا المطابقة التامّة).</summary>
    public bool HighlightIsPart { get; private set; }
    /// <summary>وضع الجذر: يُظلَّل أي كلمة شكلُها ضمن هذه المجموعة.</summary>
    public HashSet<string> HighlightForms { get; private set; } = new();
    private bool _highlightByForms;

    /// <summary>هل التظليل مفعّل ويوجد ما يُظلَّل؟ (يُقرأ عند إعادة البناء).</summary>
    public bool HighlightEnabled => HighlightMatches &&
        (_highlightByForms ? HighlightForms.Count > 0 : HighlightNorms.Count > 0);

    /// <summary>يُطلب فتح صفحة المصحف مع تمييز الآية.</summary>
    public event Action<PageTarget>? OpenPageRequested;

    /// <summary>يُطلق بعد تحديث النتائج لإعادة بناء البطاقات في الواجهة.</summary>
    public event Action? ResultsChanged;

    public SearchResultsViewModel(IQuranRepository repository)
    {
        _repository = repository;
        _settings = AppSettings.Load();
        SelectedFont = _settings.SelectedFont;
        FontSize = _settings.FontSize;
        HighlightMatches = _settings.HighlightMatches;
    }

    partial void OnHighlightMatchesChanged(bool value)
    {
        _settings.HighlightMatches = value;
        _settings.Save();
        ResultsChanged?.Invoke(); // أعد بناء البطاقات لتطبيق التظليل فوراً
    }

    private SearchOptions Options
    {
        get
        {
            var s = AppSettings.Load();
            return new SearchOptions { FoldLetters = s.FoldLetters, BothRasm = s.BothRasm };
        }
    }

    partial void OnSelectedFontChanged(string value)
    {
        if (_settings.SelectedFont == value) return; // مزامنة من الإعدادات — لا حفظ ولا إعادة بناء
        _settings.SelectedFont = value;
        _settings.Save();
        ResultsChanged?.Invoke();
    }

    partial void OnFontSizeChanged(double value)
    {
        _settings.FontSize = value;
        _settings.Save();
        ResultsChanged?.Invoke();
    }

    [RelayCommand]
    private void Search()
    {
        Results.Clear();
        HasResults = false;

        if (string.IsNullOrWhiteSpace(SearchQuery))
        {
            ResultCount = 0;
            StatusText = "اكتب كلمة للبحث.";
            ResultsChanged?.Invoke();
            return;
        }

        var term = SearchQuery.Trim();
        IReadOnlyList<Ayah> results;
        string label = string.Empty;

        // صفّر معطيات التظليل ثم اضبطها بحسب الوضع.
        HighlightNorms = Array.Empty<string>();
        HighlightForms = new HashSet<string>();
        HighlightIsPart = false;
        _highlightByForms = false;

        // كلمات البحث المطبّعة (قد تكون عدّة كلمات — تُظلَّل كلها).
        var normWords = ArabicText.Normalize(term)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries);

        switch (Mode)
        {
            case SearchMode.Root:
                var roots = _repository.FindRoots(SearchQuery);
                results = _repository.SearchByRoot(SearchQuery);
                label = roots.Count > 0 ? roots[0] : term;
                HighlightForms = new HashSet<string>(_repository.NormFormsOfRoots(SearchQuery));
                _highlightByForms = true;
                StatusText = $"بحث بالجذر «{term}» — الجذر: {(roots.Count > 0 ? string.Join("، ", roots) : "—")}";
                break;

            case SearchMode.Part:
                results = _repository.SearchText(SearchQuery, Options, wholeWord: false);
                HighlightNorms = normWords;
                HighlightIsPart = true;
                StatusText = $"بحث عن جزء «{term}»";
                break;

            default: // SearchMode.Word
                results = _repository.SearchText(SearchQuery, Options, wholeWord: true);
                HighlightNorms = normWords;
                StatusText = $"بحث عن كلمة «{term}»";
                break;
        }

        foreach (var ayah in results)
            Results.Add(new AyahItem { Ayah = ayah, MatchLabel = label });

        ResultCount = results.Count;
        HasResults = results.Count > 0;
        if (results.Count == 0)
            StatusText = $"لا توجد نتائج لـ «{term}».";

        ResultsChanged?.Invoke();
    }

    [RelayCommand]
    private void CopyAyah(AyahItem? item)
    {
        if (item is null) return;
        System.Windows.Clipboard.SetText(CopyHelper.Build(item.Ayah));
        StatusText = "تم نسخ الآية.";
    }

    [RelayCommand]
    private void OpenPage(AyahItem? item)
    {
        if (item is null) return;
        OpenPageRequested?.Invoke(
            new PageTarget(item.Ayah.Page, item.Ayah.SurahNumber, item.Ayah.NumberInSurah));
    }

    /// <summary>ينسخ كل آيات النتائج الحالية (كل واحدة بمعلوماتها) إلى الحافظة.</summary>
    [RelayCommand]
    private void CopyAll()
    {
        if (Results.Count == 0) return;
        var sb = new System.Text.StringBuilder();
        foreach (var item in Results)
            sb.AppendLine(CopyHelper.Build(item.Ayah));
        System.Windows.Clipboard.SetText(sb.ToString().TrimEnd());
        StatusText = $"تم نسخ {Results.Count} آية من النتائج.";
    }
}
