import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import '../core/arabic_text.dart';
import 'models.dart';
import 'quran_database.dart';

/// مستودع بيانات القرآن — يطابق منطق SqliteQuranRepository في سطح المكتب.
class QuranRepository {
  Database? _db;
  List<Suggestion>? _dictWords;
  List<Suggestion>? _dictRoots;

  Future<Database> get _database async => _db ??= await QuranDatabase.open();

  static const int pageCount = 604;

  // ── السور ──
  Future<List<Surah>> surahs() async {
    final db = await _database;
    final rows = await db.query('Surahs', orderBy: 'Number');
    return rows.map(Surah.fromMap).toList();
  }

  // ── البحث النصّي (كلمة كاملة أو جزء من كلمة) ──
  /// wholeWord=true: مطابقة ضمن حدود المسافات (طه ⇐ طه فقط).
  /// wholeWord=false: احتواء (طه ⇐ طهورا وغيرها).
  Future<List<Ayah>> searchText(String query, {required bool wholeWord}) async {
    final norm = normalize(query);
    if (norm.isEmpty) return const [];
    final db = await _database;

    final pattern = wholeWord ? '% $norm %' : '%$norm%';
    String col(String c) => wholeWord ? "(' ' || a.$c || ' ')" : 'a.$c';

    final rows = await db.rawQuery('''
      SELECT a.SurahNumber, s.Name AS SurahName, a.NumberInSurah, a.Text, a.Page
      FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
      WHERE ${col('NormText')} LIKE ? OR ${col('NormUthmani')} LIKE ?
      ORDER BY a.SurahNumber, a.NumberInSurah
    ''', [pattern, pattern]);
    return rows.map(Ayah.fromMap).toList();
  }

  // ── بحث الجذر ──
  /// مطابقة تامّة فقط (جذر ثم شكل/ليمة) — بلا LIKE لتفادي الجذور الكاذبة
  /// (بخل← خلق، طه← بسط). نفس إصلاح سطح المكتب.
  Future<List<String>> findRoots(String word) async {
    final norm = normalize(word);
    if (norm.isEmpty) return const [];
    final db = await _database;

    Future<List<String>> q(String where) async {
      final rows = await db.rawQuery(
        "SELECT DISTINCT Root FROM Words WHERE Root <> '' AND ($where) ORDER BY Root",
        [norm, if (where.contains('OR')) norm],
      );
      return rows.map((r) => r['Root'] as String).toList();
    }

    var roots = await q('NormRoot = ?');
    if (roots.isEmpty) roots = await q('NormLemma = ? OR NormForm = ?');
    return roots;
  }

  Future<List<Ayah>> searchByRoot(String word) async {
    final roots = await findRoots(word);
    if (roots.isEmpty) return const [];
    final db = await _database;
    final marks = List.filled(roots.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT DISTINCT a.SurahNumber, s.Name AS SurahName, a.NumberInSurah, a.Text, a.Page
      FROM Ayahs a
      JOIN Surahs s ON s.Number = a.SurahNumber
      JOIN Words w ON w.SurahNumber = a.SurahNumber AND w.Ayah = a.NumberInSurah
      WHERE w.Root IN ($marks)
      ORDER BY a.SurahNumber, a.NumberInSurah
    ''', roots);
    return rows.map(Ayah.fromMap).toList();
  }

  /// الأشكال المطبّعة لكل كلمات الجذر — لتظليلها داخل نص الآية.
  Future<Set<String>> normFormsOfRoots(String word) async {
    final roots = await findRoots(word);
    if (roots.isEmpty) return const {};
    final db = await _database;
    final marks = List.filled(roots.length, '?').join(',');
    final rows = await db.rawQuery(
      "SELECT DISTINCT NormForm FROM Words WHERE NormForm <> '' AND Root IN ($marks)",
      roots,
    );
    return rows.map((r) => r['NormForm'] as String).toSet();
  }

  // ── المصحف ──
  Future<List<Ayah>> ayahsByPage(int page) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT a.SurahNumber, s.Name AS SurahName, a.NumberInSurah, a.Text, a.Page
      FROM Ayahs a JOIN Surahs s ON s.Number = a.SurahNumber
      WHERE a.Page = ?
      ORDER BY a.SurahNumber, a.NumberInSurah
    ''', [page]);
    return rows.map(Ayah.fromMap).toList();
  }

  Future<List<QuranWord>> wordsOf(int surah, int ayah) async {
    final db = await _database;
    final rows = await db.query('Words',
        where: 'SurahNumber = ? AND Ayah = ?',
        whereArgs: [surah, ayah],
        orderBy: 'WordIndex');
    return rows.map(QuranWord.fromMap).toList();
  }

  Future<String?> tafsir(int surah, int ayah) async {
    final db = await _database;
    final rows = await db.query('Tafsir',
        where: 'SurahNumber = ? AND NumberInSurah = ?', whereArgs: [surah, ayah]);
    return rows.isEmpty ? null : rows.first['Text'] as String;
  }

  // ── الإعراب (مقاطع الكلمة مترجمة للعربية) ──
  Future<List<SegmentInfo>> analysisOf(int surah, int ayah, int wordIndex) async {
    final db = await _database;
    final rows = await db.query('Segments',
        where: 'SurahNumber = ? AND Ayah = ? AND WordIndex = ?',
        whereArgs: [surah, ayah, wordIndex],
        orderBy: 'SegIndex');
    return rows
        .map((r) => SegmentInfo(
              form: r['Form'] as String,
              description: _describe(r['Tag'] as String, r['Features'] as String),
            ))
        .toList();
  }

  static const _tags = {
    'N': 'اسم', 'PN': 'اسم علم', 'ADJ': 'صفة', 'V': 'فعل',
    'P': 'حرف جر', 'PRON': 'ضمير', 'DET': 'أداة تعريف (ال)',
    'REL': 'اسم موصول', 'DEM': 'اسم إشارة', 'CONJ': 'حرف عطف',
    'SUB': 'حرف مصدري', 'NEG': 'حرف نفي', 'INTG': 'حرف استفهام',
    'VOC': 'حرف نداء', 'EMPH': 'لام التوكيد', 'PRP': 'لام التعليل',
    'ACC': 'حرف نصب', 'AMD': 'حرف استدراك', 'ANS': 'حرف جواب',
    'AVR': 'حرف ردع', 'CAUS': 'حرف سببية', 'CERT': 'حرف تحقيق',
    'COND': 'اسم شرط', 'EQ': 'حرف تسوية', 'EXH': 'حرف تحضيض',
    'EXL': 'حرف تفصيل', 'EXP': 'استثناء', 'FUT': 'حرف استقبال',
    'IMPN': 'اسم فعل أمر', 'INC': 'حرف ابتداء', 'INT': 'حرف تفسير',
    'INL': 'حروف مقطّعة', 'LOC': 'ظرف مكان', 'T': 'ظرف زمان',
    'PREV': 'كافّة ومكفوفة', 'PRO': 'حرف نهي', 'REM': 'حرف استئناف',
    'RES': 'حرف حصر', 'RET': 'حرف اضراب', 'RSLT': 'حرف واقع في جواب الشرط',
    'SUP': 'حرف زائد', 'SUR': 'حرف فجاءة', 'INImperative': 'أمر',
  };

  static String _describe(String tag, String features) {
    final parts = <String>[_tags[tag] ?? tag];
    for (final f in features.split('|')) {
      switch (f) {
        case 'PERF': parts.add('ماضٍ');
        case 'IMPF': parts.add('مضارع');
        case 'IMPV': parts.add('أمر');
        case 'NOM': parts.add('مرفوع');
        case 'GEN': parts.add('مجرور');
        // ACC كسِمة إعرابية (وليست وسم حرف نصب)
        case 'ACC': parts.add('منصوب');
        case 'M': parts.add('مذكّر');
        case 'F': parts.add('مؤنّث');
        case 'MS': parts.add('مفرد مذكّر');
        case 'FS': parts.add('مفرد مؤنّث');
        case 'MP': parts.add('جمع مذكّر');
        case 'FP': parts.add('جمع مؤنّث');
        case 'MD': parts.add('مثنى مذكّر');
        case 'FD': parts.add('مثنى مؤنّث');
        case 'PASS': parts.add('مبني للمجهول');
        default:
          if (f.startsWith('ROOT:')) parts.add('الجذر: ${f.substring(5)}');
          if (f.startsWith('LEM:')) parts.add('الأصل: ${f.substring(4)}');
      }
    }
    return parts.join('، ');
  }

  // ── الاقتراحات (dictionary.json) ──
  Future<void> _loadDictionary() async {
    if (_dictWords != null) return;
    final raw = await rootBundle.loadString('assets/data/dictionary.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    List<Suggestion> parse(List list) => [
          for (final e in list)
            Suggestion(
              text: e['t'] as String,
              count: e['c'] as int,
              root: e['r'] as String?,
              norm: normalize(e['t'] as String),
            )
        ];
    _dictWords = parse(data['words'] as List);
    _dictRoots = parse(data['roots'] as List);
  }

  /// اقتراحات بحث: بادئة أولاً ثم احتواء، مرتّبة بالتكرار (نفس سطح المكتب).
  Future<List<Suggestion>> suggest(String query, {required bool byRoot, int limit = 10}) async {
    await _loadDictionary();
    final source = byRoot ? _dictRoots! : _dictWords!;
    final norm = normalize(query);
    if (norm.isEmpty) return const [];

    final prefix = <Suggestion>[];
    final contains = <Suggestion>[];
    for (final s in source) {
      if (s.norm.startsWith(norm)) {
        prefix.add(s);
      } else if (s.norm.contains(norm)) {
        contains.add(s);
      }
      if (prefix.length >= limit) break;
    }
    if (prefix.length >= limit) return prefix;
    return [...prefix, ...contains.take(limit - prefix.length)];
  }
}
