using System.Globalization;
using System.Windows.Data;
using Binding = System.Windows.Data.Binding;

namespace QuranAlKareem.App.Converters;

/// <summary>
/// يربط أزراراً راديوية بخاصية من نوع enum: كل زر يمرّر اسم القيمة عبر ConverterParameter.
/// </summary>
public sealed class EnumBooleanConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value?.ToString() == parameter?.ToString();

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true && parameter is not null
            ? Enum.Parse(targetType, parameter.ToString()!)
            : Binding.DoNothing;
}
