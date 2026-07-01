using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using QuranAlKareem.Core.Services;

namespace QuranAlKareem.App.Services;

/// <summary>عنصر اقتراح: النص المعروض + الجذر (إن وُجد) + التكرار.</summary>
public sealed class Suggestion
{
    [JsonPropertyName("t")] public string Text { get; init; } = string.Empty;
    [JsonPropertyName("c")] public int Count { get; init; }
    [JsonPropertyName("r")] public string? Root { get; init; }

    /// <summary>النص المطبّع (يُحسب مرة ويُخزّن للمطابقة السريعة).</summary>
    [JsonIgnore] public string Norm { get; set; } = string.Empty;
}

/// <summary>
/// قاموس كلمات/جذور القرآن (من Data/dictionary.json) — مصدر اقتراحات البحث.
/// يُحمَّل مرة واحدة (كسول) ويُشارك بين كل واجهات البحث.
/// </summary>
public sealed class WordDictionary
{
    private static readonly Lazy<WordDictionary> _instance = new(Load);
    public static WordDictionary Instance => _instance.Value;

    private readonly IReadOnlyList<Suggestion> _words;
    private readonly IReadOnlyList<Suggestion> _roots;

    private WordDictionary(IReadOnlyList<Suggestion> words, IReadOnlyList<Suggestion> roots)
    {
        _words = words;
        _roots = roots;
    }

    private sealed class Payload
    {
        [JsonPropertyName("words")] public List<Suggestion> Words { get; set; } = new();
        [JsonPropertyName("roots")] public List<Suggestion> Roots { get; set; } = new();
    }

    private static WordDictionary Load()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Data", "dictionary.json");
        if (!File.Exists(path))
            return new WordDictionary(Array.Empty<Suggestion>(), Array.Empty<Suggestion>());

        try
        {
            using var stream = File.OpenRead(path);
            var data = JsonSerializer.Deserialize<Payload>(stream) ?? new Payload();
            foreach (var w in data.Words) w.Norm = ArabicText.Normalize(w.Text);
            foreach (var r in data.Roots) r.Norm = ArabicText.Normalize(r.Text);
            return new WordDictionary(data.Words, data.Roots);
        }
        catch
        {
            return new WordDictionary(Array.Empty<Suggestion>(), Array.Empty<Suggestion>());
        }
    }

    /// <summary>
    /// أفضل اقتراحات لنصّ مكتوب. byRoot=true يبحث في الجذور، وإلا في الكلمات.
    /// المطابقة على النص المطبّع: البادئة أولاً ثم الاحتواء، مرتّبة بالتكرار.
    /// </summary>
    public IReadOnlyList<Suggestion> Suggest(string query, bool byRoot, int limit = 10)
    {
        var source = byRoot ? _roots : _words;
        var norm = ArabicText.Normalize(query);
        if (norm.Length == 0 || source.Count == 0) return Array.Empty<Suggestion>();

        // البادئة أهمّ من الاحتواء؛ والمصدر مرتّب أصلاً تنازلياً بالتكرار.
        var prefix = new List<Suggestion>();
        var contains = new List<Suggestion>();
        foreach (var s in source)
        {
            if (s.Norm.StartsWith(norm, StringComparison.Ordinal)) prefix.Add(s);
            else if (s.Norm.Contains(norm, StringComparison.Ordinal)) contains.Add(s);
            if (prefix.Count >= limit) break;
        }

        if (prefix.Count >= limit) return prefix;
        prefix.AddRange(contains.Take(limit - prefix.Count));
        return prefix;
    }
}
