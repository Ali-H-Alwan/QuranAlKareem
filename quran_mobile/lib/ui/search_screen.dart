import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/prefs.dart';
import '../app/providers.dart';
import '../core/arabic_text.dart';
import '../data/models.dart';
import 'app_colors.dart';
import 'ayah_sheet.dart';

// ألوان العلامة الثابتة (ترويسة البحث الخضراء بنصوص بيضاء/ذهبية في الوضعين).
const kGreen = AppColors.brandGreen;
const kGold = AppColors.gold;

/// شاشة البحث: ثلاثة أوضاع + اقتراحات + نتائج مع تظليل المطابق.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.onOpenPage});

  /// يفتح صفحة المصحف عند آية محدّدة.
  final void Function(int page, int surah, int ayah) onOpenPage;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<Suggestion> _suggestions = const [];
  bool _applying = false;

  Future<void> _onChanged(String text) async {
    if (_applying) return;
    final byRoot = ref.read(searchProvider).mode == SearchMode.root;
    final items = await ref.read(repositoryProvider).suggest(text, byRoot: byRoot);
    if (mounted) setState(() => _suggestions = items);
  }

  void _applySuggestion(Suggestion s) {
    _applying = true;
    _controller.text = s.text;
    _applying = false;
    setState(() => _suggestions = const []);
    _search();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = const []);
    ref.read(searchProvider.notifier).search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Column(
      children: [
        // ── شريط البحث ──
        Container(
          color: kGreen,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      // الحقل أبيض دائماً — لذا نصّه داكن حتى في الوضع الليلي.
                      style: TextStyle(
                          fontSize: 16,
                          color: AppColors.isDark(context) ? Colors.black87 : null),
                      decoration: InputDecoration(
                        hintText: 'اكتب كلمة البحث…',
                        hintStyle: AppColors.isDark(context)
                            ? const TextStyle(color: Colors.black45)
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _search,
                    style: FilledButton.styleFrom(backgroundColor: kGold),
                    child: const Text('بحث'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (m, label) in [
                    (SearchMode.word, 'كلمة'),
                    (SearchMode.part, 'جزء من كلمة'),
                    (SearchMode.root, 'جذر'),
                  ])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: state.mode == m,
                        selectedColor: kGold,
                        labelStyle: TextStyle(
                          color: state.mode == m
                              ? Colors.white
                              : AppColors.green(context),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => ref.read(searchProvider.notifier).setMode(m),
                      ),
                    ),
                  const Spacer(),
                  const Text('تظليل', style: TextStyle(color: Colors.white, fontSize: 12)),
                  Switch(
                    value: state.highlight,
                    activeThumbColor: kGold,
                    onChanged: (v) => ref.read(searchProvider.notifier).setHighlight(v),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── الاقتراحات ──
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            color: AppColors.surface(context),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(s.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: s.root == null
                      ? null
                      : Text('الجذر: ${s.root}',
                          style: TextStyle(color: AppColors.green(context))),
                  trailing: Text('${s.count}', style: const TextStyle(color: Colors.grey)),
                  onTap: () => _applySuggestion(s),
                );
              },
            ),
          ),

        // ── الحالة + نسخ كل النتائج ──
        if (state.status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(state.status,
                      style: TextStyle(
                          color: AppColors.green(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                if (state.results.isNotEmpty)
                  TextButton.icon(
                    icon: Icon(Icons.copy_all,
                        size: 18, color: AppColors.green(context)),
                    label: Text('نسخ الكل',
                        style: TextStyle(
                            color: AppColors.green(context),
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final buf = StringBuffer();
                      for (final a in state.results) {
                        buf.writeln(
                            '﴿${forReading(a.text)}﴾ [${a.surahName}: ${a.numberInSurah}]');
                      }
                      Clipboard.setData(
                          ClipboardData(text: buf.toString().trim()));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('تم نسخ ${state.results.length} آية')));
                    },
                  ),
              ],
            ),
          ),

        // ── النتائج ──
        Expanded(
          child: state.searching
              ? Center(
                  child:
                      CircularProgressIndicator(color: AppColors.green(context)))
              : state.results.isEmpty
                  ? const Center(
                      child: Text('✦ اكتب كلمة ثم اضغط بحث',
                          style: TextStyle(color: Colors.grey, fontSize: 15)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: state.results.length,
                      itemBuilder: (_, i) => _ResultCard(
                        ayah: state.results[i],
                        index: i + 1,
                        state: state,
                        onOpenPage: widget.onOpenPage,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.ayah,
    required this.index,
    required this.state,
    required this.onOpenPage,
  });

  final Ayah ayah;
  final int index;
  final SearchState state;
  final void Function(int page, int surah, int ayah) onOpenPage;

  bool _isHit(String word) {
    if (!state.highlight) return false;
    final n = normalize(word);
    if (state.highlightForms.isNotEmpty) return state.highlightForms.contains(n);
    if (state.highlightNorm.isEmpty) return false;
    // قد تكون عدّة كلمات بحث — تُظلَّل كلها.
    final terms = state.highlightNorm.split(' ').where((t) => t.isNotEmpty);
    return state.mode == SearchMode.part
        ? terms.any((q) => n.contains(q))
        : terms.contains(n);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = forReading(ayah.text); // إملاء واضح + حركات (إبراهيم)
    final spans = <TextSpan>[];
    for (final w in display.split(' ')) {
      if (w.isEmpty) continue;
      spans.add(TextSpan(
        text: '$w ',
        style: _isHit(w)
            ? TextStyle(
                backgroundColor: AppColors.highlight(context),
                color: AppColors.green(context),
                fontWeight: FontWeight.bold)
            : null,
      ));
    }
    spans.add(TextSpan(
      text: ' ﴿${toArabicDigits(ayah.numberInSurah)}﴾',
      style: TextStyle(
          color: AppColors.green(context), fontWeight: FontWeight.bold),
    ));

    return Card(
      color: AppColors.card(context),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 11,
                    backgroundColor: kGreen,
                    child: Text('$index',
                        style: const TextStyle(color: Colors.white, fontSize: 10))),
                const SizedBox(width: 8),
                Text('${ayah.surahName} • الآية ${ayah.numberInSurah} • ص${ayah.page}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                TextButton(
                  onPressed: () => onOpenPage(ayah.page, ayah.surahNumber, ayah.numberInSurah),
                  child: const Text('فتح الصفحة',
                      style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => showAyahSheet(context, ref, ayah),
              child: Text.rich(
                TextSpan(children: spans),
                textAlign: TextAlign.justify,
                style: TextStyle(
                    fontFamily: ref.watch(prefsProvider).fontFamily,
                    fontSize: 20,
                    height: 1.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
