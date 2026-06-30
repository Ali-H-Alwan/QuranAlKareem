using System.Net;
using System.Threading.Tasks;
using AutoUpdaterDotNET;

namespace QuranAlKareem.App;

/// <summary>
/// نظام تحديث البرنامج (نفس آلية أنظمة الراعد عبر AutoUpdater.NET).
/// يقرأ معلومات النسخة من فولدر التحديث الخاص بهذا النظام.
/// </summary>
public sealed class AppUpdater
{
    // فولدر التحديث الخاص بنظام القرآن الكريم.
    private const string UpdateUrl = "https://update.alraed-iq.com/quran_alihasan/VersionInfo.xml";

    public static readonly AppUpdater Instance = new();

    private bool _showMessage;

    private AppUpdater()
    {
        AutoUpdater.CheckForUpdateEvent += OnCheckForUpdate;
    }

    /// <summary>يفحص وجود تحديث. showMessage=true لإظهار رسالة حتى عند عدم توفّر تحديث.</summary>
    public void Check(bool showMessage)
    {
        _showMessage = showMessage;
        Task.Run(() =>
        {
            AutoUpdater.ShowSkipButton = false;
            AutoUpdater.Mandatory = true;
            AutoUpdater.Start(UpdateUrl);
        });
    }

    private void OnCheckForUpdate(UpdateInfoEventArgs args)
    {
        // ضمان تنفيذ كل ما يخصّ الواجهة على خيط الـ UI.
        var dispatcher = System.Windows.Application.Current?.Dispatcher;
        if (dispatcher != null && !dispatcher.CheckAccess())
        {
            dispatcher.Invoke(() => OnCheckForUpdate(args));
            return;
        }

        if (args.Error != null)
        {
            // تجاهل أخطاء الشبكة بصمت (التطبيق يعمل أوفلاين).
            if (args.Error is not WebException && _showMessage)
                System.Windows.MessageBox.Show(args.Error.Message, "تحديث النظام");
            return;
        }

        if (args.IsUpdateAvailable)
        {
            var msg = $"تتوفّر نسخة جديدة {args.CurrentVersion}، وأنت تستخدم النسخة {args.InstalledVersion}.\nهل تريد تحديث البرنامج الآن؟";
            var result = System.Windows.MessageBox.Show(msg, "تحديث النظام",
                System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Information);

            if (result == System.Windows.MessageBoxResult.Yes)
            {
                try
                {
                    if (AutoUpdater.DownloadUpdate(args))
                        System.Windows.Application.Current?.Shutdown();
                }
                catch (Exception ex)
                {
                    System.Windows.MessageBox.Show(ex.Message, "خطأ في التحديث");
                }
            }
        }
        else if (_showMessage)
        {
            System.Windows.MessageBox.Show("أنت تستخدم أحدث نسخة من البرنامج.", "تحديث النظام");
        }
    }
}
