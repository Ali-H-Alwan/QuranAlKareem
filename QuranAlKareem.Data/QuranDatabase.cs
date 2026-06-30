using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace QuranAlKareem.Data;

/// <summary>تهيئة قاعدة بيانات SQLite وإنشاء المخطط واستيراد نص القرآن.</summary>
public static class QuranDatabase
{
    /// <summary>المسار الافتراضي لملف قاعدة البيانات بجوار التطبيق.</summary>
    public static string DefaultPath =>
        Path.Combine(AppContext.BaseDirectory, "quran.db");

    /// <summary>مسار ملف نص القرآن (JSON) المنسوخ إلى مجلد الإخراج.</summary>
    private static string QuranJsonPath =>
        Path.Combine(AppContext.BaseDirectory, "Data", "quran-uthmani.json");

    /// <summary>مسار ملف التحليل الصرفي (Quranic Arabic Corpus).</summary>
    private static string MorphologyPath =>
        Path.Combine(AppContext.BaseDirectory, "Data", "morphology.txt");

    /// <summary>الرسم الإملائي المبسّط (يُستخدم لفهرسة البحث, لا للعرض).</summary>
    private static string SimpleJsonPath =>
        Path.Combine(AppContext.BaseDirectory, "Data", "quran-simple.json");

    /// <summary>تفسير الميسَّر.</summary>
    private static string TafsirJsonPath =>
        Path.Combine(AppContext.BaseDirectory, "Data", "tafsir-muyassar.json");

    public static string ConnectionString(string? path = null) =>
        new SqliteConnectionStringBuilder { DataSource = path ?? DefaultPath }.ToString();

    /// <summary>ينشئ المخطط إن لم يكن موجوداً، ويستورد النص عند أول تشغيل.</summary>
    public static void EnsureCreated(string? path = null)
    {
        using var conn = new SqliteConnection(ConnectionString(path));
        conn.Open();

        Execute(conn, """
            CREATE TABLE IF NOT EXISTS Surahs (
                Number    INTEGER PRIMARY KEY,
                Name      TEXT NOT NULL,
                AyahCount INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS Ayahs (
                SurahNumber   INTEGER NOT NULL,
                NumberInSurah INTEGER NOT NULL,
                Text          TEXT NOT NULL,
                NormText      TEXT NOT NULL DEFAULT '',
                NormUthmani   TEXT NOT NULL DEFAULT '',
                LightText     TEXT NOT NULL DEFAULT '',
                LightUthmani  TEXT NOT NULL DEFAULT '',
                Page          INTEGER NOT NULL,
                Juz           INTEGER NOT NULL DEFAULT 0,
                Hizb          INTEGER NOT NULL DEFAULT 0,
                Sajda         INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (SurahNumber, NumberInSurah),
                FOREIGN KEY (SurahNumber) REFERENCES Surahs(Number)
            );

            CREATE TABLE IF NOT EXISTS Words (
                SurahNumber INTEGER NOT NULL,
                Ayah        INTEGER NOT NULL,
                WordIndex   INTEGER NOT NULL,
                Form        TEXT NOT NULL,
                NormForm    TEXT NOT NULL,
                Root        TEXT NOT NULL DEFAULT '',
                NormRoot    TEXT NOT NULL DEFAULT '',
                Lemma       TEXT NOT NULL DEFAULT '',
                NormLemma   TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (SurahNumber, Ayah, WordIndex)
            );
            CREATE INDEX IF NOT EXISTS IX_Words_NormRoot ON Words(NormRoot);
            CREATE INDEX IF NOT EXISTS IX_Words_NormForm ON Words(NormForm);
            CREATE INDEX IF NOT EXISTS IX_Words_NormLemma ON Words(NormLemma);

            CREATE TABLE IF NOT EXISTS Tafsir (
                SurahNumber   INTEGER NOT NULL,
                NumberInSurah INTEGER NOT NULL,
                Text          TEXT NOT NULL,
                PRIMARY KEY (SurahNumber, NumberInSurah)
            );

            CREATE TABLE IF NOT EXISTS Segments (
                SurahNumber INTEGER NOT NULL,
                Ayah        INTEGER NOT NULL,
                WordIndex   INTEGER NOT NULL,
                SegIndex    INTEGER NOT NULL,
                Form        TEXT NOT NULL,
                Tag         TEXT NOT NULL,
                Features    TEXT NOT NULL,
                PRIMARY KEY (SurahNumber, Ayah, WordIndex, SegIndex)
            );
            """);

        if (CountRows(conn, "Surahs") == 0)
        {
            if (File.Exists(QuranJsonPath))
                ImportFromJson(conn, QuranJsonPath);
            else
                SeedSample(conn);
        }

        if (CountRows(conn, "Words") == 0 && File.Exists(MorphologyPath))
            ImportMorphology(conn, MorphologyPath);

        if (CountRows(conn, "Tafsir") == 0 && File.Exists(TafsirJsonPath))
            ImportTafsir(conn, TafsirJsonPath);

        BackfillNormText(conn);
    }

    /// <summary>يملأ NormText للآيات التي أُنشئت قبل إضافة العمود (ترقية القواعد القديمة).</summary>
    private static void BackfillNormText(SqliteConnection conn)
    {
        // أضف الأعمدة إن كانت غائبة في قاعدة قديمة.
        foreach (var col in new[] { "NormText", "NormUthmani", "LightText", "LightUthmani" })
            if (!ColumnExists(conn, "Ayahs", col))
                Execute(conn, $"ALTER TABLE Ayahs ADD COLUMN {col} TEXT NOT NULL DEFAULT '';");
        foreach (var col in new[] { "Juz", "Hizb", "Sajda" })
            if (!ColumnExists(conn, "Ayahs", col))
                Execute(conn, $"ALTER TABLE Ayahs ADD COLUMN {col} INTEGER NOT NULL DEFAULT 0;");

        Execute(conn, "CREATE INDEX IF NOT EXISTS IX_Ayahs_NormText ON Ayahs(NormText);");

        // املأ أعمدة الرسم العثماني من نص العرض إن كانت فارغة (ترقية قاعدة قديمة).
        var pending = new List<(int S, int A, string Text)>();
        using (var read = conn.CreateCommand())
        {
            read.CommandText = "SELECT SurahNumber, NumberInSurah, Text FROM Ayahs WHERE NormUthmani = '';";
            using var r = read.ExecuteReader();
            while (r.Read())
                pending.Add((r.GetInt32(0), r.GetInt32(1), r.GetString(2)));
        }
        if (pending.Count == 0) return;

        using var tx = conn.BeginTransaction();
        using var upd = conn.CreateCommand();
        upd.CommandText = """
            UPDATE Ayahs SET
                NormUthmani  = $u,
                LightUthmani = $lu,
                NormText  = CASE WHEN NormText  = '' THEN $u  ELSE NormText  END,
                LightText = CASE WHEN LightText = '' THEN $lu ELSE LightText END
            WHERE SurahNumber = $s AND NumberInSurah = $a;
            """;
        var pU = AddParam(upd, "$u"); var pLU = AddParam(upd, "$lu");
        var pS = AddParam(upd, "$s"); var pA = AddParam(upd, "$a");
        foreach (var (s, a, text) in pending)
        {
            pU.Value = Core.Services.ArabicText.Normalize(text);
            pLU.Value = Core.Services.ArabicText.NormalizeLight(text);
            pS.Value = s; pA.Value = a;
            upd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    private static bool ColumnExists(SqliteConnection conn, string table, string column)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"PRAGMA table_info({table});";
        using var r = cmd.ExecuteReader();
        while (r.Read())
            if (string.Equals(r.GetString(1), column, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    /// <summary>استيراد التحليل الصرفي: كلمات (جذر/ليمة) ومقاطع (للإعراب).</summary>
    private static void ImportMorphology(SqliteConnection conn, string path)
    {
        using var tx = conn.BeginTransaction();

        using var wordCmd = conn.CreateCommand();
        wordCmd.CommandText = """
            INSERT INTO Words (SurahNumber, Ayah, WordIndex, Form, NormForm, Root, NormRoot, Lemma, NormLemma)
            VALUES ($s, $a, $w, $form, $nform, $root, $nroot, $lemma, $nlemma);
            """;
        var ws = AddParam(wordCmd, "$s"); var wa = AddParam(wordCmd, "$a"); var ww = AddParam(wordCmd, "$w");
        var wForm = AddParam(wordCmd, "$form"); var wNForm = AddParam(wordCmd, "$nform");
        var wRoot = AddParam(wordCmd, "$root"); var wNRoot = AddParam(wordCmd, "$nroot");
        var wLemma = AddParam(wordCmd, "$lemma"); var wNLemma = AddParam(wordCmd, "$nlemma");

        using var segCmd = conn.CreateCommand();
        segCmd.CommandText = """
            INSERT INTO Segments (SurahNumber, Ayah, WordIndex, SegIndex, Form, Tag, Features)
            VALUES ($s, $a, $w, $g, $form, $tag, $feat);
            """;
        var ss = AddParam(segCmd, "$s"); var sa = AddParam(segCmd, "$a"); var sw = AddParam(segCmd, "$w");
        var sg = AddParam(segCmd, "$g"); var sForm = AddParam(segCmd, "$form");
        var sTag = AddParam(segCmd, "$tag"); var sFeat = AddParam(segCmd, "$feat");

        // تجميع المقاطع حسب الكلمة (sura:aya:word).
        int curS = 0, curA = 0, curW = 0;
        var formBuilder = new System.Text.StringBuilder();
        string root = "", lemma = "";

        void FlushWord()
        {
            if (curW == 0) return;
            var form = formBuilder.ToString();
            ws.Value = curS; wa.Value = curA; ww.Value = curW;
            wForm.Value = form; wNForm.Value = Core.Services.ArabicText.Normalize(form);
            wRoot.Value = root; wNRoot.Value = Core.Services.ArabicText.Normalize(root);
            wLemma.Value = lemma; wNLemma.Value = Core.Services.ArabicText.Normalize(lemma);
            wordCmd.ExecuteNonQuery();
        }

        foreach (var raw in File.ReadLines(path))
        {
            var line = raw.TrimEnd('\n', '\r');
            if (line.Length == 0 || line[0] == '#') continue;
            var cols = line.Split('\t');
            if (cols.Length < 4) continue;

            var loc = cols[0].Split(':');
            if (loc.Length < 4) continue;
            if (!int.TryParse(loc[0], out var s) || !int.TryParse(loc[1], out var a)
                || !int.TryParse(loc[2], out var w) || !int.TryParse(loc[3], out var g))
                continue;

            var form = cols[1];
            var tag = cols[2];
            var features = cols[3];

            // كلمة جديدة؟
            if (s != curS || a != curA || w != curW)
            {
                FlushWord();
                curS = s; curA = a; curW = w;
                formBuilder.Clear();
                root = ""; lemma = "";
            }

            formBuilder.Append(form);
            foreach (var token in features.Split('|'))
            {
                if (token.StartsWith("ROOT:", StringComparison.Ordinal) && root.Length == 0)
                    root = token[5..];
                else if (token.StartsWith("LEM:", StringComparison.Ordinal) && lemma.Length == 0)
                    lemma = token[4..];
            }

            ss.Value = s; sa.Value = a; sw.Value = w; sg.Value = g;
            sForm.Value = form; sTag.Value = tag; sFeat.Value = features;
            segCmd.ExecuteNonQuery();
        }
        FlushWord();

        tx.Commit();
    }

    /// <summary>استيراد تفسير الميسَّر (آية بآية).</summary>
    private static void ImportTafsir(SqliteConnection conn, string path)
    {
        using var stream = File.OpenRead(path);
        using var doc = JsonDocument.Parse(stream);
        var surahs = doc.RootElement.GetProperty("data").GetProperty("surahs");

        using var tx = conn.BeginTransaction();
        using var cmd = conn.CreateCommand();
        cmd.CommandText =
            "INSERT INTO Tafsir (SurahNumber, NumberInSurah, Text) VALUES ($s, $a, $t);";
        var pS = AddParam(cmd, "$s"); var pA = AddParam(cmd, "$a"); var pT = AddParam(cmd, "$t");

        foreach (var surah in surahs.EnumerateArray())
        {
            var n = surah.GetProperty("number").GetInt32();
            foreach (var ayah in surah.GetProperty("ayahs").EnumerateArray())
            {
                pS.Value = n;
                pA.Value = ayah.GetProperty("numberInSurah").GetInt32();
                pT.Value = ayah.GetProperty("text").GetString() ?? string.Empty;
                cmd.ExecuteNonQuery();
            }
        }
        tx.Commit();
    }

    private static Dictionary<string, string> LoadSimpleText()
    {
        var map = new Dictionary<string, string>();
        if (!File.Exists(SimpleJsonPath)) return map;

        using var stream = File.OpenRead(SimpleJsonPath);
        using var doc = JsonDocument.Parse(stream);
        var surahs = doc.RootElement.GetProperty("data").GetProperty("surahs");
        foreach (var surah in surahs.EnumerateArray())
        {
            var n = surah.GetProperty("number").GetInt32();
            foreach (var ayah in surah.GetProperty("ayahs").EnumerateArray())
            {
                var num = ayah.GetProperty("numberInSurah").GetInt32();
                map[$"{n}:{num}"] = ayah.GetProperty("text").GetString() ?? string.Empty;
            }
        }
        return map;
    }

    private static SqliteParameter AddParam(SqliteCommand cmd, string name)
    {
        var p = cmd.CreateParameter();
        p.ParameterName = name;
        cmd.Parameters.Add(p);
        return p;
    }

    /// <summary>استيراد النص الكامل من ملف AlQuran Cloud (quran-uthmani.json).</summary>
    private static void ImportFromJson(SqliteConnection conn, string jsonPath)
    {
        using var stream = File.OpenRead(jsonPath);
        using var doc = JsonDocument.Parse(stream);
        var surahs = doc.RootElement.GetProperty("data").GetProperty("surahs");

        // الرسم المبسّط لفهرسة البحث (إن وُجد): المفتاح "سورة:آية" → النص.
        var simpleText = LoadSimpleText();

        using var tx = conn.BeginTransaction();

        using var surahCmd = conn.CreateCommand();
        surahCmd.CommandText =
            "INSERT INTO Surahs (Number, Name, AyahCount) VALUES ($n, $name, $count);";
        var pN = surahCmd.CreateParameter(); pN.ParameterName = "$n"; surahCmd.Parameters.Add(pN);
        var pName = surahCmd.CreateParameter(); pName.ParameterName = "$name"; surahCmd.Parameters.Add(pName);
        var pCount = surahCmd.CreateParameter(); pCount.ParameterName = "$count"; surahCmd.Parameters.Add(pCount);

        using var ayahCmd = conn.CreateCommand();
        ayahCmd.CommandText = """
            INSERT INTO Ayahs (SurahNumber, NumberInSurah, Text, NormText, NormUthmani, LightText, LightUthmani, Page, Juz, Hizb, Sajda)
            VALUES ($s, $num, $text, $ntext, $nuth, $ltext, $luth, $page, $juz, $hizb, $sajda);
            """;
        var aS = ayahCmd.CreateParameter(); aS.ParameterName = "$s"; ayahCmd.Parameters.Add(aS);
        var aNum = ayahCmd.CreateParameter(); aNum.ParameterName = "$num"; ayahCmd.Parameters.Add(aNum);
        var aText = ayahCmd.CreateParameter(); aText.ParameterName = "$text"; ayahCmd.Parameters.Add(aText);
        var aNText = ayahCmd.CreateParameter(); aNText.ParameterName = "$ntext"; ayahCmd.Parameters.Add(aNText);
        var aNUth = ayahCmd.CreateParameter(); aNUth.ParameterName = "$nuth"; ayahCmd.Parameters.Add(aNUth);
        var aLText = ayahCmd.CreateParameter(); aLText.ParameterName = "$ltext"; ayahCmd.Parameters.Add(aLText);
        var aLUth = ayahCmd.CreateParameter(); aLUth.ParameterName = "$luth"; ayahCmd.Parameters.Add(aLUth);
        var aPage = ayahCmd.CreateParameter(); aPage.ParameterName = "$page"; ayahCmd.Parameters.Add(aPage);
        var aJuz = ayahCmd.CreateParameter(); aJuz.ParameterName = "$juz"; ayahCmd.Parameters.Add(aJuz);
        var aHizb = ayahCmd.CreateParameter(); aHizb.ParameterName = "$hizb"; ayahCmd.Parameters.Add(aHizb);
        var aSajda = ayahCmd.CreateParameter(); aSajda.ParameterName = "$sajda"; ayahCmd.Parameters.Add(aSajda);

        foreach (var surah in surahs.EnumerateArray())
        {
            var ayahs = surah.GetProperty("ayahs");
            pN.Value = surah.GetProperty("number").GetInt32();
            pName.Value = surah.GetProperty("name").GetString() ?? string.Empty;
            pCount.Value = ayahs.GetArrayLength();
            surahCmd.ExecuteNonQuery();

            var surahNumber = surah.GetProperty("number").GetInt32();
            aS.Value = surahNumber;
            foreach (var ayah in ayahs.EnumerateArray())
            {
                var num = ayah.GetProperty("numberInSurah").GetInt32();
                var text = ayah.GetProperty("text").GetString() ?? string.Empty;
                // فهرسة البحث على الرسم المبسّط إن توفّر، وإلا على نص العرض.
                var indexSource = simpleText.GetValueOrDefault($"{surahNumber}:{num}", text);

                aNum.Value = num;
                aText.Value = text;
                aNText.Value = Core.Services.ArabicText.Normalize(indexSource);      // إملائي مُوحَّد
                aNUth.Value = Core.Services.ArabicText.Normalize(text);              // عثماني مُوحَّد
                aLText.Value = Core.Services.ArabicText.NormalizeLight(indexSource); // إملائي حسب المكتوب
                aLUth.Value = Core.Services.ArabicText.NormalizeLight(text);         // عثماني حسب المكتوب
                aPage.Value = ayah.GetProperty("page").GetInt32();
                aJuz.Value = ayah.TryGetProperty("juz", out var juzEl) ? juzEl.GetInt32() : 0;
                aHizb.Value = ayah.TryGetProperty("hizbQuarter", out var hizbEl) ? hizbEl.GetInt32() : 0;
                // sajda: تكون false أو كائناً يحوي تفاصيل السجدة.
                aSajda.Value = ayah.TryGetProperty("sajda", out var sajdaEl)
                    && sajdaEl.ValueKind == JsonValueKind.Object ? 1 : 0;
                ayahCmd.ExecuteNonQuery();
            }
        }

        tx.Commit();
    }

    // بذرة احتياطية: سورة الفاتحة، تُستخدم فقط إذا غاب ملف النص الكامل.
    private static void SeedSample(SqliteConnection conn)
    {
        using var tx = conn.BeginTransaction();
        Execute(conn, "INSERT INTO Surahs (Number, Name, AyahCount) VALUES (1, 'سورة الفاتحة', 7);");

        string[] fatiha =
        {
            "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
            "الرَّحْمَٰنِ الرَّحِيمِ",
            "مَالِكِ يَوْمِ الدِّينِ",
            "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
            "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ",
            "صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ",
        };
        for (var i = 0; i < fatiha.Length; i++)
        {
            using var cmd = conn.CreateCommand();
            cmd.CommandText =
                "INSERT INTO Ayahs (SurahNumber, NumberInSurah, Text, Page) VALUES (1, $n, $t, 1);";
            cmd.Parameters.AddWithValue("$n", i + 1);
            cmd.Parameters.AddWithValue("$t", fatiha[i]);
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    private static void Execute(SqliteConnection conn, string sql)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.ExecuteNonQuery();
    }

    private static long CountRows(SqliteConnection conn, string table)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = $"SELECT COUNT(*) FROM {table};";
        return (long)(cmd.ExecuteScalar() ?? 0L);
    }
}
