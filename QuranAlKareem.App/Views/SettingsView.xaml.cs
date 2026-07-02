using QuranAlKareem.App.ViewModels;
using QuranAlKareem.Core.Services;
using UserControl = System.Windows.Controls.UserControl;

namespace QuranAlKareem.App.Views;

/// <summary>صفحة الإعدادات (تبويب).</summary>
public partial class SettingsView : UserControl
{
    public SettingsView(IQuranRepository repository)
    {
        InitializeComponent();
        var vm = new SettingsViewModel(repository);
        DataContext = vm;
        // عند العودة للتبويب: زامن «الخطّ المطبّق حالياً» (قد يتغيّر من ترويسات الصفحات).
        Loaded += (_, _) => vm.RefreshAppliedFont();
    }
}
