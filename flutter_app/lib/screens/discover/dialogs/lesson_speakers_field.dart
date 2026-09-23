import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/app_user_avatar.dart';

/// "فردي / جماعي" picker for a public lesson.
///
/// Single mode shows [singleChild] (the existing one-lecturer inputs). Group mode lists
/// the mosque's sheikhs with checkboxes; [lockedSheikhId] (the announcing sheikh) stays
/// checked and can't be removed.
class LessonSpeakersField extends StatelessWidget {
  final bool isGroup;
  final ValueChanged<bool> onFormatChanged;
  final List<Sheikh> sheikhs;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final String? lockedSheikhId;
  final Widget? singleChild;

  const LessonSpeakersField({
    super.key,
    required this.isGroup,
    required this.onFormatChanged,
    required this.sheikhs,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.lockedSheikhId,
    this.singleChild,
  });

  /// A group lesson needs at least two sheikhs.
  static const int minGroupSize = 2;

  /// Display line for several lecturers, in the order given.
  static String joinNames(Iterable<String> names) =>
      names.map((n) => n.trim()).where((n) => n.isNotEmpty).join('، ');

  /// Selected ids that belong to [sheikhs], in list order (so the order is stable
  /// and a sheikh from a previously chosen mosque never leaks in).
  static List<String> orderedSelection(List<Sheikh> sheikhs, Set<String> selectedIds) =>
      [for (final s in sheikhs) if (selectedIds.contains(s.id)) s.id];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.person_outline, size: 18), label: Text('فردي')),
            ButtonSegment(value: true, icon: Icon(Icons.groups_outlined, size: 18), label: Text('جماعي')),
          ],
          selected: {isGroup},
          onSelectionChanged: (s) => onFormatChanged(s.first),
        ),
        const SizedBox(height: 12),
        if (!isGroup && singleChild != null) singleChild!,
        if (isGroup) _buildGroupList(isDark, primary),
      ],
    );
  }

  Widget _buildGroupList(bool isDark, Color primary) {
    final selectedCount = orderedSelection(sheikhs, selectedIds).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('الشيوخ المشاركون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Text(
                  '$selectedCount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedCount >= minGroupSize ? primary : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          if (sheikhs.length < minGroupSize)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text(
                'لا يوجد شيوخ آخرون معتمدون في هذا المسجد',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 6),
                children: [
                  for (final s in sheikhs)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: primary,
                      value: selectedIds.contains(s.id),
                      // The announcing sheikh is always part of their own lesson.
                      onChanged: s.id == lockedSheikhId
                          ? null
                          : (checked) {
                              final next = {...selectedIds};
                              checked == true ? next.add(s.id) : next.remove(s.id);
                              onSelectionChanged(next);
                            },
                      title: Text(s.fullName, style: const TextStyle(fontSize: 13.5)),
                      secondary: AppUserAvatar(
                        name: s.fullName,
                        imageUrl: s.profileImageUrl,
                        role: 'sheikh',
                        radius: 14,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "درس جماعي" badge for lesson cards.
class GroupLessonBadge extends StatelessWidget {
  const GroupLessonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded, size: 14, color: AppColors.goldDark),
          const SizedBox(width: 4),
          Text(
            'درس جماعي',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.goldDark),
          ),
        ],
      ),
    );
  }
}
