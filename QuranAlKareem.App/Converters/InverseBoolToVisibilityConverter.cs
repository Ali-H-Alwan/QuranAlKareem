using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace QuranAlKareem.App.Converters;

/// <summary>يُظهر العنصر عندما تكون القيمة false (عكس BoolToVisibility).</summary>
public sealed class InverseBoolToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not Visibility.Visible;
}
