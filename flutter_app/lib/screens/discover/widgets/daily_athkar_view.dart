import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../presentation/widgets/unified_badge.dart';
import 'athkar_data_constants.dart';

/// Interactive Daily Athkar View with countdown counters and category resets.
class DailyAthkarView extends StatefulWidget {
  final bool isDark;

  const DailyAthkarView({super.key, required this.isDark});

  @override
  State<DailyAthkarView> createState() => _DailyAthkarViewState();
}

class _DailyAthkarViewState extends State<DailyAthkarView> {
  String _selectedAthkarCategory = 'morning';
  final Map<String, int> _athkarTaps = {};

  void _tapDhikr(String dhikrId, int targetCount) {
    final current = _athkarTaps[dhikrId] ?? 0;
    if (current < targetCount) {
      HapticFeedback.lightImpact();
      setState(() => _athkarTaps[dhikrId] = current + 1);
    }
  }

  void _resetDhikr(String dhikrId) => setState(() => _athkarTaps[dhikrId] = 0);
  void _resetAllCategory() => setState(() => _athkarTaps.clear());

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAthkarChip('أذكار الصباح ☀️', 'morning'),
              const SizedBox(width: 8),
              _buildAthkarChip('أذكار المساء 🌙', 'evening'),
              const SizedBox(width: 8),
              _buildAthkarChip('أدعية بعد الصلاة 🕌', 'prayer'),
              const SizedBox(width: 8),
              _buildAthkarChip('أذكار النوم 🛏️', 'sleep'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text('اضغط على بطاقة الذكر للعد التنازلي التفاعلي', style: AppTypography.verveSubtitle(context)),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('تصفير العدادات', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.terracottaPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _resetAllCategory,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAthkarList(_selectedAthkarCategory, isDark),
      ],
    );
  }

  Widget _buildAthkarChip(String label, String key) {
    final isSelected = _selectedAthkarCategory == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: widget.isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      onSelected: (v) {
        if (v) setState(() => _selectedAthkarCategory = key);
      },
    );
  }

  Widget _buildAthkarList(String category, bool isDark) {
    final list = kAthkarDatabase[category] ?? [];
    final primary = Theme.of(context).primaryColor;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final item = list[idx];
        final id = '${category}_$idx';
        final countTarget = (item['count'] as num?)?.toInt() ?? 1;
        final currentTaps = _athkarTaps[id] ?? 0;
        final isCompleted = currentTaps >= countTarget;
        final fadl = (item['virtue'] ?? item['fadl'] ?? '') as String;
        final dhikrText = (item['text'] ?? '') as String;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _tapDhikr(id, countTarget),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? primary.withValues(alpha: 0.1) : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCompleted ? primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isCompleted ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (fadl.isNotEmpty)
                      Expanded(
                        child: Text(
                          fadl,
                          style: TextStyle(fontSize: 12, color: AppColors.goldDark, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const Spacer(),
                    Row(
                      children: [
                        UnifiedBadge(
                          label: '$currentTaps / $countTarget',
                          backgroundColor: isCompleted ? primary : (isDark ? Colors.white12 : Colors.black12),
                          textColor: isCompleted ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _resetDhikr(id),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  dhikrText,
                  style: GoogleFonts.amiri(
                    fontSize: 17.5,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
