using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using QuranAlKareem.App.Audio;
using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App.ViewModels;

public sealed partial class MushafViewModel : ObservableObject
{
    private readonly IQuranRepository _repository;
    private readonly AppSettings _settings;
    private readonly AudioService _audio = new();
    // (إعدادات النسخ تُقرأ لحظة النسخ عبر CopyHelper)

    /// <summary>القرّاء المتاحون.</summary>
    public IReadOnlyList<Reciter> Reciters { get; } = Reciter.All;

    [ObservableProperty]
    private Reciter _selectedReciter = Reciter.All[0];

    [ObservableProperty]
    private bool _isPlaying;

    [ObservableProperty]
    private string _audioStatus = string.Empty;

    /// <summary>الآية الجاري تلاوتها (للتمييز في الواجهة).</summary>
    public event Action<Ayah?>? PlayingAyahChanged;

    /// <summary>مقاطع إعراب الكلمة المختارة (للشريط الجانبي).</summary>
    public ObservableCollection<SegmentInfo> Analysis { get; } = new();

    [ObservableProperty]
    private string _analysisTitle = string.Empty;

    [ObservableProperty]
    private string _tafsirText = string.Empty;

    /// <summary>كلمات آية (لعرضها قابلة للنقر في وضع الصفحة الواحدة).</summary>
    public IReadOnlyList<QuranWord> WordsOf(Ayah ayah) =>
        _repository.GetWords(ayah.SurahNumber, ayah.NumberInSurah);

    /// <summary>آيات الصفحة اليمنى (الصفحة الحالية).</summary>
    public ObservableCollection<Ayah> RightAyahs { get; } = new();

    /// <summary>آيات الصفحة اليسرى (الصفحة التالية، في وضع الصفحتين).</summary>
    public ObservableCollection<Ayah> LeftAyahs { get; } = new();

    [ObservableProperty]
    private int _currentPage = 1;

    [ObservableProperty]
    private string _selectedFont = "Amiri Quran";

    [ObservableProperty]
    private double _fontSize = 28;

    [ObservableProperty]
    private string _rightHeader = string.Empty;

    [ObservableProperty]
    private string _leftHeader = string.Empty;

    [ObservableProperty]
    private string _copyNotice = string.Empty;

    [ObservableProperty]
    private bool _twoPages;

    [ObservableProperty]
    private PageInfo? _pageInfo;

    /// <summary>اتجاه آخر انتقال (+1 للأمام، -1 للخلف) لضبط الأنيميشن.</summary>
    public int LastDirection { get; private set; } = 1;

    /// <summary>يُطلق عند تغيّر الصفحة لإعادة بناء النص وتشغيل الأنيميشن.</summary>
    public event Action? PageChanged;

    public int PageCount { get; }

    public MushafViewModel(IQuranRepository repository, int startPage)
    {
        _repository = repository;
        _settings = AppSettings.Load();
        SelectedFont = _settings.SelectedFont;
        FontSize = _settings.FontSize;
        _twoPages = _settings.MushafTwoPages;
        _selectedReciter = Reciter.ByName(_settings.Reciter);
        PageCount = repository.PageCount;
        CurrentPage = Math.Clamp(startPage, 1, PageCount);

        _audio.CurrentAyahChanged += a =>
        {
            IsPlaying = _audio.IsPlaying;
            PlayingAyahChanged?.Invoke(a);
        };
        _audio.DownloadProgress += (done, total) =>
            AudioStatus = done < total ? $"جاري تحميل الصوت {done}/{total}…" : "يُشغّل…";
        LoadPage();
    }

    partial void OnSelectedReciterChanged(Reciter value)
    {
        _settings.Reciter = value.Name;
        _settings.Save();
    }

    /// <summary>يعرض إعراب الكلمة المنقورة في الشريط الجانبي.</summary>
    [RelayCommand]
    public void ShowWordAnalysis(QuranWord? word)
    {
        if (word is null) return;
        // أثناء التلاوة: النقر ينقل الصوت إلى هذه الآية.
        _audio.JumpTo(word.SurahNumber, word.Ayah);
        Analysis.Clear();
        var an = _repository.GetAnalysisForWord(word.SurahNumber, word.Ayah, word.WordIndex);
        if (an is null) { AnalysisTitle = string.Empty; return; }
        foreach (var seg in an.Segments) Analysis.Add(seg);
        var root = string.IsNullOrEmpty(an.Root) ? "—" : an.Root;
        AnalysisTitle = $"إعراب: {an.Form}  (الجذر: {root})";
        TafsirText = _repository.GetTafsir(word.SurahNumber, word.Ayah) ?? string.Empty;
    }

    [RelayCommand]
    private async Task PlayPage()
    {
        AudioStatus = "جاري تحميل الصوت…";
        try
        {
            await _audio.PrepareAndPlayAsync(RightAyahs.ToList(), SelectedReciter.Folder);
        }
        catch (OperationCanceledException) { AudioStatus = string.Empty; }
        catch
        {
            AudioStatus = "تعذّر تحميل الصوت — تحقّق من الإنترنت";
        }
    }

    [RelayCommand]
    private void StopAudio()
    {
        _audio.Stop();
        IsPlaying = false;
        AudioStatus = string.Empty;
    }

    // ── تكبير/تصغير الخط داخل الصفحة ──
    [RelayCommand]
    private void ZoomIn()
    {
        FontSize = Math.Min(72, FontSize + 2);
        PersistFont();
        PageChanged?.Invoke();
    }

    [RelayCommand]
    private void ZoomOut()
    {
        FontSize = Math.Max(14, FontSize - 2);
        PersistFont();
        PageChanged?.Invoke();
    }

    private void PersistFont()
    {
        _settings.FontSize = FontSize;
        _settings.Save();
    }

    public bool CanGoNext => CurrentPage < PageCount;
    public bool CanGoPrevious => CurrentPage > 1;

    private int Step => TwoPages ? 2 : 1;

    [RelayCommand]
    private void NextPage()
    {
        if (!CanGoNext) return;
        LastDirection = 1;
        CurrentPage = Math.Min(PageCount, CurrentPage + Step);
        LoadPage();
    }

    [RelayCommand]
    private void PreviousPage()
    {
        if (!CanGoPrevious) return;
        LastDirection = -1;
        CurrentPage = Math.Max(1, CurrentPage - Step);
        LoadPage();
    }

    /// <summary>كبسة يسار على الآية تنسخها.</summary>
    [RelayCommand]
    public void CopyAyah(Ayah? ayah)
    {
        if (ayah is null) return;
        // أثناء التلاوة (وضع الصفحتين): النقر ينقل الصوت إلى هذه الآية.
        _audio.JumpTo(ayah.SurahNumber, ayah.NumberInSurah);
        System.Windows.Clipboard.SetText(CopyHelper.Build(ayah));
        CopyNotice = $"تم نسخ الآية ﴿{ayah.NumberInSurah}﴾";
    }

    partial void OnTwoPagesChanged(bool value)
    {
        _settings.MushafTwoPages = value;
        _settings.Save();
        LoadPage();
    }

    private void LoadPage()
    {
        RightAyahs.Clear();
        LeftAyahs.Clear();

        foreach (var ayah in _repository.GetAyahsByPage(CurrentPage))
            RightAyahs.Add(ayah);
        RightHeader = BuildHeader(RightAyahs, CurrentPage);

        if (TwoPages && CurrentPage < PageCount)
        {
            foreach (var ayah in _repository.GetAyahsByPage(CurrentPage + 1))
                LeftAyahs.Add(ayah);
            LeftHeader = BuildHeader(LeftAyahs, CurrentPage + 1);
            PageInfo = null; // لا نعرض اللوحة الجانبية في وضع الصفحتين
        }
        else
        {
            LeftHeader = string.Empty;
            PageInfo = _repository.GetPageInfo(CurrentPage);
        }

        CopyNotice = string.Empty;
        Analysis.Clear();
        AnalysisTitle = string.Empty;
        TafsirText = string.Empty;
        AudioStatus = string.Empty;
        _audio.Stop();
        IsPlaying = false;
        NextPageCommand.NotifyCanExecuteChanged();
        PreviousPageCommand.NotifyCanExecuteChanged();
        PageChanged?.Invoke();
    }

    private string BuildHeader(IReadOnlyList<Ayah> ayahs, int page)
    {
        var surah = ayahs.Count > 0 ? ayahs[0].SurahName : string.Empty;
        return $"{surah}  —  صفحة {page} / {PageCount}";
    }
}
