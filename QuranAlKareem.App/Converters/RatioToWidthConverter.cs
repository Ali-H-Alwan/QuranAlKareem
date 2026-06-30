using System.Globalization;
using System.Windows.Data;

namespace QuranAlKareem.App.Converters;

/// <summary>يحوّل نسبة (0..1) إلى عرض بالبكسل لشريط الإحصائية.</summary>
public sealed class RatioToWidthConverter : IValueConverter
{
    private const double MaxWidth = 200.0;

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var ratio = value is double d ? d : 0.0;
        // حدّ أدنى بسيط حتى يظهر اسم السورة.
        return Math.Max(46.0, ratio * MaxWidth);
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
