using QuranAlKareem.App.Services;
using QuranAlKareem.App.ViewModels;
using QuranAlKareem.Core.Services;
using UserControl = System.Windows.Controls.UserControl;

namespace QuranAlKareem.App.Views;

/// <summary>تبويب البحث (نفس واجهة البحث السابقة).</summary>
public partial class SearchView : UserControl
{
    private readonly MainViewModel _vm;

    /// <summary>يُطلب فتح صفحة المصحف في تبويب جديد (مع تمييز الآية).</summary>
    public event Action<PageTarget>? OpenPageRequested;

    /// <summary>يُطلب فتح صفحة الإعدادات في تبويب.</summary>
    public event Action? OpenSettingsRequested;

    public SearchView(IQuranRepository repository)
    {
        InitializeComponent();
        _vm = new MainViewModel(repository);
        _vm.OpenPageRequested += t => OpenPageRequested?.Invoke(t);
        _vm.OpenSettingsRequested += () => OpenSettingsRequested?.Invoke();
        DataContext = _vm;

        _ = new SearchAutoComplete(SearchBox, SuggestPopup, SuggestList,
            () => _vm.Mode == SearchMode.Root,
            text =>
            {
                _vm.SearchQuery = text;
                if (_vm.SearchCommand.CanExecute(null)) _vm.SearchCommand.Execute(null);
            });
    }

    /// <summary>يمنع قائمة النتائج من التمرير التلقائي عند النقر داخل عنصر.</summary>
    private void OnItemRequestBringIntoView(object sender, System.Windows.RequestBringIntoViewEventArgs e)
        => e.Handled = true;
}
