import 'package:flutter/material.dart';
import '../../ui/app_colors.dart';
import 'islamic_content.dart';

const _gold = AppColors.gold; // ذهبي العلامة — ثابت في الوضعين.

/// القسم الإسلامي: العقائد وفروع الدين والصلاة والطهارة (إمامي، فتوى السيستاني).
class IslamicScreen extends StatelessWidget {
  const IslamicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: islamicSections.length,
      itemBuilder: (_, i) {
        final s = islamicSections[i];
        return Card(
          color: AppColors.card(context),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border(context)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              leading: Text(s.icon, style: const TextStyle(fontSize: 24)),
              title: Text(s.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.green(context))),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              children: [
                if (s.note != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('ℹ ${s.note}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.noteText(context))),
                  ),
                for (final item in s.items) _InfoTile(item: item),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.item});
  final InfoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: _gold,
                  margin: const EdgeInsets.only(left: 8)),
              Expanded(
                child: Text(item.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.green(context))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.body,
              style: TextStyle(
                  fontSize: 13.5, height: 1.9, color: AppColors.text(context))),
        ],
      ),
    );
  }
}
