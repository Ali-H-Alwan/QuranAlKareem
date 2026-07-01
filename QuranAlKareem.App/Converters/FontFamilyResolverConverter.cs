using System.Globalization;
using System.Windows.Data;
using QuranAlKareem.App.Services;
using FontFamily = System.Windows.Media.FontFamily;

namespace QuranAlKareem.App.Converters;

/// <summary>
/// يحوّل اسم خطّ (نص) إلى عائلة خطّ صالحة للعرض، محمّلاً الخطوط المُنزَّلة
/// من ملفاتها مباشرةً (لتظهر في كل التطبيق حتى قبل التثبيت على النظام).
/// </summary>
public sealed class FontFamilyResolverConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is string s && s.Length > 0
            ? FontInstaller.Resolve(s)
            : new FontFamily("Arial");

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is FontFamily f ? f.Source : System.Windows.Data.Binding.DoNothing;
}
