using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Animation;
using QuranAlKareem.App.ViewModels;
using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;
using Brush = System.Windows.Media.Brush;
using Color = System.Windows.Media.Color;
using FontFamily = System.Windows.Media.FontFamily;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;
using UserControl = System.Windows.Controls.UserControl;

namespace QuranAlKareem.App.Views;

/// <summary>تبويب المصحف: تبرير متّصل مثل المصحف الحقيقي مع تلاوة وإعراب وتفسير.</summary>
public partial class MushafView : UserControl
{
    private readonly MushafViewModel _vm;
    private static readonly Brush HoverBrush = new SolidColorBrush(Color.FromRgb(0xF1, 0xE6, 0xC8));
    private static readonly Brush OrnamentBrush = new SolidColorBrush(Color.FromRgb(0x0E, 0x5A, 0x3C));
    private static readonly Brush PlayingBrush = new SolidColorBrush(Color.FromRgb(0xCF, 0xE9, 0xD6));
    private static readonly Brush TargetBrush = new SolidColorBrush(Color.FromRgb(0xFB, 0xEB, 0xB6));

    private readonly Dictionary<(int, int), List<TextElement>> _ayahInlines = new();
    private List<TextElement>? _highlighted;

    /// <summary>الآية المطلوب تمييزها عند الفتح من نتائج البحث (إن وُجدت).</summary>
    private readonly (int Surah, int Ayah)? _target;

    /// <summary>عنوان التبويب (اسم السورة).</summary>
    public string TabTitle { get; }

    public MushafView(IQuranRepository repository, int startPage, (int Surah, int Ayah)? target = null)
    {
        InitializeComponent();
        _target = target;
        _vm = new MushafViewModel(repository, startPage);
        _vm.PageChanged += OnPageChanged;
        _vm.PlayingAyahChanged += HighlightPlaying;
        DataContext = _vm;
        TabTitle = _vm.RightAyahs.Count > 0
            ? $"{_vm.RightAyahs[0].SurahName} • {startPage}"
            : $"صفحة {startPage}";
        OnPageChanged();
    }

    private void OnPageChanged()
    {
        _ayahInlines.Clear();
        _highlighted = null;
        BuildWords(SingleText, _vm.RightAyahs);
        BuildAyahs(TwoRightText, _vm.RightAyahs);
        BuildAyahs(TwoLeftText, _vm.LeftAyahs);
        AnimatePageTurn();
        HighlightTarget();
    }

    /// <summary>يميّز الآية القادمة من نتائج البحث ويمررها إلى مجال الرؤية.</summary>
    private void HighlightTarget()
    {
        if (_target is not { } t) return;
        if (!_ayahInlines.TryGetValue((t.Surah, t.Ayah), out var list)) return;

        foreach (var el in list) el.Background = TargetBrush;

        // التمرير إلى الآية بعد اكتمال التخطيط.
        if (list.Count > 0)
            Dispatcher.BeginInvoke(
                new Action(() => list[0].BringIntoView()),
                System.Windows.Threading.DispatcherPriority.Loaded);
    }

    private void Track(Ayah ayah, TextElement element)
    {
        var key = (ayah.SurahNumber, ayah.NumberInSurah);
        if (!_ayahInlines.TryGetValue(key, out var list))
            _ayahInlines[key] = list = new List<TextElement>();
        list.Add(element);
    }

    private void HighlightPlaying(Ayah? ayah)
    {
        if (_highlighted != null)
            foreach (var el in _highlighted) el.Background = null;
        _highlighted = null;

        if (ayah is null) return;
        if (_ayahInlines.TryGetValue((ayah.SurahNumber, ayah.NumberInSurah), out var list))
        {
            foreach (var el in list) el.Background = PlayingBrush;
            _highlighted = list;
        }
    }

    private void Prepare(TextBlock target)
    {
        target.Inlines.Clear();
        target.FontFamily = new FontFamily(_vm.SelectedFont);
        target.FontSize = _vm.FontSize;
        target.LineHeight = _vm.FontSize * 1.9;
        target.LineStackingStrategy = LineStackingStrategy.BlockLineHeight;
    }

    private Run Ornament(int ayahNumber) => new($" ﴿{ToArabicDigits(ayahNumber)}﴾ ")
    {
        Foreground = OrnamentBrush,
        FontWeight = FontWeights.Bold,
    };

    private void BuildWords(TextBlock target, IEnumerable<Ayah> ayahs)
    {
        if (target is null) return;
        Prepare(target);

        foreach (var ayah in ayahs)
        {
            foreach (var word in _vm.WordsOf(ayah))
            {
                var run = new Run(word.Form + " ") { Cursor = System.Windows.Input.Cursors.Hand };
                var captured = word;
                run.MouseLeftButtonDown += (_, _) => _vm.ShowWordAnalysis(captured);
                run.MouseEnter += (s, _) => { if (!ReferenceEquals(((Run)s).Background, PlayingBrush)) ((Run)s).Background = HoverBrush; };
                run.MouseLeave += (s, _) => { if (!ReferenceEquals(((Run)s).Background, PlayingBrush)) ((Run)s).Background = null; };
                target.Inlines.Add(run);
                Track(ayah, run);
            }
            var orn = Ornament(ayah.NumberInSurah);
            target.Inlines.Add(orn);
            Track(ayah, orn);
        }
    }

    private void BuildAyahs(TextBlock target, IEnumerable<Ayah> ayahs)
    {
        if (target is null) return;
        Prepare(target);

        foreach (var ayah in ayahs)
        {
            var span = new Span { Cursor = System.Windows.Input.Cursors.Hand };
            span.Inlines.Add(new Run(ayah.Text));
            span.Inlines.Add(Ornament(ayah.NumberInSurah));

            var captured = ayah;
            span.ToolTip = "اضغط لنسخ الآية";
            span.MouseLeftButtonDown += (_, _) => _vm.CopyAyah(captured);
            span.MouseEnter += (s, _) => { if (!ReferenceEquals(((Span)s).Background, PlayingBrush)) ((Span)s).Background = HoverBrush; };
            span.MouseLeave += (s, _) => { if (!ReferenceEquals(((Span)s).Background, PlayingBrush)) ((Span)s).Background = null; };
            target.Inlines.Add(span);
            Track(ayah, span);
        }
    }

    private static string ToArabicDigits(int n)
    {
        const string ar = "٠١٢٣٤٥٦٧٨٩";
        var s = n.ToString();
        var chars = new char[s.Length];
        for (var i = 0; i < s.Length; i++)
            chars[i] = char.IsDigit(s[i]) ? ar[s[i] - '0'] : s[i];
        return new string(chars);
    }

    private void AnimatePageTurn()
    {
        SingleScale.ScaleX = 0.0;
        var flip = new DoubleAnimation
        {
            From = 0.0,
            To = 1.0,
            Duration = TimeSpan.FromMilliseconds(280),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut },
        };
        var fade = new DoubleAnimation { From = 0.45, To = 1.0, Duration = TimeSpan.FromMilliseconds(280) };
        SingleScale.BeginAnimation(ScaleTransform.ScaleXProperty, flip);
        SingleCard.BeginAnimation(OpacityProperty, fade);
    }
}
