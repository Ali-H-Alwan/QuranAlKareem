/// قرّاء التلاوة — نفس قائمة سطح المكتب (everyayah.com).
class Reciter {
  final String name;
  final String folder;
  const Reciter(this.name, this.folder);

  String urlFor(int surah, int ayah) {
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$a.mp3';
  }

  static const List<Reciter> all = [
    Reciter('محمود خليل الحُصَري', 'Husary_128kbps'),
    Reciter('محمد صديق المِنشاوي', 'Minshawy_Murattal_128kbps'),
    Reciter('عبد الباسط عبد الصمد', 'Abdul_Basit_Murattal_192kbps'),
  ];

  static Reciter byName(String? name) =>
      all.firstWhere((r) => r.name == name, orElse: () => all.first);
}
