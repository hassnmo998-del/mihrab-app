import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Unhurried Editorial List Row Component.
///
/// Implements the editorial design system from C:\UI UX\4:
/// - Flat, unhurried open layout (no boxed container/card)
/// - Prominent Amiri typography for titles and numbering ("01", "02", ...)
/// - Generous vertical breathing room
/// - Subtle hairline bottom divider
class EditorialListItem extends StatelessWidget {
  /// Optional sequence index (e.g., 0 renders "01", 1 renders "02")
  final int? index;

  /// Custom leading widget if index numbering is not used
  final Widget? leading;

  /// Main title text
  final String title;

  /// Optional subtitle or metadata string
  final String? subtitle;

  /// Optional custom subtitle widget for multi-line or rich formatting
  final Widget? subtitleWidget;

  /// Trailing widget (action buttons, badges, menu)
  final Widget? trailing;

  /// Optional metadata tags/chips displayed below the subtitle
  final List<Widget>? tags;

  /// Tap callback
  final VoidCallback? onTap;

  /// Whether to display the bottom hairline divider. Defaults to true.
  final bool showDivider;

  /// Custom padding
  final EdgeInsetsGeometry? padding;

  const EditorialListItem({
    super.key,
    this.index,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.tags,
    this.onTap,
    this.showDivider = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accentColor = theme.colorScheme.primary;

    Widget? leadingContent = leading;
    if (leadingContent == null && index != null) {
      final formattedIndex = (index! + 1).toString().padLeft(2, '0');
      leadingContent = Container(
        width: 36,
        alignment: Alignment.center,
        child: Text(
          formattedIndex,
          style: GoogleFonts.amiri(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: accentColor,
            height: 1.0,
          ),
        ),
      );
    }

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leadingContent != null) ...[
            leadingContent,
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    height: 1.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: GoogleFonts.amiri(
                      fontSize: 13.5,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 3),
                  subtitleWidget!,
                ],
                if (tags != null && tags!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      );
    }

    if (showDivider) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          Divider(
            height: 1,
            thickness: 0.8,
            color: dividerColor,
          ),
        ],
      );
    }

    return content;
  }
}
