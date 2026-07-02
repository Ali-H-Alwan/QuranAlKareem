# -*- coding: utf-8 -*-
"""
مولّد توقيتات الآيات داخل ملف سورة كاملة (MP3Quran) بالمحاذاة الصوتية.

الطريقة: Whisper يفرّغ الصوت مع توقيت كل كلمة ← نطبّع الكلمات بنفس قواعد
تطبيع التطبيق ← نحاذيها مع نص الآيات من quran.db ← نستخرج بداية/نهاية
كل آية. الناتج: JSON توقيتات (للتمييز في وضع السورة) و/أو ملفات mp3
لكل آية بهيكلية everyayah (لوضع آية-آية).

الاستخدام:
  python split_ayahs.py --db <quran.db> --url <رابط mp3 السورة> --surah 1 --out out/kurdi [--cut]
"""
import argparse
import difflib
import json
import os
import sqlite3
import subprocess
import sys
import unicodedata
import urllib.request

# ── تطبيع عربي مطابق لـ ArabicText.Normalize في التطبيق ──
_MAP = {"آ": "ا", "أ": "ا", "إ": "ا", "ٱ": "ا", "ٲ": "ا", "ٳ": "ا",
        "ى": "ي", "ئ": "ي", "ؤ": "و", "ة": "ه"}

def normalize(text: str) -> str:
    out = []
    for ch in text:
        cat = unicodedata.category(ch)
        if cat in ("Mn", "Cf"):
            continue
        if ch in ("ـ", "ء"):
            continue
        out.append(_MAP.get(ch, ch))
    return "".join(out).strip()


def load_ayah_words(db_path: str, surah: int):
    """كلمات كل آية (مطبّعة) + بسملة اختيارية تُنسب للآية 1."""
    con = sqlite3.connect(db_path)
    rows = con.execute(
        "SELECT NumberInSurah, Text FROM Ayahs WHERE SurahNumber=? ORDER BY NumberInSurah",
        (surah,)).fetchall()
    con.close()
    expected = []  # (ayah_number, word_norm)
    if surah not in (1, 9):  # بسملة الافتتاح ليست آية — تُلحق ببداية الآية 1
        for w in "بسم الله الرحمن الرحيم".split():
            expected.append((1, normalize(w)))
    for num, text in rows:
        for w in text.split():
            n = normalize(w)
            if n:
                expected.append((num, n))
    return expected, len(rows)


def transcribe(audio_path: str, model_size: str):
    from faster_whisper import WhisperModel
    print(f">> تحميل نموذج Whisper ({model_size})…", flush=True)
    model = WhisperModel(model_size, device="cpu", compute_type="int8")
    print(">> التفريغ الصوتي…", flush=True)
    segments, info = model.transcribe(
        audio_path, language="ar", word_timestamps=True, beam_size=5)
    words = []  # (norm, start, end)
    for seg in segments:
        for w in seg.words or []:
            n = normalize(w.word)
            if n:
                words.append((n, w.start, w.end))
    return words, info.duration


def align(expected, words):
    """محاذاة كلمات النص مع كلمات التفريغ ← زمن بداية/نهاية كل آية."""
    e_tokens = [w for _, w in expected]
    t_tokens = [w for w, _, _ in words]
    sm = difflib.SequenceMatcher(None, e_tokens, t_tokens, autojunk=False)

    e2t = {}
    for block in sm.get_matching_blocks():
        for k in range(block.size):
            e2t[block.a + k] = block.b + k
    match_ratio = len(e2t) / max(1, len(e_tokens))

    spans = {}  # ayah -> [t_first, t_last]
    for ei, (ayah, _) in enumerate(expected):
        ti = e2t.get(ei)
        if ti is None:
            continue
        s = spans.setdefault(ayah, [ti, ti])
        s[0] = min(s[0], ti)
        s[1] = max(s[1], ti)
    return spans, match_ratio


def build_timings(spans, words, ayah_count, duration):
    """حدود نظيفة: منتصف السكتة بين آخر كلمة آية وأول كلمة التالية."""
    starts, ends = {}, {}
    for ayah, (ti0, ti1) in spans.items():
        starts[ayah] = words[ti0][1]
        ends[ayah] = words[ti1][2]

    timings = []
    prev_end = 0.0
    for a in range(1, ayah_count + 1):
        st = starts.get(a)
        en = ends.get(a)
        if st is None or en is None:  # آية بلا تطابق — تُقدّر لاحقاً من الجارتين
            timings.append([a, None, None])
            continue
        timings.append([a, st, en])

    # حدود متلاصقة: بداية الآية = منتصف السكتة قبلها
    result = []
    for i, (a, st, en) in enumerate(timings):
        if st is None:
            continue
        if not result:
            begin = 0.0
        else:
            begin = (result[-1][2] + st) / 2
            result[-1] = (result[-1][0], result[-1][1], begin)
        result.append((a, begin, en))
    if result:
        result[-1] = (result[-1][0], result[-1][1], duration)
    return result


def cut_files(audio_path, timings, surah, out_dir):
    import imageio_ffmpeg
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(out_dir, exist_ok=True)
    for ayah, st, en in timings:
        name = f"{surah:03d}{ayah:03d}.mp3"
        subprocess.run(
            [ffmpeg, "-y", "-loglevel", "error", "-i", audio_path,
             "-ss", f"{st:.3f}", "-to", f"{en:.3f}",
             "-c:a", "libmp3lame", "-q:a", "4", os.path.join(out_dir, name)],
            check=True)
    print(f">> قُصَّت {len(timings)} آية إلى {out_dir}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--url", required=True, help="رابط mp3 السورة أو مسار محلي")
    ap.add_argument("--surah", type=int, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--model", default="small")
    ap.add_argument("--cut", action="store_true", help="قصّ ملفات آيات أيضاً")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    audio = args.url
    if audio.startswith("http"):
        audio = os.path.join(args.out, f"surah_{args.surah:03d}.mp3")
        if not os.path.exists(audio):
            print(">> تنزيل ملف السورة…", flush=True)
            urllib.request.urlretrieve(args.url, audio)

    expected, ayah_count = load_ayah_words(args.db, args.surah)
    words, duration = transcribe(audio, args.model)
    spans, ratio = align(expected, words)
    timings = build_timings(spans, words, ayah_count, duration)

    print(f">> تطابق الكلمات: {ratio:.0%} | آيات موقّتة: {len(timings)}/{ayah_count} | المدة: {duration:.1f}ث")
    for a, st, en in timings:
        print(f"   الآية {a:>3}: {st:7.2f} ← {en:7.2f}  ({en-st:.1f}ث)")

    out_json = os.path.join(args.out, f"timings_{args.surah:03d}.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump({"surah": args.surah, "duration": duration,
                   "match_ratio": round(ratio, 3),
                   "ayahs": [{"ayah": a, "start": round(s, 3), "end": round(e, 3)}
                              for a, s, e in timings]}, f, ensure_ascii=False, indent=1)
    print(f">> التوقيتات: {out_json}")

    if args.cut:
        cut_files(audio, timings, args.surah, args.out)


if __name__ == "__main__":
    main()
