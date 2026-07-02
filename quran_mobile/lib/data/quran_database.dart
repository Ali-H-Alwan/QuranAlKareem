import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// يفتح قاعدة القرآن: تُنسخ من الأصول (assets) عند أول تشغيل ثم تُفتح للقراءة.
/// القاعدة مبنية مسبقاً بكامل الفهرسة (نفس quran.db في نسخة سطح المكتب).
class QuranDatabase {
  static Database? _db;

  static Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'quran.db');

    if (!File(path).existsSync()) {
      final bytes = await rootBundle.load('assets/db/quran.db');
      await File(path).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    _db = await openDatabase(path, readOnly: true);
    return _db!;
  }
}
