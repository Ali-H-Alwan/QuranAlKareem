import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'bookmarks.dart';

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);

/// ورقة المفضّلة: قائمة العلامات المحفوظة، النقر يفتح صفحتها ويظلّل الآية.
void showBookmarksSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFBF8F1),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => Consumer(
          builder: (context, ref, _) {
            final items = ref.watch(bookmarksProvider);
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.bookmarks, color: _gold),
                    SizedBox(width: 8),
                    Text('المفضّلة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: _green)),
                  ]),
                ),
                if (items.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('لا توجد علامات محفوظة بعد.\nاحفظ آية من صفحتها.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final b = items[i];
                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE6D9B8)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                                backgroundColor: _green,
                                child: Text('${b.ayah}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12))),
                            title: Text(b.surahName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: _green)),
                            subtitle: Text(b.snippet,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF9A4A3A)),
                              onPressed: () => ref.read(bookmarksProvider.notifier).remove(b),
                            ),
                            onTap: () {
                              ref.read(targetAyahProvider.notifier).state = (b.surah, b.ayah);
                              ref.read(currentPageProvider.notifier).state = b.page;
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    ),
  );
}
