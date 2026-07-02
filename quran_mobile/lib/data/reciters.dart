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
    Reciter('محمود خليل الحُصَري (مرتّل)', 'Husary_128kbps'),
    Reciter('محمود خليل الحُصَري (مجوّد)', 'Husary_128kbps_Mujawwad'),
    Reciter('محمود خليل الحُصَري (معلّم)', 'Husary_Muallim_128kbps'),
    Reciter('محمد صديق المِنشاوي (مرتّل)', 'Minshawy_Murattal_128kbps'),
    Reciter('محمد صديق المِنشاوي (مجوّد)', 'Minshawy_Mujawwad_192kbps'),
    Reciter('عبد الباسط عبد الصمد (مرتّل)', 'Abdul_Basit_Murattal_192kbps'),
    Reciter('عبد الباسط عبد الصمد (مجوّد)', 'Abdul_Basit_Mujawwad_128kbps'),
    Reciter('مصطفى إسماعيل', 'Mustafa_Ismail_48kbps'),
    Reciter('محمد الطبلاوي', 'Mohammad_al_Tablaway_128kbps'),
    Reciter('محمود علي البنّا', 'mahmoud_ali_al_banna_32kbps'),
  ];

  static Reciter byName(String? name) =>
      all.firstWhere((r) => r.name == name, orElse: () => all.first);
}
