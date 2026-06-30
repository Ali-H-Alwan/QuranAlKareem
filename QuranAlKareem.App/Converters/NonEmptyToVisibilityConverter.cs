using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace QuranAlKareem.App.Converters;

/// <summary>يُظهر العنصر إذا كانت السلسلة غير فارغة، وإلا يُخفيه.</summary>
public sealed class NonEmptyToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => string.IsNullOrWhiteSpace(value as string) ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
