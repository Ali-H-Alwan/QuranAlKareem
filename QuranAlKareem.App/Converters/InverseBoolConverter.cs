using System.Globalization;
using System.Windows.Data;

namespace QuranAlKareem.App.Converters;

/// <summary>يعكس قيمة منطقية (للأزرار الراديوية المتقابلة).</summary>
public sealed class InverseBoolConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not true;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not true;
}
