import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Centralized Reusable Card Component.
///
/// Ensures consistent cards across the app adhering to:
/// - [AppRadius.card] (16px border radius)
/// - [AppSpacing.cardPadding] (16px standard insets)
/// - Light/Dark mode backgrounds ([AppColors.lightSurface] / [AppColors.darkCard])
/// - Standard borders ([AppColors.lightBorder] / [AppColors.darkBorder])
/// - Standard shadows ([AppShadows.card])
class UnifiedCard extends StatelessWidget {
  /// The widget content inside the card.
  final Widget child;

  /// Inset padding for the card content. Defaults to [AppSpacing.cardPadding].
  final EdgeInsetsGeometry? padding;

  /// Outer margin surrounding the card. Defaults to vertical 6px.
  final EdgeInsetsGeometry? margin;

  /// Background color override. Automatically adapts to light/dark if null.
  final Color? color;

  /// Border color override. Automatically adapts to light/dark if null.
  final Color? borderColor;

  /// Border width. Defaults to 1.0. Set to 0 to disable visible border.
  final double borderWidth;

  /// Border radius. Defaults to [AppRadius.card] (16px).
  final BorderRadius? borderRadius;

  /// Elevation depth for the card.
  final double elevation;

  /// Custom box shadow list override.
  final List<BoxShadow>? shadows;

  /// Optional click callback. Enables ripple effect if provided.
  final VoidCallback? onTap;

  /// Optional long press callback.
  final VoidCallback? onLongPress;

  /// Optional double tap callback.
  final VoidCallback? onDoubleTap;

  /// Clipping behavior for rounded corners. Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  /// Optional gradient background.
  final Gradient? gradient;

  /// Fixed width constraint.
  final double? width;

  /// Fixed height constraint.
  final double? height;

  const UnifiedCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin = const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.elevation = 0.0,
    this.shadows,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.clipBehavior = Clip.antiAlias,
    this.gradient,
    this.width,
    this.height,
  });

  /// Factory constructor for elevated card with noticeable shadow.
  factory UnifiedCard.elevated({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding = AppSpacing.cardPadding,
    EdgeInsetsGeometry? margin = const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
    Color? color,
    Color? borderColor,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double? width,
    double? height,
  }) {
    return UnifiedCard(
      key: key,
      padding: padding,
      margin: margin,
      color: color,
      borderColor: borderColor,
      borderWidth: 1.0,
      borderRadius: borderRadius,
      elevation: 2.0,
      shadows: AppShadows.card,
      onTap: onTap,
      onLongPress: onLongPress,
      width: width,
      height: height,
      child: child,
    );
  }

  /// Factory constructor for a flat card without shadows or borders.
  factory UnifiedCard.flat({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding = AppSpacing.cardPadding,
    EdgeInsetsGeometry? margin = const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
    Color? color,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    return UnifiedCard(
      key: key,
      padding: padding,
      margin: margin,
      color: color,
      borderWidth: 0,
      borderRadius: borderRadius,
      elevation: 0,
      shadows: AppShadows.none,
      onTap: onTap,
      width: width,
      height: height,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBgColor = color ?? (isDark ? AppColors.darkCard : AppColors.lightSurface);
    final effectiveBorderColor = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final effectiveRadius = borderRadius ?? AppRadius.card;

    final isInteractive = onTap != null || onLongPress != null || onDoubleTap != null;

    Widget cardContent = padding != null
        ? Padding(
            padding: padding!,
            child: child,
          )
        : child;

    if (isInteractive) {
      cardContent = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onDoubleTap: onDoubleTap,
        borderRadius: effectiveRadius,
        child: cardContent,
      );
    }

    Widget result = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? effectiveBgColor : null,
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: borderWidth > 0
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
        boxShadow: shadows ?? (elevation > 0 ? AppShadows.card : null),
      ),
      clipBehavior: clipBehavior,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: effectiveRadius,
        child: cardContent,
      ),
    );

    return result;
  }
}
