import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Semantic Status Type for unified badges.
enum UnifiedBadgeType {
  present,       // حاضر
  absent,        // غائب
  lateStatus,    // متأخر
  active,        // جارية
  finished,      // منتهية
  smartDetection,// كشف ذكي
  custom,
}

/// Centralized Reusable Status Badge Component.
///
/// Ensures consistent badge visuals across the app adhering to:
/// - [AppRadius.badge] (8px border radius)
/// - [AppSpacing.badgePadding] (10px horizontal, 4px vertical)
/// - Unified typography via [AppTypography.badgeText]
/// - Semantic colors for statuses (حاضر, غائب, متأخر, جارية, منتهية, كشف ذكي)
class UnifiedBadge extends StatelessWidget {
  /// The text label to display.
  final String label;

  /// Semantic badge type.
  final UnifiedBadgeType type;

  /// Primary semantic color for text and border calculations.
  final Color? color;

  /// Background color override.
  final Color? backgroundColor;

  /// Border color override.
  final Color? borderColor;

  /// Text color override.
  final Color? textColor;

  /// Optional leading icon.
  final IconData? icon;

  /// Custom icon widget.
  final Widget? iconWidget;

  /// Whether to display the icon if available. Defaults to true.
  final bool showIcon;

  /// Whether to show a small circular status dot indicator.
  final bool showDot;

  /// Custom padding override. Defaults to [AppSpacing.badgePadding].
  final EdgeInsetsGeometry? padding;

  /// Custom border radius override. Defaults to [AppRadius.badge].
  final BorderRadius? borderRadius;

  /// Font size for label. Defaults to 11.0.
  final double fontSize;

  /// Optional tap callback.
  final VoidCallback? onTap;

  const UnifiedBadge({
    super.key,
    required this.label,
    this.type = UnifiedBadgeType.custom,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.icon,
    this.iconWidget,
    this.showIcon = true,
    this.showDot = false,
    this.padding = AppSpacing.badgePadding,
    this.borderRadius,
    this.fontSize = 11.0,
    this.onTap,
  });

  /// Factory for Present attendance status (حاضر).
  factory UnifiedBadge.present({
    Key? key,
    String label = 'حاضر',
    IconData? icon = Icons.check_circle_outline_rounded,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    return UnifiedBadge(
      key: key,
      label: label,
      type: UnifiedBadgeType.present,
      color: AppColors.attendancePresent,
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  /// Factory for Absent attendance status (غائب).
  factory UnifiedBadge.absent({
    Key? key,
    String label = 'غائب',
    IconData? icon = Icons.cancel_outlined,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    return UnifiedBadge(
      key: key,
      label: label,
      type: UnifiedBadgeType.absent,
      color: AppColors.attendanceAbsent,
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  /// Factory for Late attendance status (متأخر).
  factory UnifiedBadge.late({
    Key? key,
    String label = 'متأخر',
    IconData? icon = Icons.schedule_rounded,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    return UnifiedBadge(
      key: key,
      label: label,
      type: UnifiedBadgeType.lateStatus,
      color: AppColors.attendanceLate,
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  /// Factory for Active / Ongoing status (جارية).
  factory UnifiedBadge.active({
    Key? key,
    String label = 'جارية',
    IconData? icon = Icons.play_circle_outline_rounded,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    return UnifiedBadge(
      key: key,
      label: label,
      type: UnifiedBadgeType.active,
      color: AppColors.emeraldPrimary,
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  /// Factory for Finished / Completed status (منتهية).
  factory UnifiedBadge.finished({
    Key? key,
    String label = 'منتهية',
    IconData? icon = Icons.task_alt_rounded,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    return UnifiedBadge(
      key: key,
      label: label,
      type: UnifiedBadgeType.finished,
      color: const Color(0xFF64748B), // Slate 500
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  /// Factory for Smart Timing Detection badge (كشف ذكي).
  factory UnifiedBadge.smartDetection({
    Key? key,
    String label = 'كشف ذكي',
    IconData? icon = Icons.auto_awesome_rounded,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    return UnifiedBadge(
      key: key,
      label: label,
      type: UnifiedBadgeType.smartDetection,
      color: const Color(0xFF0284C7), // Sky 600
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  /// Smart dynamic factory that detects the semantic status from a text string.
  ///
  /// Matches:
  /// - `حاضر` / `present` -> [UnifiedBadge.present]
  /// - `غائب` / `absent` -> [UnifiedBadge.absent]
  /// - `متأخر` / `late` -> [UnifiedBadge.late]
  /// - `جارية` / `active` / `current` -> [UnifiedBadge.active]
  /// - `منتهية` / `finished` / `completed` -> [UnifiedBadge.finished]
  /// - `كشف ذكي` / `smart` -> [UnifiedBadge.smartDetection]
  factory UnifiedBadge.fromStatus(
    String status, {
    Key? key,
    IconData? icon,
    Widget? iconWidget,
    bool showIcon = true,
    bool showDot = false,
    EdgeInsetsGeometry? padding = AppSpacing.badgePadding,
    BorderRadius? borderRadius,
    double fontSize = 11.0,
    VoidCallback? onTap,
  }) {
    final lower = status.trim().toLowerCase();

    if (lower.contains('حاضر') || lower.contains('present')) {
      return UnifiedBadge.present(
        key: key,
        label: status,
        icon: icon ?? Icons.check_circle_outline_rounded,
        iconWidget: iconWidget,
        showIcon: showIcon,
        showDot: showDot,
        padding: padding,
        borderRadius: borderRadius,
        fontSize: fontSize,
        onTap: onTap,
      );
    } else if (lower.contains('غائب') || lower.contains('absent')) {
      return UnifiedBadge.absent(
        key: key,
        label: status,
        icon: icon ?? Icons.cancel_outlined,
        iconWidget: iconWidget,
        showIcon: showIcon,
        showDot: showDot,
        padding: padding,
        borderRadius: borderRadius,
        fontSize: fontSize,
        onTap: onTap,
      );
    } else if (lower.contains('متأخر') || lower.contains('late')) {
      return UnifiedBadge.late(
        key: key,
        label: status,
        icon: icon ?? Icons.schedule_rounded,
        iconWidget: iconWidget,
        showIcon: showIcon,
        showDot: showDot,
        padding: padding,
        borderRadius: borderRadius,
        fontSize: fontSize,
        onTap: onTap,
      );
    } else if (lower.contains('جارية') || lower.contains('active') || lower.contains('current')) {
      return UnifiedBadge.active(
        key: key,
        label: status,
        icon: icon ?? Icons.play_circle_outline_rounded,
        iconWidget: iconWidget,
        showIcon: showIcon,
        showDot: showDot,
        padding: padding,
        borderRadius: borderRadius,
        fontSize: fontSize,
        onTap: onTap,
      );
    } else if (lower.contains('منتهية') || lower.contains('finished') || lower.contains('completed')) {
      return UnifiedBadge.finished(
        key: key,
        label: status,
        icon: icon ?? Icons.task_alt_rounded,
        iconWidget: iconWidget,
        showIcon: showIcon,
        showDot: showDot,
        padding: padding,
        borderRadius: borderRadius,
        fontSize: fontSize,
        onTap: onTap,
      );
    } else if (lower.contains('كشف ذكي') || lower.contains('smart')) {
      return UnifiedBadge.smartDetection(
        key: key,
        label: status,
        icon: icon ?? Icons.auto_awesome_rounded,
        iconWidget: iconWidget,
        showIcon: showIcon,
        showDot: showDot,
        padding: padding,
        borderRadius: borderRadius,
        fontSize: fontSize,
        onTap: onTap,
      );
    }

    return UnifiedBadge(
      key: key,
      label: status,
      color: AppColors.emeraldPrimary,
      icon: icon,
      iconWidget: iconWidget,
      showIcon: showIcon,
      showDot: showDot,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = _resolveBaseColor(isDark);
    final effectiveBg = backgroundColor ??
        baseColor.withValues(alpha: isDark ? 0.20 : 0.10);
    final effectiveBorder = borderColor ??
        baseColor.withValues(alpha: isDark ? 0.45 : 0.28);
    final effectiveText = textColor ??
        (isDark ? _lightenForDark(baseColor) : baseColor);
    final effectiveRadius = borderRadius ?? AppRadius.badge;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showDot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: effectiveText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.s6),
        ],
        if (showIcon && (iconWidget != null || icon != null)) ...[
          iconWidget ??
              Icon(
                icon,
                size: fontSize + 3,
                color: effectiveText,
              ),
          const SizedBox(width: AppSpacing.s4),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.badgeText(
              color: effectiveText,
              fontSize: fontSize,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    Widget badgeWidget = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(color: effectiveBorder, width: 1.0),
      ),
      child: content,
    );

    if (onTap != null) {
      badgeWidget = InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: badgeWidget,
      );
    }

    return badgeWidget;
  }

  Color _resolveBaseColor(bool isDark) {
    if (color != null) return color!;

    switch (type) {
      case UnifiedBadgeType.present:
        return AppColors.attendancePresent;
      case UnifiedBadgeType.absent:
        return AppColors.attendanceAbsent;
      case UnifiedBadgeType.lateStatus:
        return AppColors.attendanceLate;
      case UnifiedBadgeType.active:
        return isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
      case UnifiedBadgeType.finished:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      case UnifiedBadgeType.smartDetection:
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      case UnifiedBadgeType.custom:
        return isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary;
    }
  }

  Color _lightenForDark(Color c) {
    // Return brightened readable color in dark mode if needed
    if (type == UnifiedBadgeType.active) return AppColors.emeraldLight;
    if (type == UnifiedBadgeType.smartDetection) return const Color(0xFF38BDF8);
    if (type == UnifiedBadgeType.finished) return const Color(0xFFCBD5E1);
    return c;
  }
}
