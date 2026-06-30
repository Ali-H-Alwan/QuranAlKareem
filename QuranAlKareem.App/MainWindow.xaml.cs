using System.Windows;
using System.Windows.Controls;
using QuranAlKareem.App.Views;
using QuranAlKareem.Data;
using Button = System.Windows.Controls.Button;
using Orientation = System.Windows.Controls.Orientation;

namespace QuranAlKareem.App;

/// <summary>الواجهة الرئيسية: تبويبات مثل كروم — تبويب البحث + تبويبات صفحات المصحف.</summary>
public partial class MainWindow : Window
{
    private readonly SqliteQuranRepository _repository = new();

    public MainWindow()
    {
        InitializeComponent();

        var search = new SearchView(_repository);
        search.OpenPageRequested += OpenMushafTabAt;
        search.OpenSettingsRequested += OpenSettingsTab;
        AddTab("🔍 البحث", search, closable: false);

        var results = new SearchResultsView(_repository);
        results.OpenPageRequested += OpenMushafTabAt;
        AddTab("📃 نتائج البحث", results, closable: false);
    }

    private TabItem? _settingsTab;

    /// <summary>يفتح صفحة المصحف مع تمييز الآية القادمة من البحث.</summary>
    private void OpenMushafTabAt(ViewModels.PageTarget t)
    {
        var view = new MushafView(_repository, t.Page, (t.SurahNumber, t.AyahNumber));
        AddTab(view.TabTitle, view, closable: true);
    }

    private void OpenSettingsTab()
    {
        // تبويب إعدادات واحد فقط: إن كان مفتوحاً نختاره، وإلا ننشئه.
        if (_settingsTab != null && Tabs.Items.Contains(_settingsTab))
        {
            Tabs.SelectedItem = _settingsTab;
            return;
        }
        _settingsTab = AddTab("⚙ الإعدادات", new SettingsView(_repository), closable: true);
    }

    private TabItem AddTab(string title, UIElement content, bool closable)
    {
        var tab = new TabItem { Content = content };

        var header = new StackPanel { Orientation = Orientation.Horizontal };
        header.Children.Add(new TextBlock
        {
            Text = title,
            VerticalAlignment = VerticalAlignment.Center,
            FontWeight = FontWeights.Bold,
            FontSize = 13,
        });

        if (closable)
        {
            var close = new Button
            {
                Content = "✕",
                Margin = new Thickness(8, 0, 0, 0),
                Padding = new Thickness(4, 0, 4, 0),
                BorderThickness = new Thickness(0),
                Background = System.Windows.Media.Brushes.Transparent,
                Cursor = System.Windows.Input.Cursors.Hand,
                FontSize = 12,
            };
            close.Click += (_, _) =>
            {
                var i = Tabs.Items.IndexOf(tab);
                Tabs.Items.Remove(tab);
                if (Tabs.Items.Count > 0)
                    Tabs.SelectedIndex = System.Math.Max(0, i - 1);
            };
            header.Children.Add(close);
        }

        tab.Header = header;
        Tabs.Items.Add(tab);
        Tabs.SelectedItem = tab;
        return tab;
    }
}
