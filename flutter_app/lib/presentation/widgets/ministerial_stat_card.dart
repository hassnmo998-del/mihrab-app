import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Single item for the Ministerial Stat Row (C:\UI UX\4 Style).
class MinisterialStatItem {
  final String value;
  final String label;
  final String? subtitle;
  final Color? valueColor;

  const MinisterialStatItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.valueColor,
  });
}

/// Editorial 3-Column / 4-Column Stat Bar (C:\UI UX\4 Style).
/// Matches the "38% | 2× | 12k" design with large thin Amiri serif numbers,
/// muted labels, and subtle hairline vertical divider lines.
class MinisterialStatsRow extends StatelessWidget {
  final List<MinisterialStatItem> items;
  final EdgeInsetsGeometry padding;

  const MinisterialStatsRow({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final labelColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: AppRadius.card,
        border: Border.all(color: dividerColor, width: 1.0),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 44,
                width: 1.0,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: dividerColor,
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    items[i].value,
                    style: GoogleFonts.amiri(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: items[i].valueColor ??
                          (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  if (items[i].subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      items[i].subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: labelColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Numbered Section Tile ("01", "02", "03" style from C:\UI UX\4).
class MinisterialNumberedCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MinisterialNumberedCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final numColor = theme.colorScheme.primary;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: AppRadius.card,
          border: Border.all(color: dividerColor, width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number "01", "02" in Amiri Serif
            Container(
              width: 38,
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                number,
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: numColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.amiri(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      height: 1.4,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
