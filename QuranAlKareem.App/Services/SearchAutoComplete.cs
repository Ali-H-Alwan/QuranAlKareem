using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using KeyEventArgs = System.Windows.Input.KeyEventArgs;
using MouseButtonEventArgs = System.Windows.Input.MouseButtonEventArgs;
using TextBox = System.Windows.Controls.TextBox;
using ListBox = System.Windows.Controls.ListBox;
using TextChangedEventArgs = System.Windows.Controls.TextChangedEventArgs;

namespace QuranAlKareem.App.Services;

/// <summary>
/// يربط اقتراحات القاموس (autocomplete) بصندوق بحث + قائمة منبثقة.
/// مشترك بين واجهتَي البحث ليتطابق سلوكهما تماماً.
/// </summary>
public sealed class SearchAutoComplete
{
    private readonly TextBox _box;
    private readonly Popup _popup;
    private readonly ListBox _list;
    private readonly Func<bool> _byRoot;
    private readonly Action<string> _commit;
    private bool _applying;

    /// <param name="byRoot">هل الوضع الحالي بحث بالجذر؟</param>
    /// <param name="commit">يعبّئ نص البحث وينفّذه عند اختيار اقتراح.</param>
    public SearchAutoComplete(TextBox box, Popup popup, ListBox list,
                              Func<bool> byRoot, Action<string> commit)
    {
        _box = box;
        _popup = popup;
        _list = list;
        _byRoot = byRoot;
        _commit = commit;

        _box.TextChanged += OnTextChanged;
        _box.PreviewKeyDown += OnBoxKeyDown;
        _box.LostFocus += (_, _) => _popup.IsOpen = false;
        _list.PreviewKeyDown += OnListKeyDown;
        _list.PreviewMouseLeftButtonUp += OnListClicked;
    }

    private void OnTextChanged(object sender, TextChangedEventArgs e)
    {
        if (_applying) return;
        var items = WordDictionary.Instance.Suggest(_box.Text, _byRoot());
        if (items.Count == 0) { _popup.IsOpen = false; return; }
        _list.ItemsSource = items;
        _list.SelectedIndex = -1;
        _popup.IsOpen = true;
    }

    private void OnBoxKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape) { _popup.IsOpen = false; return; }
        // السهم لأسفل ينقل التركيز إلى القائمة.
        if (e.Key == Key.Down && _popup.IsOpen && _list.Items.Count > 0)
        {
            _list.SelectedIndex = 0;
            (_list.ItemContainerGenerator.ContainerFromIndex(0) as ListBoxItem)?.Focus();
            e.Handled = true;
        }
    }

    private void OnListKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key is Key.Enter or Key.Tab) { Apply(); e.Handled = true; }
        else if (e.Key == Key.Escape) { _popup.IsOpen = false; _box.Focus(); }
    }

    private void OnListClicked(object sender, MouseButtonEventArgs e)
    {
        // النقر قد يسبق تحديث SelectedItem؛ نحلّ العنصر من مصدر النقر.
        if (_list.SelectedItem is null &&
            e.OriginalSource is DependencyObject src &&
            ItemsControl.ContainerFromElement(_list, src) is ListBoxItem li)
            _list.SelectedItem = li.DataContext;
        Apply();
    }

    private void Apply()
    {
        if (_list.SelectedItem is not Suggestion s) return;
        _applying = true;          // يمنع إعادة فتح القائمة أثناء التعبئة
        _commit(s.Text);
        _applying = false;
        _popup.IsOpen = false;
        _box.Focus();
        _box.CaretIndex = _box.Text.Length;
    }
}
