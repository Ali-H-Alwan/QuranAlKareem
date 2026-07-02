using System.Collections.ObjectModel;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using QuranAlKareem.App.Audio;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App.ViewModels;

/// <summary>صفحة الإعدادات: خيارات البحث/العرض + إدارة تحميل الصوت + التحديث.</summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly IQuranRepository _repository;
    private readonly AppSettings _settings;
    private bool _loading;
    private CancellationTokenSource? _downloadCts;

    public IReadOnlyList<string> Fonts { get; } = Services.FontInstaller.DisplayNames;
    public IReadOnlyList<Reciter> Reciters { get; } = Reciter.All;

    /// <summary>إجمالي عدد آيات المصحف (لحساب نسبة التحميل).</summary>
    public int TotalAyahs { get; }

    public ObservableCollection<ReciterCacheInfo> ReciterCaches { get; } = new();

    /// <summary>خطوط القرآن المتاحة للتنزيل/التثبيت (مع معاينة).</summary>
    public ObservableCollection<FontItemViewModel> QuranFonts { get; } = new();

    /// <summary>الخطّ المختار في قائمة التنزيل/التثبيت (للمعاينة).</summary>
    [ObservableProperty] private FontItemViewModel? _selectedQuranFont;

    [ObservableProperty] private bool _foldLetters = true;
    [ObservableProperty] private bool _bothRasm = true;
    [ObservableProperty] private bool _copyFullInfo = true;
    [ObservableProperty] private bool _copyWithoutTashkil;
    [ObservableProperty] private bool _mushafTwoPages;
    [ObservableProperty] private string _selectedFont = "Amiri Quran";
    [ObservableProperty] private double _fontSize = 26;
    [ObservableProperty] private Reciter _selectedReciter = Reciter.All[0];

    [ObservableProperty] private bool _isDownloading;
    [ObservableProperty] private string _downloadStatus = string.Empty;
    [ObservableProperty] private double _downloadPercent;

    public string AppVersion { get; } =
        System.Reflection.Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "1.0.0";

    /// <summary>الجهة المطوّرة.</summary>
    public string Developer => "شركة الرائد للحلول البرمجية";

    private readonly (int Surah, int Ayah)[] _allRefs;

    public SettingsViewModel(IQuranRepository repository)
    {
        _repository = repository;

        // كل مراجع الآيات (سورة, آية) من قائمة السور.
        var refs = new List<(int, int)>();
        foreach (var s in repository.GetSurahs())
            for (var a = 1; a <= s.AyahCount; a++)
                refs.Add((s.Number, a));
        _allRefs = refs.ToArray();
        TotalAyahs = _allRefs.Length;

        _loading = true;
        _settings = AppSettings.Load();
        FoldLetters = _settings.FoldLetters;
        BothRasm = _settings.BothRasm;
        CopyFullInfo = _settings.CopyFullInfo;
        CopyWithoutTashkil = _settings.CopyWithoutTashkil;
        MushafTwoPages = _settings.MushafTwoPages;
        SelectedFont = _settings.SelectedFont;
        FontSize = _settings.FontSize;
        SelectedReciter = Reciter.ByName(_settings.Reciter);
        _loading = false;

        RefreshCaches();

        foreach (var f in Services.FontInstaller.Catalog)
            QuranFonts.Add(new FontItemViewModel(f));
        SelectedQuranFont = QuranFonts.FirstOrDefault();
    }

    private void Persist()
    {
        if (_loading) return;
        _settings.FoldLetters = FoldLetters;
        _settings.BothRasm = BothRasm;
        _settings.CopyFullInfo = CopyFullInfo;
        _settings.CopyWithoutTashkil = CopyWithoutTashkil;
        _settings.MushafTwoPages = MushafTwoPages;
        _settings.SelectedFont = SelectedFont;
        _settings.FontSize = FontSize;
        _settings.Reciter = SelectedReciter.Name;
        _settings.Save();
    }

    partial void OnFoldLettersChanged(bool value) => Persist();
    partial void OnBothRasmChanged(bool value) => Persist();
    partial void OnCopyFullInfoChanged(bool value) => Persist();
    partial void OnCopyWithoutTashkilChanged(bool value) => Persist();
    partial void OnMushafTwoPagesChanged(bool value) => Persist();
    partial void OnSelectedFontChanged(string value) => Persist();
    partial void OnFontSizeChanged(double value) => Persist();
    partial void OnSelectedReciterChanged(Reciter value) => Persist();

    private void RefreshCaches()
    {
        ReciterCaches.Clear();
        foreach (var r in Reciters)
        {
            var (files, mb) = AudioLibrary.Stats(r.Folder);
            ReciterCaches.Add(new ReciterCacheInfo
            {
                Name = r.Name,
                Folder = r.Folder,
                Files = files,
                Megabytes = mb,
                Total = TotalAyahs,
            });
        }
    }

    [RelayCommand]
    private async Task DownloadAll()
    {
        if (IsDownloading) return;
        IsDownloading = true;
        DownloadPercent = 0;
        DownloadStatus = $"بدء تحميل تلاوة «{SelectedReciter.Name}» كاملة…";
        _downloadCts = new CancellationTokenSource();

        var progress = new Progress<(int Done, int Total)>(p =>
        {
            DownloadPercent = p.Total == 0 ? 0 : (double)p.Done / p.Total * 100;
            DownloadStatus = $"تحميل الصوت {p.Done} / {p.Total} آية ({DownloadPercent:0}%)";
        });

        try
        {
            await AudioLibrary.DownloadAsync(_allRefs, SelectedReciter.Folder, progress, _downloadCts.Token);
            DownloadStatus = "اكتمل تحميل التلاوة كاملة ✅ (تعمل الآن بدون إنترنت)";
        }
        catch (OperationCanceledException)
        {
            DownloadStatus = "أُلغي التحميل (يُستأنف لاحقاً من حيث توقّف)";
        }
        catch
        {
            DownloadStatus = "تعذّر إكمال التحميل — تحقّق من الإنترنت ثم أعد المحاولة";
        }
        finally
        {
            IsDownloading = false;
            RefreshCaches();
        }
    }

    [RelayCommand]
    private void CancelDownload() => _downloadCts?.Cancel();

    [RelayCommand]
    private void ClearReciter()
    {
        AudioLibrary.Clear(SelectedReciter.Folder);
        RefreshCaches();
        DownloadStatus = $"تم حذف صوت «{SelectedReciter.Name}»";
    }

    [RelayCommand]
    private void ClearAll()
    {
        AudioLibrary.ClearAll();
        RefreshCaches();
        DownloadStatus = "تم حذف كل ملفات الصوت";
    }

    [RelayCommand]
    private void CheckUpdate() => AppUpdater.Instance.Check(showMessage: true);

    /// <summary>يزامن «الخطّ المطبّق حالياً» مع الإعدادات (عند العودة للتبويب).</summary>
    public void RefreshAppliedFont() => SelectedFont = AppSettings.Load().SelectedFont;

    /// <summary>يطبّق الخطّ المختار كخطّ عرض للتطبيق كله.</summary>
    [RelayCommand]
    private void ApplyFont()
    {
        if (SelectedQuranFont is null) return;
        SelectedFont = SelectedQuranFont.Family; // يحفظ عبر OnSelectedFontChanged → Persist
    }
}

/// <summary>حالة ذاكرة الصوت لقارئ.</summary>
public sealed class ReciterCacheInfo
{
    public string Name { get; init; } = string.Empty;
    public string Folder { get; init; } = string.Empty;
    public int Files { get; init; }
    public double Megabytes { get; init; }
    public int Total { get; init; }

    public bool IsComplete => Files >= Total && Total > 0;
    public string Summary => Files == 0
        ? "غير محمَّل"
        : IsComplete ? $"كامل ✅ ({Megabytes} م.ب)" : $"{Files} / {Total} آية ({Megabytes} م.ب)";
}
