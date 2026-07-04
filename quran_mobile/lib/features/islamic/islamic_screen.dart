import 'package:flutter/material.dart';
import 'islamic_content.dart';

const _green = Color(0xFF0E5A3C);
const _gold = Color(0xFFC9A24B);
const _card = Color(0xFFFBF8F1);

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
          color: _card,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE6D9B8)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              leading: Text(s.icon, style: const TextStyle(fontSize: 24)),
              title: Text(s.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: _green)),
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
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8A6D1F))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEFE7D2)),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: _green)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.body,
              style: const TextStyle(fontSize: 13.5, height: 1.9, color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }
}
