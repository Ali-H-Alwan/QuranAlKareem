namespace QuranAlKareem.Core.Services;

/// <summary>وضع البحث الذي يختاره المستخدم.</summary>
public enum SearchMode
{
    /// <summary>كلمة كاملة: يطابق الكلمة كما كُتبت فقط (طه ⇐ طه/طة).</summary>
    Word,

    /// <summary>جزء من كلمة: احتواء (طه ⇐ طهورا وغيرها).</summary>
    Part,

    /// <summary>الجذر: كل الكلمات المشتقّة من الجذر نفسه.</summary>
    Root,
}
