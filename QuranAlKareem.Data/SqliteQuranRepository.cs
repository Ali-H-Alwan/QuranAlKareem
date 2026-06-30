using Microsoft.Data.Sqlite;
using QuranAlKareem.Core.Models;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.Data;

/// <summary>تنفيذ مستودع القرآن فوق قاعدة بيانات SQLite.</summary>
public sealed class SqliteQuranRepository : IQuranRepository
{
    private readonly string _connectionString;

    public SqliteQuranRepository(string? path = null)
        => _connectionString = QuranDatabase.ConnectionString(path);

    public IReadOnlyList<Surah> GetSurahs()
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT Number, Name, AyahCount FROM Surahs ORDER BY Number;";

        var result = new List<Surah>();
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
            result.Add(new Surah
            {
                Number = reader.GetInt32(0),
                Name = reader.GetString(1),
                AyahCount = reader.GetInt32(2),
            });
        return result;
    }

    public IReadOnlyList<Ayah> GetAyahsBySurah(int surahNumber)
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            SELECT a.SurahNumber, s.Name, a.NumberInSurah, a.Text, a.Page
            FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
            WHERE a.SurahNumber = $s
            ORDER BY a.NumberInSurah;
            """;
        cmd.Parameters.AddWithValue("$s", surahNumber);
        return ReadAyahs(cmd);
    }

    public IReadOnlyList<Ayah> SearchText(string query, SearchOptions options)
    {
        if (string.IsNullOrWhiteSpace(query))
            return Array.Empty<Ayah>();

        // اختيار طريقة التطبيع والأعمدة بحسب الإعدادات.
        var norm = options.FoldLetters
            ? ArabicText.Normalize(query)       // توحيد ة/ه والألفات والياء
            : ArabicText.NormalizeLight(query); // حسب المكتوب (تشكيل فقط)
        if (norm.Length == 0) return Array.Empty<Ayah>();

        // إملائي/عثماني مُوحَّد أو خفيف.
        var imlaaiCol = options.FoldLetters ? "NormText" : "LightText";
        var uthmaniCol = options.FoldLetters ? "NormUthmani" : "LightUthmani";

        // البحث بالرسمين معاً، أو على المكتوب فقط (العثماني = نص المصحف المعروض).
        var where = options.BothRasm
            ? $"a.{imlaaiCol} LIKE $q OR a.{uthmaniCol} LIKE $q"
            : $"a.{uthmaniCol} LIKE $q";

        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"""
            SELECT a.SurahNumber, s.Name, a.NumberInSurah, a.Text, a.Page
            FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
            WHERE {where}
            ORDER BY a.SurahNumber, a.NumberInSurah;
            """;
        cmd.Parameters.AddWithValue("$q", $"%{norm}%");
        return ReadAyahs(cmd);
    }

    public IReadOnlyList<string> FindRoots(string word)
    {
        var norm = ArabicText.Normalize(word);
        if (norm.Length == 0) return Array.Empty<string>();

        using var conn = Open();

        // مطابقة متدرّجة لتفادي النتائج الكاذبة: نبدأ بالأدقّ، ولا ننزل لمطابقة
        // الاحتواء (LIKE) إلا إذا لم نجد أي تطابق تامّ. وإلا فإن كلمةً مثل «بِخَلْقِ»
        // (الباء + خلق ⇐ المطبّع «بخلق») تطابق LIKE %بخل% فيظهر جذر «خلق» خطأً
        // عند البحث عن «بخل».
        // 1) المُدخل جذر تامّ.  2) شكل/ليمة كلمة تامّ.  3) احتواء (أخير، عند غياب التطابق التامّ).
        var roots = QueryRoots(conn, "NormRoot = $n", norm);
        if (roots.Count == 0)
            roots = QueryRoots(conn, "NormLemma = $n OR NormForm = $n", norm);
        if (roots.Count == 0)
            roots = QueryRoots(conn, "NormLemma LIKE $like OR NormForm LIKE $like", norm);
        return roots;
    }

    private static List<string> QueryRoots(SqliteConnection conn, string condition, string norm)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"""
            SELECT DISTINCT Root FROM Words
            WHERE Root <> '' AND ({condition})
            ORDER BY Root;
            """;
        cmd.Parameters.AddWithValue("$n", norm);
        cmd.Parameters.AddWithValue("$like", $"%{norm}%");

        var roots = new List<string>();
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
            roots.Add(reader.GetString(0));
        return roots;
    }

    public IReadOnlyList<Ayah> SearchByRoot(string word)
    {
        var roots = FindRoots(word);
        if (roots.Count == 0) return Array.Empty<Ayah>();

        using var conn = Open();
        using var cmd = conn.CreateCommand();
        var placeholders = string.Join(",", roots.Select((_, i) => $"$r{i}"));
        cmd.CommandText = $"""
            SELECT a.SurahNumber, s.Name, a.NumberInSurah, a.Text, a.Page
            FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
            WHERE EXISTS (
                SELECT 1 FROM Words w
                WHERE w.SurahNumber = a.SurahNumber AND w.Ayah = a.NumberInSurah
                  AND w.Root IN ({placeholders})
            )
            ORDER BY a.SurahNumber, a.NumberInSurah;
            """;
        for (var i = 0; i < roots.Count; i++)
            cmd.Parameters.AddWithValue($"$r{i}", roots[i]);
        return ReadAyahs(cmd);
    }

    public WordAnalysis? GetAnalysisForRoot(string root)
    {
        using var conn = Open();

        // أول كلمة تحمل هذا الجذر.
        using var locate = conn.CreateCommand();
        locate.CommandText = """
            SELECT SurahNumber, Ayah, WordIndex, Form, Root, Lemma FROM Words
            WHERE Root = $r ORDER BY SurahNumber, Ayah, WordIndex LIMIT 1;
            """;
        locate.Parameters.AddWithValue("$r", root);
        using var lr = locate.ExecuteReader();
        if (!lr.Read()) return null;

        int s = lr.GetInt32(0), a = lr.GetInt32(1), w = lr.GetInt32(2);
        string form = lr.GetString(3), rt = lr.GetString(4), lemma = lr.GetString(5);
        lr.Close();

        return new WordAnalysis { Form = form, Root = rt, Lemma = lemma, Segments = LoadSegments(conn, s, a, w) };
    }

    public IReadOnlyList<QuranWord> GetWords(int surahNumber, int ayah)
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            SELECT WordIndex, Form FROM Words
            WHERE SurahNumber = $s AND Ayah = $a ORDER BY WordIndex;
            """;
        cmd.Parameters.AddWithValue("$s", surahNumber);
        cmd.Parameters.AddWithValue("$a", ayah);

        var words = new List<QuranWord>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            words.Add(new QuranWord
            {
                SurahNumber = surahNumber,
                Ayah = ayah,
                WordIndex = r.GetInt32(0),
                Form = r.GetString(1),
            });
        return words;
    }

    public WordAnalysis? GetAnalysisForWord(int surahNumber, int ayah, int wordIndex)
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            SELECT Form, Root, Lemma FROM Words
            WHERE SurahNumber = $s AND Ayah = $a AND WordIndex = $w;
            """;
        cmd.Parameters.AddWithValue("$s", surahNumber);
        cmd.Parameters.AddWithValue("$a", ayah);
        cmd.Parameters.AddWithValue("$w", wordIndex);
        using var r = cmd.ExecuteReader();
        if (!r.Read()) return null;
        string form = r.GetString(0), root = r.GetString(1), lemma = r.GetString(2);
        r.Close();

        return new WordAnalysis
        {
            Form = form, Root = root, Lemma = lemma,
            Segments = LoadSegments(conn, surahNumber, ayah, wordIndex),
        };
    }

    private static List<SegmentInfo> LoadSegments(SqliteConnection conn, int s, int a, int w)
    {
        using var seg = conn.CreateCommand();
        seg.CommandText = """
            SELECT Form, Tag, Features FROM Segments
            WHERE SurahNumber = $s AND Ayah = $a AND WordIndex = $w ORDER BY SegIndex;
            """;
        seg.Parameters.AddWithValue("$s", s);
        seg.Parameters.AddWithValue("$a", a);
        seg.Parameters.AddWithValue("$w", w);

        var segments = new List<SegmentInfo>();
        using var sr = seg.ExecuteReader();
        while (sr.Read())
        {
            var feat = sr.GetString(2);
            segments.Add(new SegmentInfo
            {
                Form = sr.GetString(0),
                Features = feat,
                Description = Grammar.Describe(sr.GetString(1), feat),
            });
        }
        return segments;
    }

    public IReadOnlyList<Ayah> GetAyahsByPage(int page)
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            SELECT a.SurahNumber, s.Name, a.NumberInSurah, a.Text, a.Page
            FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
            WHERE a.Page = $p
            ORDER BY a.SurahNumber, a.NumberInSurah;
            """;
        cmd.Parameters.AddWithValue("$p", page);
        return ReadAyahs(cmd);
    }

    public PageInfo GetPageInfo(int page)
    {
        using var conn = Open();

        var surahs = new List<string>();
        var juz = new SortedSet<int>();
        var hizbQ = new SortedSet<int>();
        int ayahCount = 0, sajda = 0, letters = 0;

        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = """
                SELECT s.Name, a.Juz, a.Hizb, a.Sajda, a.LightUthmani
                FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
                WHERE a.Page = $p
                ORDER BY a.SurahNumber, a.NumberInSurah;
                """;
            cmd.Parameters.AddWithValue("$p", page);
            using var r = cmd.ExecuteReader();
            while (r.Read())
            {
                var name = r.GetString(0);
                if (surahs.Count == 0 || surahs[^1] != name) surahs.Add(name);
                if (!r.IsDBNull(1) && r.GetInt32(1) > 0) juz.Add(r.GetInt32(1));
                if (!r.IsDBNull(2) && r.GetInt32(2) > 0) hizbQ.Add(r.GetInt32(2));
                sajda += r.GetInt32(3);
                ayahCount++;
                foreach (var ch in r.GetString(4))
                    if (ch is >= 'ء' and <= 'ي') letters++;
            }
        }

        int words = 0;
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = """
                SELECT COUNT(*) FROM Words w
                JOIN Ayahs a ON a.SurahNumber = w.SurahNumber AND a.NumberInSurah = w.Ayah
                WHERE a.Page = $p;
                """;
            cmd.Parameters.AddWithValue("$p", page);
            words = System.Convert.ToInt32(cmd.ExecuteScalar() ?? 0);
        }

        // تحويل ربع الحزب (1..240) إلى وصف: الحزب والربع.
        var hizbLabels = new List<string>();
        var seenHizb = new SortedSet<int>();
        foreach (var hq in hizbQ)
        {
            var hizb = (hq - 1) / 4 + 1;
            if (seenHizb.Add(hizb)) hizbLabels.Add($"الحزب {hizb}");
        }

        return new PageInfo
        {
            Page = page,
            Surahs = surahs,
            Juz = juz.Select(j => $"الجزء {j}").ToList(),
            HizbQuarters = hizbLabels,
            AyahCount = ayahCount,
            WordCount = words,
            LetterCount = letters,
            SajdaCount = sajda,
        };
    }

    public string? GetTafsir(int surahNumber, int ayah)
    {
        using var conn = Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT Text FROM Tafsir WHERE SurahNumber = $s AND NumberInSurah = $a;";
        cmd.Parameters.AddWithValue("$s", surahNumber);
        cmd.Parameters.AddWithValue("$a", ayah);
        return cmd.ExecuteScalar() as string;
    }

    public int PageCount
    {
        get
        {
            using var conn = Open();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT COALESCE(MAX(Page), 0) FROM Ayahs;";
            return System.Convert.ToInt32(cmd.ExecuteScalar() ?? 0);
        }
    }

    private static List<Ayah> ReadAyahs(SqliteCommand cmd)
    {
        var result = new List<Ayah>();
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
            result.Add(new Ayah
            {
                SurahNumber = reader.GetInt32(0),
                SurahName = reader.GetString(1),
                NumberInSurah = reader.GetInt32(2),
                Text = reader.GetString(3),
                Page = reader.GetInt32(4),
            });
        return result;
    }

    private SqliteConnection Open()
    {
        var conn = new SqliteConnection(_connectionString);
        conn.Open();
        return conn;
    }
}
