/// نماذج البيانات — تطابق أعمدة quran.db (نفس قاعدة نسخة سطح المكتب).
library;

class Surah {
  final int number;
  final String name;
  final int ayahCount;
  const Surah({required this.number, required this.name, required this.ayahCount});

  factory Surah.fromMap(Map<String, Object?> m) => Surah(
        number: m['Number'] as int,
        name: m['Name'] as String,
        ayahCount: m['AyahCount'] as int,
      );
}

class Ayah {
  final int surahNumber;
  final String surahName;
  final int numberInSurah;
  final String text;
  final int page;
  const Ayah({
    required this.surahNumber,
    required this.surahName,
    required this.numberInSurah,
    required this.text,
    required this.page,
  });

  factory Ayah.fromMap(Map<String, Object?> m) => Ayah(
        surahNumber: m['SurahNumber'] as int,
        surahName: (m['SurahName'] ?? m['Name'] ?? '') as String,
        numberInSurah: m['NumberInSurah'] as int,
        text: m['Text'] as String,
        page: m['Page'] as int,
      );
}

class QuranWord {
  final int surahNumber;
  final int ayah;
  final int wordIndex;
  final String form;
  final String root;
  final String lemma;
  const QuranWord({
    required this.surahNumber,
    required this.ayah,
    required this.wordIndex,
    required this.form,
    required this.root,
    required this.lemma,
  });

  factory QuranWord.fromMap(Map<String, Object?> m) => QuranWord(
        surahNumber: m['SurahNumber'] as int,
        ayah: m['Ayah'] as int,
        wordIndex: m['WordIndex'] as int,
        form: m['Form'] as String,
        root: (m['Root'] ?? '') as String,
        lemma: (m['Lemma'] ?? '') as String,
      );
}

/// مقطع صرفي لكلمة (من جدول Segments) مع وصفه العربي.
class SegmentInfo {
  final String form;
  final String description;
  const SegmentInfo({required this.form, required this.description});
}

/// اقتراح بحث (من dictionary.json).
class Suggestion {
  final String text;
  final int count;
  final String? root;
  final String norm;
  const Suggestion({required this.text, required this.count, this.root, required this.norm});
}

/// وضع البحث — يطابق SearchMode في سطح المكتب.
enum SearchMode { word, part, root }
