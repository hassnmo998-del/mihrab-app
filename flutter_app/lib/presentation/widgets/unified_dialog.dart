import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Centralized Reusable Dialog Component.
///
/// Ensures all dialogs across the app adhere to:
/// - [AppRadius.dialog] (20px border radius)
/// - [AppSpacing.dialogPadding] (20px standard insets)
/// - Unified typography via [AppTypography]
/// - Theme-aware light/dark surfaces and borders
class UnifiedDialog extends StatelessWidget {
  /// The dialog title text.
  final String? title;

  /// Custom title widget, if more complex header layout is needed.
  final Widget? titleWidget;

  /// Descriptive message text shown below title.
  final String? message;

  /// Custom content widget.
  final Widget? content;

  /// Optional leading/header icon.
  final IconData? icon;

  /// Custom icon widget.
  final Widget? iconWidget;

  /// Color for the header icon (defaults to primary emerald).
  final Color? iconColor;

  /// Custom action buttons at the bottom.
  final List<Widget>? actions;

  /// Label for confirm button.
  final String? confirmText;

  /// Callback when confirm button is pressed.
  final VoidCallback? onConfirm;

  /// Custom color for confirm button (e.g. red for destructive action).
  final Color? confirmColor;

  /// Label for cancel button.
  final String? cancelText;

  /// Callback when cancel button is pressed.
  final VoidCallback? onCancel;

  /// Custom border radius override (defaults to [AppRadius.dialog]).
  final BorderRadius? borderRadius;

  /// Custom content padding override (defaults to [AppSpacing.dialogPadding]).
  final EdgeInsetsGeometry? padding;

  /// Maximum width constraint for desktop/tablet screens.
  final double maxWidth;

  /// Whether dialog can be closed with an 'X' button in top corner.
  final bool showCloseButton;

  const UnifiedDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.message,
    this.content,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.actions,
    this.confirmText,
    this.onConfirm,
    this.confirmColor,
    this.cancelText,
    this.onCancel,
    this.borderRadius,
    this.padding,
    this.maxWidth = 460,
    this.showCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.dialogTheme.backgroundColor ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final effectiveRadius = borderRadius ?? AppRadius.dialog;
    final effectivePadding = padding ?? AppSpacing.dialogPadding;
    final effectiveIconColor = iconColor ?? primaryColor;

    return Dialog(
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: effectiveRadius,
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: effectivePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with optional Icon and Close Button
              if (showCloseButton || icon != null || iconWidget != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null || iconWidget != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s10),
                        decoration: BoxDecoration(
                          color: effectiveIconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: iconWidget ??
                            Icon(
                              icon,
                              color: effectiveIconColor,
                              size: 26,
                            ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (showCloseButton)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: textSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),

              if (icon != null || iconWidget != null)
                const SizedBox(height: AppSpacing.s14),

              // Title Section
              if (titleWidget != null)
                titleWidget!
              else if (title != null)
                Text(
                  title!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ) ?? AppTypography.titleBold(context, fontSize: 17),
                  textAlign: TextAlign.start,
                ),

              // Scrollable Message and Content Section
              if (message != null || content != null) ...[
                const SizedBox(height: AppSpacing.s10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (message != null)
                          Text(
                            message!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textSecondary,
                              height: 1.45,
                            ) ?? AppTypography.bodyRegular(context, fontSize: 13),
                            textAlign: TextAlign.start,
                          ),
                        if (message != null && content != null)
                          const SizedBox(height: AppSpacing.s14),
                        if (content != null) content!,
                      ],
                    ),
                  ),
                ),
              ],

              // Actions Section
              if (_hasActions) ...[
                const SizedBox(height: AppSpacing.s16),
                _buildActions(context, primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      (actions != null && actions!.isNotEmpty) ||
      confirmText != null ||
      cancelText != null;

  Widget _buildActions(BuildContext context, Color primaryColor) {
    if (actions != null && actions!.isNotEmpty) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: actions!,
      );
    }

    final effectiveConfirmColor = confirmColor ?? primaryColor;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        if (cancelText != null)
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
              padding: AppSpacing.buttonPadding,
            ),
            child: Text(cancelText!),
          ),
        if (confirmText != null)
          ElevatedButton(
            onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: effectiveConfirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
              padding: AppSpacing.buttonPadding,
            ),
            child: Text(confirmText!),
          ),
      ],
    );
  }
}

/// Helper function to display a unified dialog adhering to centralized theme tokens.
///
/// Example:
/// ```dart
/// final confirmed = await showUnifiedDialog<bool>(
///   context: context,
///   title: 'تأكيد الحذف',
///   message: 'هل أنت متأكد من رغبتك في حذف هذا العنصر؟',
///   icon: Icons.delete_outline,
///   confirmText: 'حذف',
///   confirmColor: Colors.red,
///   cancelText: 'إلغاء',
/// );
/// ```
Future<T?> showUnifiedDialog<T>({
  required BuildContext context,
  String? title,
  Widget? titleWidget,
  String? message,
  Widget? content,
  IconData? icon,
  Widget? iconWidget,
  Color? iconColor,
  List<Widget>? actions,
  String? confirmText,
  VoidCallback? onConfirm,
  Color? confirmColor,
  String? cancelText,
  VoidCallback? onCancel,
  bool barrierDismissible = true,
  BorderRadius? borderRadius,
  EdgeInsetsGeometry? padding,
  double maxWidth = 460,
  bool showCloseButton = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => UnifiedDialog(
      title: title,
      titleWidget: titleWidget,
      message: message,
      content: content,
      icon: icon,
      iconWidget: iconWidget,
      iconColor: iconColor,
      actions: actions,
      confirmText: confirmText,
      onConfirm: onConfirm,
      confirmColor: confirmColor,
      cancelText: cancelText,
      onCancel: onCancel,
      borderRadius: borderRadius,
      padding: padding,
      maxWidth: maxWidth,
      showCloseButton: showCloseButton,
    ),
  );
}

/// Convenience helper for quick confirmation dialogs.
Future<bool> showUnifiedConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'تأكيد',
  String cancelText = 'إلغاء',
  Color? confirmColor,
  IconData icon = Icons.help_outline_rounded,
  Color? iconColor,
}) async {
  final result = await showUnifiedDialog<bool>(
    context: context,
    title: title,
    message: message,
    icon: icon,
    iconColor: iconColor,
    confirmText: confirmText,
    cancelText: cancelText,
    confirmColor: confirmColor,
  );
  return result ?? false;
}
