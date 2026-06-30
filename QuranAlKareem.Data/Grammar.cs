namespace QuranAlKareem.Data;

/// <summary>
/// يبني إعراباً عربياً لكل مقطع من وسوم Quranic Arabic Corpus:
/// نوع الكلمة + حالتها الإعرابية + علامة الإعراب (مرفوع/منصوب/مجرور…).
/// </summary>
internal static class Grammar
{
    public static string Describe(string tag, string features)
    {
        var t = new HashSet<string>(features.Split('|', StringSplitOptions.RemoveEmptyEntries));

        return tag switch
        {
            "V" => DescribeVerb(t),
            "N" => DescribeNominal(t),
            _   => DescribeParticle(t),
        };
    }

    // ── الأفعال ──────────────────────────────────────────────
    private static string DescribeVerb(HashSet<string> t)
    {
        if (t.Contains("IMPV"))
            return "فعل أمر مبنيّ";

        if (t.Contains("PERF"))
            return "فعل ماضٍ مبنيّ على الفتح";

        if (t.Contains("IMPF"))
        {
            if (t.Contains("MOOD:SUBJ")) return "فعل مضارع منصوب وعلامة نصبه الفتحة";
            if (t.Contains("MOOD:JUS"))  return "فعل مضارع مجزوم وعلامة جزمه السكون";
            return "فعل مضارع مرفوع وعلامة رفعه الضمة";
        }
        return "فعل";
    }

    // ── الأسماء والضمائر ─────────────────────────────────────
    private static string DescribeNominal(HashSet<string> t)
    {
        // المبنيات: لا تتغيّر بالإعراب.
        if (t.Contains("PRON")) return "ضمير مبنيّ";
        if (t.Contains("REL"))  return "اسم موصول مبنيّ";
        if (t.Contains("DEM"))  return "اسم إشارة مبنيّ";

        var kind =
            t.Contains("PN")        ? "اسم علَم" :
            t.Contains("ACT_PCPL")  ? "اسم فاعل" :
            t.Contains("PASS_PCPL") ? "اسم مفعول" :
            t.Contains("ADJ")       ? "صفة" :
                                      "اسم";

        var indef = t.Contains("INDEF") ? "نكرة " : string.Empty;

        if (t.Contains("NOM")) return $"{kind} {indef}مرفوع وعلامة رفعه الضمة";
        if (t.Contains("ACC")) return $"{kind} {indef}منصوب وعلامة نصبه الفتحة";
        if (t.Contains("GEN")) return $"{kind} {indef}مجرور وعلامة جره الكسرة";
        return kind.Trim();
    }

    // ── الحروف والأدوات ──────────────────────────────────────
    private static string DescribeParticle(HashSet<string> t)
    {
        if (t.Contains("DET"))  return "أداة تعريف";
        if (t.Contains("CONJ")) return "حرف عطف مبنيّ لا محلّ له من الإعراب";
        if (t.Contains("NEG"))  return "حرف نفي مبنيّ لا محلّ له من الإعراب";
        if (t.Contains("EXP"))  return "أداة استثناء";
        if (t.Contains("INTG")) return "حرف استفهام";
        if (t.Contains("COND")) return "أداة شرط";
        if (t.Contains("EMPH")) return "لام التوكيد";
        if (t.Contains("VOC"))  return "أداة نداء";
        if (t.Contains("ACC") && t.Contains("FAM")) return "حرف ناصب (من أخوات إنّ)";
        if (t.Contains("SUB"))  return "حرف مصدريّ ونصب";
        if (t.Contains("FUT"))  return "حرف استقبال";
        if (t.Contains("INL"))  return "حروف مقطَّعة";
        if (t.Contains("P"))    return "حرف جرّ مبنيّ";
        return "حرف مبنيّ لا محلّ له من الإعراب";
    }
}
