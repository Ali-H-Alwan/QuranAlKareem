using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace QuranAlKareem.App.Audio;

/// <summary>إدارة ذاكرة الصوت المحلية: الحجم، الحذف، والتحميل الكامل المسبق.</summary>
public static class AudioLibrary
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public static string Root
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "QuranAlKareem", "audio");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    private static string FolderDir(string folder)
    {
        var dir = Path.Combine(Root, folder);
        Directory.CreateDirectory(dir);
        return dir;
    }

    /// <summary>عدد الملفات والحجم بالميغابايت لقارئ معيّن.</summary>
    public static (int Files, double Megabytes) Stats(string folder)
    {
        var dir = Path.Combine(Root, folder);
        if (!Directory.Exists(dir)) return (0, 0);
        var files = Directory.GetFiles(dir, "*.mp3");
        long bytes = 0;
        foreach (var f in files) bytes += new FileInfo(f).Length;
        return (files.Length, Math.Round(bytes / 1024.0 / 1024.0, 1));
    }

    public static void Clear(string folder)
    {
        var dir = Path.Combine(Root, folder);
        if (Directory.Exists(dir)) Directory.Delete(dir, recursive: true);
    }

    public static void ClearAll()
    {
        if (Directory.Exists(Root)) Directory.Delete(Root, recursive: true);
    }

    public static string FileFor(string folder, int surah, int ayah) =>
        Path.Combine(FolderDir(folder), $"{surah:D3}{ayah:D3}.mp3");

    private static string UrlFor(string folder, int surah, int ayah) =>
        $"https://everyayah.com/data/{folder}/{surah:D3}{ayah:D3}.mp3";

    public static bool IsCached(string folder, int surah, int ayah)
    {
        var path = FileFor(folder, surah, ayah);
        return File.Exists(path) && new FileInfo(path).Length > 0;
    }

    /// <summary>ينزّل قائمة آيات (سورة, آية) لقارئ، متجاهلاً المخزّن مسبقاً.</summary>
    public static async Task DownloadAsync(
        IReadOnlyList<(int Surah, int Ayah)> refs, string folder,
        IProgress<(int Done, int Total)> progress, CancellationToken ct)
    {
        for (var i = 0; i < refs.Count; i++)
        {
            ct.ThrowIfCancellationRequested();
            var (s, a) = refs[i];
            if (!IsCached(folder, s, a))
            {
                var bytes = await Http.GetByteArrayAsync(UrlFor(folder, s, a), ct);
                await File.WriteAllBytesAsync(FileFor(folder, s, a), bytes, ct);
            }
            if ((i & 7) == 0 || i == refs.Count - 1)
                progress.Report((i + 1, refs.Count));
        }
    }
}
