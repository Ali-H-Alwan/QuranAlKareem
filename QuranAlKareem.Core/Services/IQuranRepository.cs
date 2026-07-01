using QuranAlKareem.Core.Models;

namespace QuranAlKareem.Core.Services;

/// <summary>مصدر بيانات القرآن الكريم (قراءة فقط).</summary>
public interface IQuranRepository
{
    IReadOnlyList<Surah> GetSurahs();
    IReadOnlyList<Ayah> GetAyahsBySurah(int surahNumber);

    /// <summary>
    /// بحث نصّي في جميع الآيات وفق خيارات البحث.
    /// wholeWord=true يطابق الكلمة الكاملة (ضمن حدود المسافات)، وإلا احتواء (جزء من كلمة).
    /// </summary>
    IReadOnlyList<Ayah> SearchText(string query, SearchOptions options, bool wholeWord = false);

    /// <summary>بحث بجذر الكلمة: يرجع كل الآيات الحاوية لكلمة من نفس الجذر.</summary>
    IReadOnlyList<Ayah> SearchByRoot(string word);

    /// <summary>الأشكال المطبّعة (NormForm) لكل الكلمات المشتقّة من جذر الكلمة — للتظليل.</summary>
    IReadOnlyList<string> NormFormsOfRoots(string word);

    /// <summary>الجذور المطابقة لكلمة مُدخلة (للعرض عند البحث بالجذر).</summary>
    IReadOnlyList<string> FindRoots(string word);

    /// <summary>التحليل الصرفي/الإعراب لكلمة بحسب موقعها، أو لأول كلمة من جذر مُعطى.</summary>
    WordAnalysis? GetAnalysisForRoot(string root);

    /// <summary>كلمات آية معيّنة مرتّبة (لعرضها قابلة للنقر).</summary>
    IReadOnlyList<QuranWord> GetWords(int surahNumber, int ayah);

    /// <summary>التحليل الصرفي/الإعراب لكلمة محدّدة بموقعها.</summary>
    WordAnalysis? GetAnalysisForWord(int surahNumber, int ayah, int wordIndex);

    /// <summary>آيات صفحة المصحف (مرتّبة)، مع اسم السورة.</summary>
    IReadOnlyList<Ayah> GetAyahsByPage(int page);

    /// <summary>عدد صفحات المصحف.</summary>
    int PageCount { get; }

    /// <summary>معلومات وإحصائيات صفحة معيّنة.</summary>
    PageInfo GetPageInfo(int page);

    /// <summary>تفسير الميسَّر لآية معيّنة (أو null إن لم يوجد).</summary>
    string? GetTafsir(int surahNumber, int ayah);
}
