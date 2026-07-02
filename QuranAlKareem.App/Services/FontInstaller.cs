using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using FontFamily = System.Windows.Media.FontFamily;

namespace QuranAlKareem.App.Services;

/// <summary>خطّ قرآني قابل للتنزيل والتثبيت.</summary>
public sealed record QuranFont(string Display, string Family, string FileName, string Url, string Description);

/// <summary>
/// تنزيل خطوط القرآن الحرّة ومعاينتها وتثبيتها على النظام (يتطلّب صلاحيات مدير).
/// المعاينة تعمل من الملف المنزَّل مباشرةً قبل التثبيت.
/// </summary>
public static class FontInstaller
{
    private const int WM_FONTCHANGE = 0x001D;

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    private static extern int AddFontResource(string path);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern int SendMessage(IntPtr hwnd, int msg, IntPtr w, IntPtr l);

    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(60) };

    /// <summary>
    /// خطوط المصحف المعتمدة — كلها مفحوصة فحصاً آلياً بتغطية كامل محارف
    /// نص المصحف (81 محرفاً: الحروف والتشكيل وعلامات الوقف وأقواس الآيات)،
    /// فلا تظهر مربعات. لا تُضِف خطاً هنا قبل فحص تغطيته.
    /// </summary>
    public static readonly IReadOnlyList<QuranFont> Catalog = new[]
    {
        new QuranFont("KFGQPC Uthmanic Script HAFS", "KFGQPC Uthmanic Script HAFS", "UthmanicHafs.otf",
            "https://github.com/nuqayah/qpc-fonts/raw/master/various/UthmanicHafs1%20Ver09.otf",
            "الخط الرسمي لمصحف المدينة النبوية (حفص) — مجمع الملك فهد."),
        new QuranFont("Amiri Quran", "Amiri Quran", "AmiriQuran-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/amiriquran/AmiriQuran-Regular.ttf",
            "خطّ نسخي مخصّص لرسم المصحف مع الضبط الكامل."),
        new QuranFont("Amiri", "Amiri", "Amiri-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Regular.ttf",
            "نسخ كلاسيكي أنيق للنصوص العربية والقرآنية."),
        new QuranFont("Scheherazade New", "Scheherazade New", "ScheherazadeNew-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/scheherazadenew/ScheherazadeNew-Regular.ttf",
            "خطّ نسخي واسع الانتشار لعرض القرآن (SIL)."),
        new QuranFont("Lateef", "Lateef", "Lateef-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/lateef/Lateef-Regular.ttf",
            "خطّ نسخي رفيع مريح للقراءة الطويلة."),
        new QuranFont("Noto Naskh Arabic", "Noto Naskh Arabic", "NotoNaskhArabic-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/notonaskharabic/NotoNaskhArabic%5Bwght%5D.ttf",
            "نسخ واضح من مجموعة Noto من Google."),
        new QuranFont("Harmattan", "Harmattan", "Harmattan-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/harmattan/Harmattan-Regular.ttf",
            "نسخ خفيف مريح (SIL)."),
        new QuranFont("Jomhuria", "Jomhuria", "Jomhuria-Regular.ttf",
            "https://github.com/google/fonts/raw/main/ofl/jomhuria/Jomhuria-Regular.ttf",
            "ثُلث عريض للعناوين — بتغطية قرآنية كاملة."),
    };

    /// <summary>
    /// عائلة خطّ صالحة للعرض في كل التطبيق: إن كان الخطّ مُنزَّلاً وغير مثبّت
    /// يُحمَّل من الملف مباشرةً (فيظهر بلا تثبيت على النظام)، وإلا يُطلب بالاسم.
    /// </summary>
    public static FontFamily Resolve(string family)
    {
        var f = Catalog.FirstOrDefault(c => c.Family == family);
        if (f is not null && !IsInstalled(f) && IsDownloaded(f))
            return new FontFamily(new Uri(CacheDir + Path.DirectorySeparatorChar), $"./{f.FileName}#{f.Family}");
        return new FontFamily(family);
    }

    /// <summary>أسماء الخطوط المعروضة في قوائم الاختيار (خطوط أساسية + الكتالوج).</summary>
    public static IReadOnlyList<string> DisplayNames { get; } =
        new[] { "Amiri Quran", "Traditional Arabic", "Arial" }
            .Concat(Catalog.Select(c => c.Family))
            .Distinct()
            .ToArray();

    public static string CacheDir
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "QuranAlKareem", "fonts");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    public static string CachePath(QuranFont f) => Path.Combine(CacheDir, f.FileName);

    public static bool IsDownloaded(QuranFont f)
    {
        var p = CachePath(f);
        return File.Exists(p) && new FileInfo(p).Length > 0;
    }

    public static bool IsInstalled(QuranFont f)
    {
        var winFonts = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Fonts", f.FileName);
        return File.Exists(winFonts);
    }

    /// <summary>ينزّل ملف الخطّ إلى ذاكرة التطبيق (للمعاينة والتثبيت).</summary>
    public static async Task DownloadAsync(QuranFont f, CancellationToken ct = default)
    {
        var bytes = await Http.GetByteArrayAsync(f.Url, ct);
        await File.WriteAllBytesAsync(CachePath(f), bytes, ct);
    }

    /// <summary>عائلة خطّ للمعاينة: من النظام إن كان مثبّتاً، أو من الملف المنزَّل، أو null.</summary>
    public static FontFamily? Preview(QuranFont f)
    {
        if (IsInstalled(f)) return new FontFamily(f.Family);
        if (IsDownloaded(f))
            return new FontFamily(new Uri(CacheDir + Path.DirectorySeparatorChar), $"./{f.FileName}#{f.Family}");
        return null;
    }

    /// <summary>يثبّت الخطّ لكل النظام (نسخ إلى مجلد الخطوط + تسجيل) عبر عملية مرفوعة الصلاحيات.</summary>
    public static async Task<bool> InstallAsync(QuranFont f)
    {
        if (!IsDownloaded(f)) await DownloadAsync(f);

        var src = CachePath(f);
        var windir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        var dst = Path.Combine(windir, "Fonts", f.FileName);

        var script = $"""
            $dst = Join-Path $env:WINDIR 'Fonts\{f.FileName}'
            Copy-Item -LiteralPath '{src}' -Destination $dst -Force
            New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name '{f.Display} (TrueType)' -Value '{f.FileName}' -PropertyType String -Force | Out-Null
            """;
        var scriptPath = Path.Combine(Path.GetTempPath(), $"qak_install_{f.FileName}.ps1");
        await File.WriteAllTextAsync(scriptPath, script);

        var psi = new ProcessStartInfo("powershell.exe",
            $"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{scriptPath}\"")
        {
            UseShellExecute = true,
            Verb = "runas", // يطلب صلاحيات المدير (UAC)
            WindowStyle = ProcessWindowStyle.Hidden,
        };

        try
        {
            var p = Process.Start(psi);
            if (p is null) return false;
            await p.WaitForExitAsync();
            if (p.ExitCode != 0) return false;
        }
        catch (System.ComponentModel.Win32Exception)
        {
            return false; // أُلغي طلب المدير
        }

        // اجعل الخطّ متاحاً في الجلسة الحالية دون إعادة تشغيل.
        try
        {
            AddFontResource(dst);
            SendMessage((IntPtr)0xffff, WM_FONTCHANGE, IntPtr.Zero, IntPtr.Zero);
        }
        catch { /* تجاهل: سيظهر بعد إعادة التشغيل */ }

        return File.Exists(dst);
    }
}
