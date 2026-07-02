using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App.ViewModels;

public sealed partial class MainViewModel : ObservableObject
{
    private readonly IQuranRepository _repository;

    public ObservableCollection<Surah> Surahs { get; } = new();
    public ObservableCollection<AyahItem> Ayahs { get; } = new();

    /// <summary>الخطوط المتاحة لعرض المصحف.</summary>
    public IReadOnlyList<string> Fonts { get; } = Services.FontInstaller.DisplayNames;

    [ObservableProperty]
    private Surah? _selectedSurah;

    [ObservableProperty]
    private string _selectedFont = "Amiri Quran";

    [ObservableProperty]
    private double _fontSize = 26;

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    [ObservableProperty]
    private SearchMode _mode = SearchMode.Word;

    [ObservableProperty]
    private bool _highlightMatches = true;

    // ── إعدادات البحث ──
    [ObservableProperty]
    private bool _foldLetters = true;

    [ObservableProperty]
    private bool _bothRasm = true;

    [ObservableProperty]
    private bool _copyFullInfo = true;

    [ObservableProperty]
    private bool _mushafTwoPages;

    /// <summary>رقم إصدار البرنامج (للعرض في الإعدادات).</summary>
    public string AppVersion { get; } =
        System.Reflection.Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "1.0.0";

    [RelayCommand]
    private void CheckUpdate() => AppUpdater.Instance.Check(showMessage: true);

    /// <summary>يُطلب فتح صفحة الإعدادات في تبويب.</summary>
    public event Action? OpenSettingsRequested;

    [RelayCommand]
    private void ToggleSettings() => OpenSettingsRequested?.Invoke();

    [ObservableProperty]
    private string _statusText = string.Empty;

    /// <summary>مقاطع الإعراب للكلمة/الجذر المعروض.</summary>
    public ObservableCollection<SegmentInfo> Analysis { get; } = new();

    [ObservableProperty]
    private string _analysisTitle = string.Empty;

    [ObservableProperty]
    private string _tafsirText = string.Empty;

    // ── إحصائيات البحث (الشريط الجانبي) ──
    public ObservableCollection<SurahStat> SurahStats { get; } = new();

    [ObservableProperty]
    private bool _hasStats;

    [ObservableProperty]
    private string _statTerm = string.Empty;

    [ObservableProperty]
    private string _statRoots = string.Empty;

    [ObservableProperty]
    private int _statAyahCount;

    [ObservableProperty]
    private int _statSurahCount;

    [ObservableProperty]
    private int _statWordOccurrences;

    private readonly AppSettings _settings;
    private bool _loading;

    public MainViewModel(IQuranRepository repository)
    {
        _repository = repository;

        _loading = true;
        _settings = AppSettings.Load();
        FoldLetters = _settings.FoldLetters;
        BothRasm = _settings.BothRasm;
        CopyFullInfo = _settings.CopyFullInfo;
        MushafTwoPages = _settings.MushafTwoPages;
        SelectedFont = _settings.SelectedFont;
        FontSize = _settings.FontSize;
        HighlightMatches = _settings.HighlightMatches;
        _loading = false;

        foreach (var surah in _repository.GetSurahs())
            Surahs.Add(surah);
        SelectedSurah = Surahs.FirstOrDefault();
    }

    // تُقرأ خيارات البحث من الإعدادات المحفوظة لحظة البحث (لتطبيق تغييرات صفحة الإعدادات فوراً).
    private SearchOptions Options
    {
        get
        {
            var s = AppSettings.Load();
            return new SearchOptions { FoldLetters = s.FoldLetters, BothRasm = s.BothRasm };
        }
    }

    private void PersistSettings()
    {
        if (_loading) return;
        _settings.FoldLetters = FoldLetters;
        _settings.BothRasm = BothRasm;
        _settings.CopyFullInfo = CopyFullInfo;
        _settings.MushafTwoPages = MushafTwoPages;
        _settings.SelectedFont = SelectedFont;
        _settings.FontSize = FontSize;
        _settings.HighlightMatches = HighlightMatches;
        _settings.Save();
    }

    /// <summary>
    /// يعيد قراءة الإعدادات المحفوظة (الخطّ وغيره) دون إعادة حفظها —
    /// يُستدعى عند العودة للتبويب حتى ينعكس الخطّ المطبَّق من صفحة الإعدادات.
    /// </summary>
    public void RefreshDisplaySettings()
    {
        var s = AppSettings.Load();
        _loading = true;
        FoldLetters = s.FoldLetters;
        BothRasm = s.BothRasm;
        CopyFullInfo = s.CopyFullInfo;
        MushafTwoPages = s.MushafTwoPages;
        HighlightMatches = s.HighlightMatches;
        SelectedFont = s.SelectedFont;
        FontSize = s.FontSize;
        _loading = false;
    }

    partial void OnHighlightMatchesChanged(bool value) => PersistSettings();
    partial void OnFoldLettersChanged(bool value) => PersistSettings();
    partial void OnBothRasmChanged(bool value) => PersistSettings();
    partial void OnCopyFullInfoChanged(bool value) => PersistSettings();
    partial void OnMushafTwoPagesChanged(bool value) => PersistSettings();
    partial void OnSelectedFontChanged(string value) => PersistSettings();
    partial void OnFontSizeChanged(double value) => PersistSettings();

    partial void OnSelectedSurahChanged(Surah? value)
    {
        Ayahs.Clear();
        Analysis.Clear();
        AnalysisTitle = string.Empty;
        if (value is null) return;
        foreach (var ayah in _repository.GetAyahsBySurah(value.Number))
            Ayahs.Add(ToItem(ayah));
        StatusText = $"سورة {value.Name} — {value.AyahCount} آية";
    }

    private AyahItem ToItem(Ayah ayah, string matchLabel = "") => new()
    {
        Ayah = ayah,
        Words = _repository.GetWords(ayah.SurahNumber, ayah.NumberInSurah),
        MatchLabel = matchLabel,
    };

    [RelayCommand]
    private void Search()
    {
        Ayahs.Clear();
        Analysis.Clear();
        AnalysisTitle = string.Empty;
        TafsirText = string.Empty;
        HasStats = false;

        if (string.IsNullOrWhiteSpace(SearchQuery)) return;

        RefreshDisplaySettings(); // طبّق آخر خطّ/إعدادات محفوظة قبل عرض النتائج

        IReadOnlyList<Ayah> results;
        string rootsText = string.Empty;

        if (Mode == SearchMode.Root)
        {
            var roots = _repository.FindRoots(SearchQuery);
            rootsText = roots.Count > 0 ? string.Join("، ", roots) : "—";
            results = _repository.SearchByRoot(SearchQuery);
            var label = roots.Count > 0 ? roots[0] : SearchQuery.Trim();

            foreach (var ayah in results)
                Ayahs.Add(ToItem(ayah, label));

            StatusText = $"بحث بالجذر «{SearchQuery}» (الجذور: {rootsText}): {results.Count} آية";
            if (roots.Count > 0)
                ShowAnalysis(_repository.GetAnalysisForRoot(roots[0]));
        }
        else
        {
            var wholeWord = Mode == SearchMode.Word;
            results = _repository.SearchText(SearchQuery, Options, wholeWord);
            foreach (var ayah in results)
                Ayahs.Add(ToItem(ayah, string.Empty)); // لا شارة جذر في وضع الكلمة/الجزء
            var kind = wholeWord ? "كلمة" : "جزء";
            StatusText = $"بحث عن {kind} «{SearchQuery}»: {results.Count} آية";
        }

        BuildStats(results, rootsText);
    }

    private void BuildStats(IReadOnlyList<Ayah> results, string rootsText)
    {
        SurahStats.Clear();
        StatTerm = SearchQuery.Trim();
        StatRoots = string.IsNullOrEmpty(rootsText) ? "—" : rootsText;
        StatAyahCount = results.Count;

        var bySurah = results
            .GroupBy(a => a.SurahName)
            .Select(g => new { Surah = g.Key, Count = g.Count() })
            .OrderByDescending(x => x.Count)
            .ToList();

        StatSurahCount = bySurah.Count;
        StatWordOccurrences = results.Count;

        var max = bySurah.Count > 0 ? bySurah.Max(x => x.Count) : 1;
        foreach (var s in bySurah.Take(12))
            SurahStats.Add(new SurahStat
            {
                SurahName = s.Surah,
                Count = s.Count,
                Ratio = max > 0 ? (double)s.Count / max : 0,
            });

        HasStats = true;
    }

    /// <summary>يعرض إعراب الكلمة التي نقر عليها المستخدم في اللوحة السفلية.</summary>
    [RelayCommand]
    private void ShowWordAnalysis(QuranWord? word)
    {
        if (word is null) return;
        ShowAnalysis(_repository.GetAnalysisForWord(word.SurahNumber, word.Ayah, word.WordIndex));
        TafsirText = _repository.GetTafsir(word.SurahNumber, word.Ayah) ?? string.Empty;
    }

    private void ShowAnalysis(WordAnalysis? analysis)
    {
        Analysis.Clear();
        if (analysis is null)
        {
            AnalysisTitle = string.Empty;
            return;
        }
        foreach (var seg in analysis.Segments)
            Analysis.Add(seg);

        var root = string.IsNullOrEmpty(analysis.Root) ? "—" : analysis.Root;
        var lemma = string.IsNullOrEmpty(analysis.Lemma) ? "—" : analysis.Lemma;
        AnalysisTitle = $"الإعراب — {analysis.Form}  (الجذر: {root}، الليمة: {lemma})";
    }

    /// <summary>يُطلب فتح صفحة المصحف عند الآية المحدّدة (مع تمييزها).</summary>
    public event Action<PageTarget>? OpenPageRequested;

    [RelayCommand]
    private void OpenPage(AyahItem? ayah)
    {
        if (ayah is null) return;
        OpenPageRequested?.Invoke(
            new PageTarget(ayah.Page, ayah.Ayah.SurahNumber, ayah.NumberInSurah));
    }

    [RelayCommand]
    private void CopyAyah(AyahItem? ayah)
    {
        if (ayah is null) return;
        System.Windows.Clipboard.SetText(CopyHelper.Build(ayah.Ayah));
        StatusText = "تم نسخ الآية.";
    }
}
