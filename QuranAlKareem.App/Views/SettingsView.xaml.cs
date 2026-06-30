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
        DataContext = new SettingsViewModel(repository);
    }
}
