using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using QuranAlKareem.App.Services;
using FontFamily = System.Windows.Media.FontFamily;

namespace QuranAlKareem.App.ViewModels;

/// <summary>خطّ قرآني في قائمة الإعدادات: معاينة + تنزيل + تثبيت.</summary>
public sealed partial class FontItemViewModel : ObservableObject
{
    private readonly QuranFont _font;

    public string Display => _font.Display;
    public string Family => _font.Family;
    public string Description => _font.Description;

    /// <summary>عيّنة تُعرض بالخطّ نفسه.</summary>
    public string Sample => "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ";

    [ObservableProperty] private FontFamily? _previewFamily;
    [ObservableProperty] private string _status = string.Empty;
    [ObservableProperty] private bool _busy;
    [ObservableProperty] private bool _canPreview;

    public FontItemViewModel(QuranFont font)
    {
        _font = font;
        Refresh();
    }

    private void Refresh()
    {
        PreviewFamily = FontInstaller.Preview(_font);
        CanPreview = PreviewFamily is not null;
        Status = FontInstaller.IsInstalled(_font)
            ? "مثبّت على النظام ✅"
            : FontInstaller.IsDownloaded(_font)
                ? "مُنزَّل — جاهز للتثبيت"
                : "غير مُنزَّل";
    }

    [RelayCommand]
    private async Task Download()
    {
        if (Busy) return;
        Busy = true;
        Status = "جاري التنزيل…";
        try
        {
            await FontInstaller.DownloadAsync(_font);
            Refresh();
        }
        catch
        {
            Status = "تعذّر التنزيل — تحقّق من الإنترنت";
        }
        finally { Busy = false; }
    }

    [RelayCommand]
    private async Task Install()
    {
        if (Busy) return;
        Busy = true;
        try
        {
            if (!FontInstaller.IsDownloaded(_font))
            {
                Status = "جاري التنزيل…";
                await FontInstaller.DownloadAsync(_font);
                Refresh();
            }
            Status = "جاري التثبيت (وافق على طلب المدير)…";
            var ok = await FontInstaller.InstallAsync(_font);
            Status = ok ? "مثبّت على النظام ✅" : "لم يكتمل التثبيت";
            Refresh();
        }
        catch
        {
            Status = "تعذّر التثبيت";
        }
        finally { Busy = false; }
    }
}
