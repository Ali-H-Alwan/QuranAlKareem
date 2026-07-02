/// قرّاء «السورة الكاملة» — من قاعدة MP3Quran.net (ملف mp3 لكل سورة).
/// الروابط مُتحقَّق منها من API الرسمي (200 OK).
class SurahReciter {
  final String name;
  final String server;
  final int surahTotal; // بعض المصاحف غير مكتملة

  const SurahReciter(this.name, this.server, {this.surahTotal = 114});

  String urlFor(int surah) =>
      '$server${surah.toString().padLeft(3, '0')}.mp3';

  /// معرّف مجلد التخزين المحلي.
  String get cacheFolder => server
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

  static const List<SurahReciter> all = [
    SurahReciter('هيثم الجدعاني',
        'https://server16.mp3quran.net/hitham/Rewayat-Hafs-A-n-Assem/',
        surahTotal: 101),
    SurahReciter('رعد محمد الكردي', 'https://server6.mp3quran.net/kurdi/'),
    SurahReciter('مصطفى رعد العزاوي', 'https://server8.mp3quran.net/ra3ad/'),
    SurahReciter('بيشه وا قادر الكردي',
        'https://server16.mp3quran.net/peshawa/Rewayat-Hafs-A-n-Assem/'),
  ];

  static SurahReciter byName(String? name) =>
      all.firstWhere((r) => r.name == name, orElse: () => all.first);
}
