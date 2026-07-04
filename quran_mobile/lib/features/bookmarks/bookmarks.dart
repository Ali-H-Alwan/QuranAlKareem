import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// علامة مرجعية على آية (تحفظ موقعها لسرعة الرجوع).
class Bookmark {
  final int surah;
  final int ayah;
  final int page;
  final String surahName;
  final String snippet; // مقتطف من نص الآية

  const Bookmark({
    required this.surah,
    required this.ayah,
    required this.page,
    required this.surahName,
    required this.snippet,
  });

  String get key => '$surah:$ayah';

  Map<String, dynamic> toJson() => {
        's': surah, 'a': ayah, 'p': page, 'n': surahName, 't': snippet,
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        surah: j['s'] as int,
        ayah: j['a'] as int,
        page: j['p'] as int,
        surahName: j['n'] as String,
        snippet: j['t'] as String,
      );
}

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  SharedPreferences? _sp;

  @override
  List<Bookmark> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    _sp = await SharedPreferences.getInstance();
    final raw = _sp!.getStringList('bookmarks') ?? const [];
    state = raw
        .map((s) => Bookmark.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  void _persist() =>
      _sp?.setStringList('bookmarks', state.map((b) => jsonEncode(b.toJson())).toList());

  bool contains(int surah, int ayah) =>
      state.any((b) => b.surah == surah && b.ayah == ayah);

  /// يضيف/يزيل العلامة ويرجع الحالة الجديدة (true = صارت محفوظة).
  bool toggle(Bookmark b) {
    if (contains(b.surah, b.ayah)) {
      state = state.where((x) => x.key != b.key).toList();
      _persist();
      return false;
    }
    state = [b, ...state];
    _persist();
    return true;
  }

  void remove(Bookmark b) {
    state = state.where((x) => x.key != b.key).toList();
    _persist();
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);
