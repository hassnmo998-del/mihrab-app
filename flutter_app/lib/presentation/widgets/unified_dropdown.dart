import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Centralized Ministerial Dropdown Field (C:\UI UX\4 Style).
/// Completely removes raw default Flutter dropdown boxes and borders.
/// Features warm ivory/espresso backgrounds, smooth 14px outer radius,
/// custom bronze chevrons, and 18px rounded popup menus with checkmarks.
class MinisterialDropdownField<T> extends StatelessWidget {
  final String? label;
  final String? hintText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? prefixIcon;
  final bool isRequired;
  final String? Function(T?)? validator;

  const MinisterialDropdownField({
    super.key,
    this.label,
    this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.isRequired = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final fillColor = isDark ? AppColors.darkInputFill : AppColors.lightInputFill;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final focusColor = theme.colorScheme.primary;
    final menuColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                if (isRequired)
                  Text(
                    ' *',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          dropdownColor: menuColor,
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            color: primaryTextColor,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: focusColor, width: 1.5),
            ),
            hintStyle: GoogleFonts.cairo(
              fontSize: 13,
              color: secondaryTextColor.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
