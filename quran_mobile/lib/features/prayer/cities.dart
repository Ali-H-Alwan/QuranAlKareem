/// مدن مواقيت الصلاة — عراقية أولاً ثم إقليمية، مع الإحداثيات وفرق التوقيت.
class City {
  final String name;
  final String country; // بالإنكليزية لطلبات Aladhan
  final double lat;
  final double lng;
  final int utcOffsetHours;
  const City(this.name, this.country, this.lat, this.lng, this.utcOffsetHours);

  static const List<City> all = [
    // ── العراق ──
    City('بغداد', 'Iraq', 33.3152, 44.3661, 3),
    City('البصرة', 'Iraq', 30.5085, 47.7804, 3),
    City('الموصل', 'Iraq', 36.3350, 43.1189, 3),
    City('أربيل', 'Iraq', 36.1911, 44.0092, 3),
    City('كربلاء', 'Iraq', 32.6160, 44.0249, 3),
    City('النجف', 'Iraq', 32.0000, 44.3300, 3),
    City('كركوك', 'Iraq', 35.4681, 44.3922, 3),
    City('السليمانية', 'Iraq', 35.5570, 45.4351, 3),
    City('دهوك', 'Iraq', 36.8672, 42.9503, 3),
    City('الرمادي', 'Iraq', 33.4258, 43.2992, 3),
    City('الحلة', 'Iraq', 32.4637, 44.4199, 3),
    City('الناصرية', 'Iraq', 31.0510, 46.2593, 3),
    City('العمارة', 'Iraq', 31.8356, 47.1447, 3),
    City('الديوانية', 'Iraq', 31.9929, 44.9247, 3),
    City('السماوة', 'Iraq', 31.3096, 45.2805, 3),
    City('الكوت', 'Iraq', 32.5128, 45.8182, 3),
    City('بعقوبة', 'Iraq', 33.7466, 44.6437, 3),
    City('تكريت', 'Iraq', 34.6070, 43.6786, 3),
    City('سامراء', 'Iraq', 34.1959, 43.8857, 3),
    City('الفلوجة', 'Iraq', 33.3538, 43.7797, 3),
    // ── المنطقة ──
    City('مكة المكرمة', 'Saudi Arabia', 21.4225, 39.8262, 3),
    City('المدينة المنورة', 'Saudi Arabia', 24.4672, 39.6111, 3),
    City('الرياض', 'Saudi Arabia', 24.7136, 46.6753, 3),
    City('الكويت', 'Kuwait', 29.3759, 47.9774, 3),
    City('دبي', 'UAE', 25.2048, 55.2708, 4),
    City('الدوحة', 'Qatar', 25.2854, 51.5310, 3),
    City('المنامة', 'Bahrain', 26.2285, 50.5860, 3),
    City('عمّان', 'Jordan', 31.9539, 35.9106, 3),
    City('دمشق', 'Syria', 33.5138, 36.2765, 3),
    City('بيروت', 'Lebanon', 33.8938, 35.5018, 3),
    City('القاهرة', 'Egypt', 30.0444, 31.2357, 3),
    City('اسطنبول', 'Turkey', 41.0082, 28.9784, 3),
    City('طهران', 'Iran', 35.6892, 51.3890, 3),
    City('مشهد', 'Iran', 36.2605, 59.6168, 3),
    City('قم', 'Iran', 34.6401, 50.8764, 3),
  ];

  static City byName(String? name) =>
      all.firstWhere((c) => c.name == name, orElse: () => all.first);
}
