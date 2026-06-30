using System.Threading;
using System.Threading.Tasks;
using System.Windows.Media;
using QuranAlKareem.Core.Models;

namespace QuranAlKareem.App.Audio;

/// <summary>
/// تلاوة الآيات: ينزّل ملفات الصوت أولاً إلى ذاكرة مؤقتة محلية ثم يشغّلها
/// بالتسلسل. بعد التنزيل تعمل التلاوة دون إنترنت (مخزّنة).
/// </summary>
public sealed class AudioService
{
    private readonly MediaPlayer _player = new();
    private List<Ayah> _queue = new();
    private int _index = -1;
    private string _folder = "Husary_128kbps";
    private CancellationTokenSource? _cts;

    /// <summary>الآية الجاري تلاوتها (أو null عند التوقّف) — للتمييز (الهايلايت).</summary>
    public event Action<Ayah?>? CurrentAyahChanged;

    /// <summary>تقدّم التنزيل (المنجز, الإجمالي).</summary>
    public event Action<int, int>? DownloadProgress;

    public bool IsPlaying { get; private set; }

    public AudioService()
    {
        _player.MediaEnded += (_, _) => PlayNext();
    }

    /// <summary>ينزّل ملفات الصفحة (إن لم تكن مخزّنة) ثم يبدأ التلاوة.</summary>
    public async Task PrepareAndPlayAsync(IReadOnlyList<Ayah> ayahs, string folder)
    {
        Stop();
        _folder = folder;
        _queue = ayahs.ToList();
        if (_queue.Count == 0) return;

        _cts = new CancellationTokenSource();
        var ct = _cts.Token;

        var refs = _queue.Select(a => (a.SurahNumber, a.NumberInSurah)).ToList();
        await AudioLibrary.DownloadAsync(refs, folder,
            new Progress<(int, int)>(p => DownloadProgress?.Invoke(p.Item1, p.Item2)), ct);

        _index = -1;
        IsPlaying = true;
        PlayNext();
    }

    /// <summary>أثناء التلاوة: ينتقل إلى آية ضمن نفس الصفحة فيتلوها.</summary>
    public void JumpTo(int surah, int ayah)
    {
        if (!IsPlaying) return;
        var idx = _queue.FindIndex(a => a.SurahNumber == surah && a.NumberInSurah == ayah);
        if (idx < 0) return;
        _index = idx - 1;
        PlayNext();
    }

    public void Stop()
    {
        _cts?.Cancel();
        IsPlaying = false;
        _player.Stop();
        _player.Close();
        CurrentAyahChanged?.Invoke(null);
    }

    private void PlayNext()
    {
        _index++;
        if (!IsPlaying || _index >= _queue.Count)
        {
            Stop();
            return;
        }
        var ayah = _queue[_index];
        _player.Open(new Uri(AudioLibrary.FileFor(_folder, ayah.SurahNumber, ayah.NumberInSurah)));
        _player.Play();
        CurrentAyahChanged?.Invoke(ayah);
    }
}
