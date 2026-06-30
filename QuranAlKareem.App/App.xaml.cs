using QuranAlKareem.Data;
using Application = System.Windows.Application;
using StartupEventArgs = System.Windows.StartupEventArgs;

namespace QuranAlKareem.App;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        // تهيئة قاعدة البيانات وإنشاء المخطط عند أول تشغيل.
        QuranDatabase.EnsureCreated();
        // فحص صامت للتحديث عند الإقلاع (يتجاهل غياب الإنترنت).
        AppUpdater.Instance.Check(showMessage: false);
    }
}

