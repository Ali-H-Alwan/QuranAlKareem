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
    Reciter('محمود خليل الحُصَري (مجوّد)', 'Husary_Mujawwad_128kbps'),
    Reciter('محمد صديق المِنشاوي (مرتّل)', 'Minshawy_Murattal_128kbps'),
    Reciter('محمد صديق المِنشاوي (مجوّد)', 'Minshawy_Mujawwad_192kbps'),
    Reciter('عبد الباسط عبد الصمد (مرتّل)', 'Abdul_Basit_Murattal_192kbps'),
    Reciter('عبد الباسط عبد الصمد (مجوّد)', 'Abdul_Basit_Mujawwad_128kbps'),
    Reciter('عبد الرحمن السُّدَيس', 'Abdurrahmaan_As-Sudais_192kbps'),
    Reciter('سعود الشُّرَيم', 'Saood_ash-Shuraym_128kbps'),
    Reciter('مشاري راشد العفاسي', 'Alafasy_128kbps'),
    Reciter('ماهر المُعَيْقلي', 'Maher_AlMuaiqly_64kbps'),
    Reciter('أبو بكر الشاطري', 'Abu_Bakr_Ash-Shaatree_128kbps'),
    Reciter('سعد الغامدي', 'Ghamadi_40kbps'),
    Reciter('علي الحُذَيْفي', 'Hudhaify_128kbps'),
    Reciter('هاني الرِّفاعي', 'Hani_Rifai_192kbps'),
    Reciter('محمد أيوب', 'Muhammad_Ayyoub_128kbps'),
    Reciter('محمد جبريل', 'Muhammad_Jibreel_128kbps'),
    Reciter('عبد الله بَصْفَر', 'Abdullah_Basfar_192kbps'),
    Reciter('ناصر القَطَامي', 'Nasser_Alqatami_128kbps'),
    Reciter('أحمد بن علي العجمي', 'ahmed_ibn_ali_al_ajamy_128kbps'),
    Reciter('ياسر الدوسري', 'Yasser_Ad-Dussary_128kbps'),
    Reciter('فارس عبّاد', 'Fares_Abbad_64kbps'),
    Reciter('محمود علي البنّا', 'mahmoud_ali_al_banna_32kbps'),
  ];

  static Reciter byName(String? name) =>
      all.firstWhere((r) => r.name == name, orElse: () => all.first);
}
