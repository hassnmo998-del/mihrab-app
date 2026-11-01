import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/datasources/ministry_remote.dart';

/// ملخص المنصة للإشراف العام: أرقام يحسبها الخادم، وأكثر المدن مساجد (للتصفية بالنقر).
class MinistryOverviewCard extends StatelessWidget {
  final MinistryOverview overview;
  final String? selectedCity;
  final ValueChanged<String?> onCity;

  const MinistryOverviewCard({
    super.key,
    required this.overview,
    required this.selectedCity,
    required this.onCity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiles = <(IconData, String, int)>[
      (Icons.mosque_rounded, 'المساجد', overview.mosques),
      (Icons.people, 'الطلاب', overview.students),
      (Icons.person, 'المشايخ', overview.sheikhs),
      (Icons.menu_book, 'الحلقات', overview.halaqat),
      (Icons.how_to_reg_outlined, 'حضور اليوم', overview.attendanceToday),
      (Icons.bolt_outlined, 'نشطة هذا الأسبوع', overview.activeMosques7d),
      (Icons.add_business_outlined, 'جديدة خلال 30 يوماً', overview.newMosques30d),
      (Icons.female, 'أقسام نسائية', overview.mosquesWomen),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: AppColors.emeraldPrimary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('نظرة عامة على المنصة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 4 : 2;
            final w = (c.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tiles) SizedBox(width: w, child: _tile(t, isDark))],
            );
          }),
          if (overview.cities.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('المساجد حسب المدينة',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in overview.cities.take(12))
                  FilterChip(
                    label: Text('${c.city} (${c.mosques})', style: const TextStyle(fontSize: 11)),
                    selected: selectedCity == c.city,
                    visualDensity: VisualDensity.compact,
                    onSelected: (on) => onCity(on ? c.city : null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile((IconData, String, int) t, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(t.$1, size: 20, color: AppColors.emeraldPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('${t.$3}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ),
                Text(t.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
