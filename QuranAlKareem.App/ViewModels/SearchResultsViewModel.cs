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
    public string[] Fonts { get; } = { "Amiri Quran", "Scheherazade New", "Traditional Arabic", "Arial" };

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    [ObservableProperty]
    private bool _searchByRoot;

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

    /// <summary>الكلمة التي تُظلَّل داخل نص الآية (فارغة في البحث بالجذر).</summary>
    [ObservableProperty]
    private string _highlightTerm = string.Empty;

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
        string label;

        if (SearchByRoot)
        {
            var roots = _repository.FindRoots(SearchQuery);
            results = _repository.SearchByRoot(SearchQuery);
            label = roots.Count > 0 ? roots[0] : term;
            HighlightTerm = string.Empty; // الجذر لا يُظلَّل حرفياً داخل النص
            StatusText = $"بحث بالجذر «{term}» — الجذر: {(roots.Count > 0 ? string.Join("، ", roots) : "—")}";
        }
        else
        {
            results = _repository.SearchText(SearchQuery, Options);
            label = term;
            HighlightTerm = term;
            StatusText = $"نتائج البحث عن «{term}»";
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
}
