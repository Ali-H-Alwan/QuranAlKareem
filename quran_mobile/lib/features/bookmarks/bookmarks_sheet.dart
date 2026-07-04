import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../ui/app_colors.dart';
import 'bookmarks.dart';

const _gold = AppColors.gold; // ذهبي العلامة — ثابت في الوضعين.

/// ورقة المفضّلة: قائمة العلامات المحفوظة، النقر يفتح صفحتها ويظلّل الآية.
void showBookmarksSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card(context),
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
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.bookmarks, color: _gold),
                    const SizedBox(width: 8),
                    Text('المفضّلة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.green(context))),
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
                          color: AppColors.surface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppColors.border(context)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                                // دائرة خضراء غامقة بنص أبيض — مقروءة في الوضعين.
                                backgroundColor: AppColors.brandGreen,
                                child: Text('${b.ayah}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12))),
                            title: Text(b.surahName,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.green(context))),
                            subtitle: Text(b.snippet,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: AppColors.danger(context)),
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
