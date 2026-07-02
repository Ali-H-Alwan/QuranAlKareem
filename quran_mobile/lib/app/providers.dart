import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/arabic_text.dart';
import '../data/models.dart';
import '../data/quran_repository.dart';

/// المستودع المشترك.
final repositoryProvider = Provider<QuranRepository>((ref) => QuranRepository());

/// حالة البحث.
class SearchState {
  final SearchMode mode;
  final String query;
  final List<Ayah> results;
  final bool highlight;
  final bool searching;
  final String status;

  /// معطيات التظليل: نص مطبّع (كلمة/جزء) أو مجموعة أشكال (جذر).
  final String highlightNorm;
  final Set<String> highlightForms;

  const SearchState({
    this.mode = SearchMode.word,
    this.query = '',
    this.results = const [],
    this.highlight = true,
    this.searching = false,
    this.status = '',
    this.highlightNorm = '',
    this.highlightForms = const {},
  });

  SearchState copyWith({
    SearchMode? mode,
    String? query,
    List<Ayah>? results,
    bool? highlight,
    bool? searching,
    String? status,
    String? highlightNorm,
    Set<String>? highlightForms,
  }) =>
      SearchState(
        mode: mode ?? this.mode,
        query: query ?? this.query,
        results: results ?? this.results,
        highlight: highlight ?? this.highlight,
        searching: searching ?? this.searching,
        status: status ?? this.status,
        highlightNorm: highlightNorm ?? this.highlightNorm,
        highlightForms: highlightForms ?? this.highlightForms,
      );
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  void setMode(SearchMode m) => state = state.copyWith(mode: m);
  void setHighlight(bool v) => state = state.copyWith(highlight: v);

  Future<void> search(String query) async {
    final repo = ref.read(repositoryProvider);
    final term = query.trim();
    if (term.isEmpty) return;
    state = state.copyWith(searching: true, query: term);

    List<Ayah> results;
    var norm = '';
    var forms = const <String>{};
    String status;

    switch (state.mode) {
      case SearchMode.root:
        final roots = await repo.findRoots(term);
        results = await repo.searchByRoot(term);
        forms = await repo.normFormsOfRoots(term);
        status = roots.isEmpty
            ? 'لا جذر مطابقاً لـ«$term»'
            : 'الجذر: ${roots.join('، ')} — ${results.length} آية';
      case SearchMode.part:
        results = await repo.searchText(term, wholeWord: false);
        norm = _normOf(term);
        status = 'جزء «$term»: ${results.length} آية';
      case SearchMode.word:
        results = await repo.searchText(term, wholeWord: true);
        norm = _normOf(term);
        status = 'كلمة «$term»: ${results.length} آية';
    }

    state = state.copyWith(
      results: results,
      searching: false,
      status: status,
      highlightNorm: norm,
      highlightForms: forms,
    );
  }

  static String _normOf(String s) => normalize(s);
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

/// الصفحة الحالية بالمصحف (مشتركة بين البحث والمصحف).
final currentPageProvider = StateProvider<int>((ref) => 1);

/// الآية المستهدفة للتظليل عند الفتح من البحث.
final targetAyahProvider = StateProvider<(int surah, int ayah)?>((ref) => null);

/// آيات صفحة معيّنة.
final pageAyahsProvider = FutureProvider.family<List<Ayah>, int>((ref, page) async {
  return ref.read(repositoryProvider).ayahsByPage(page);
});
