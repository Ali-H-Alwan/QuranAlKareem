using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using QuranAlKareem.App.Services;
using QuranAlKareem.App.ViewModels;
using QuranAlKareem.Core.Services;
using Brush = System.Windows.Media.Brush;
using Color = System.Windows.Media.Color;
using FontFamily = System.Windows.Media.FontFamily;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;
using UserControl = System.Windows.Controls.UserControl;
using Button = System.Windows.Controls.Button;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using VerticalAlignment = System.Windows.VerticalAlignment;
using Orientation = System.Windows.Controls.Orientation;

namespace QuranAlKareem.App.Views;

/// <summary>
/// واجهة بحث احترافية: كل النتائج في صفحة واحدة، بلا تشكيل وبلا أسماء سور،
/// مع تمييز كلمة البحث داخل نص الآية وأزرار النسخ وفتح الصفحة.
/// </summary>
public partial class SearchResultsView : UserControl
{
    private readonly SearchResultsViewModel _vm;

    private static readonly Brush CardBrush = new SolidColorBrush(Color.FromRgb(0xFB, 0xF8, 0xF1));
    private static readonly Brush CardBorder = new SolidColorBrush(Color.FromRgb(0xE6, 0xD9, 0xB8));
    private static readonly Brush InkBrush = new SolidColorBrush(Color.FromRgb(0x1C, 0x1C, 0x1C));
    private static readonly Brush GreenBrush = new SolidColorBrush(Color.FromRgb(0x0E, 0x5A, 0x3C));
    private static readonly Brush GoldBrush = new SolidColorBrush(Color.FromRgb(0xC9, 0xA2, 0x4B));
    private static readonly Brush HitBrush = new SolidColorBrush(Color.FromRgb(0xFB, 0xEB, 0xB6));
    private static readonly Brush BadgeBrush = new SolidColorBrush(Color.FromRgb(0xEF, 0xE7, 0xD2));

    /// <summary>يُطلب فتح صفحة المصحف مع تمييز الآية.</summary>
    public event Action<PageTarget>? OpenPageRequested;

    public SearchResultsView(IQuranRepository repository)
    {
        InitializeComponent();
        _vm = new SearchResultsViewModel(repository);
        _vm.OpenPageRequested += t => OpenPageRequested?.Invoke(t);
        _vm.ResultsChanged += BuildResults;
        DataContext = _vm;

        // عند العودة للتبويب: زامن قائمة الخط وأعد بناء النتائج إن تغيّر الخطّ المطبَّق.
        Loaded += (_, _) =>
        {
            _vm.SelectedFont = AppSettings.Load().SelectedFont; // مزامنة القائمة (بلا إعادة حفظ)
            if (_builtFont.Length > 0 && AppSettings.Load().SelectedFont != _builtFont)
                BuildResults();
        };

        _ = new SearchAutoComplete(SearchBox, SuggestPopup, SuggestList,
            () => _vm.Mode == SearchMode.Root,
            text =>
            {
                _vm.SearchQuery = text;
                if (_vm.SearchCommand.CanExecute(null)) _vm.SearchCommand.Execute(null);
            });
    }

    /// <summary>الخطّ الذي بُنيت به البطاقات (لإعادة البناء عند تغيّر الخطّ المطبَّق).</summary>
    private string _builtFont = string.Empty;

    private void BuildResults()
    {
        ResultsPanel.Children.Clear();
        ResultsScroll.ScrollToTop();

        _builtFont = AppSettings.Load().SelectedFont;
        var font = Services.FontInstaller.Resolve(_builtFont);
        var index = 1;

        foreach (var item in _vm.Results)
            ResultsPanel.Children.Add(BuildCard(item, index++, font));
    }

    private Border BuildCard(AyahItem item, int index, FontFamily font)
    {
        var grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        // ── الشريط العلوي: الرقم + الشارات + الأزرار ──
        var top = new DockPanel { LastChildFill = false, Margin = new Thickness(0, 0, 0, 8) };

        var num = new Border
        {
            Background = GreenBrush,
            CornerRadius = new CornerRadius(13),
            Width = 26,
            Height = 26,
            Child = new TextBlock
            {
                Text = index.ToString(),
                Foreground = System.Windows.Media.Brushes.White,
                FontSize = 12,
                FontWeight = FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
            },
        };
        DockPanel.SetDock(num, Dock.Right);
        top.Children.Add(num);

        top.Children.Add(Badge("الآية", item.NumberInSurah.ToString()));
        top.Children.Add(Badge("الصفحة", item.Page.ToString()));

        var open = LinkButton("فتح الصفحة", GoldBrush);
        open.Click += (_, _) => _vm.OpenPageCommand.Execute(item);
        DockPanel.SetDock(open, Dock.Left);
        top.Children.Add(open);

        var copy = LinkButton("نسخ", GreenBrush);
        copy.Click += (_, _) => _vm.CopyAyahCommand.Execute(item);
        DockPanel.SetDock(copy, Dock.Left);
        top.Children.Add(copy);

        Grid.SetRow(top, 0);
        grid.Children.Add(top);

        // ── نص الآية (بلا تشكيل) مع تمييز كلمة البحث ──
        var text = new TextBlock
        {
            FontFamily = font,
            FontSize = _vm.FontSize,
            Foreground = InkBrush,
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Justify,
            LineHeight = _vm.FontSize * 1.8,
            LineStackingStrategy = LineStackingStrategy.BlockLineHeight,
        };
        FillText(text, item.Ayah.SimpleText.Length > 0
            ? item.Ayah.SimpleText
            : ArabicText.NormalizeLight(item.Ayah.Text));
        text.Inlines.Add(new Run($"  ﴿{ToArabicDigits(item.NumberInSurah)}﴾")
        {
            Foreground = GreenBrush,
            FontWeight = FontWeights.Bold,
        });
        Grid.SetRow(text, 1);
        grid.Children.Add(text);

        return new Border
        {
            Background = CardBrush,
            BorderBrush = CardBorder,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(16, 12, 16, 14),
            Margin = new Thickness(0, 4, 0, 4),
            Child = grid,
        };
    }

    /// <summary>يبني نص الآية مقسّماً إلى كلمات، ويظلّل المطابق حسب وضع البحث.</summary>
    private void FillText(TextBlock target, string text)
    {
        target.Inlines.Clear();
        var enabled = _vm.HighlightEnabled;
        var norm = _vm.HighlightNorm;

        foreach (var word in text.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            var isHit = false;
            if (enabled)
            {
                var n = ArabicText.Normalize(word);
                if (_vm.HighlightForms.Count > 0)            // وضع الجذر
                    isHit = _vm.HighlightForms.Contains(n);
                else if (_vm.HighlightIsPart)               // وضع الجزء: احتواء
                    isHit = norm.Length > 0 && n.Contains(norm, StringComparison.Ordinal);
                else                                        // وضع الكلمة: تطابق تامّ
                    isHit = norm.Length > 0 && n == norm;
            }

            if (isHit)
            {
                target.Inlines.Add(new Run(word + " ")
                {
                    Background = HitBrush,
                    Foreground = GreenBrush,
                    FontWeight = FontWeights.Bold,
                });
            }
            else
            {
                target.Inlines.Add(new Run(word + " "));
            }
        }
    }

    private static Border Badge(string label, string value)
    {
        var panel = new StackPanel { Orientation = System.Windows.Controls.Orientation.Horizontal };
        panel.Children.Add(new TextBlock
        {
            Text = label + " ",
            Foreground = new SolidColorBrush(Color.FromRgb(0x8A, 0x7B, 0x5F)),
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
        });
        panel.Children.Add(new TextBlock
        {
            Text = value,
            Foreground = InkBrush,
            FontSize = 13,
            FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center,
        });
        return new Border
        {
            Background = BadgeBrush,
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(10, 4, 10, 4),
            Margin = new Thickness(0, 0, 8, 0),
            Child = panel,
        };
    }

    private static Button LinkButton(string content, Brush foreground) => new()
    {
        Content = content,
        Foreground = foreground,
        Background = System.Windows.Media.Brushes.Transparent,
        BorderThickness = new Thickness(0),
        Padding = new Thickness(8, 2, 8, 2),
        Margin = new Thickness(2, 0, 0, 0),
        FontSize = 13,
        FontWeight = FontWeights.Bold,
        Cursor = System.Windows.Input.Cursors.Hand,
    };

    private static string ToArabicDigits(int n)
    {
        const string ar = "٠١٢٣٤٥٦٧٨٩";
        var s = n.ToString();
        var chars = new char[s.Length];
        for (var i = 0; i < s.Length; i++)
            chars[i] = char.IsDigit(s[i]) ? ar[s[i] - '0'] : s[i];
        return new string(chars);
    }
}
