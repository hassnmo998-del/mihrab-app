import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Centralized Ministerial Input Field (C:\UI UX\4 Style).
/// Eliminates default Flutter raw borders and provides a luxury,
/// ministerial aesthetic with warm tints, smooth radiuses, and refined typography.
class MinisterialTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final bool isRequired;
  final bool isPill;

  const MinisterialTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.validator,
    this.isRequired = false,
    this.isPill = false,
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
    final borderRadius = isPill ? BorderRadius.circular(999) : BorderRadius.circular(14);

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
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          onChanged: onChanged,
          onTap: onTap,
          validator: validator,
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            color: primaryTextColor,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            errorText: errorText,
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: isPill
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: focusColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
            hintStyle: GoogleFonts.cairo(
              fontSize: 13,
              color: secondaryTextColor.withValues(alpha: 0.7),
            ),
            helperStyle: GoogleFonts.cairo(
              fontSize: 11,
              color: secondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill Search Field (C:\UI UX\4 Style).
class MinisterialSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const MinisterialSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'بحث...',
  });

  @override
  Widget build(BuildContext context) {
    return MinisterialTextField(
      controller: controller,
      hintText: hintText,
      isPill: true,
      onChanged: onChanged,
      prefixIcon: Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.primary),
      suffixIcon: controller != null && controller!.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, size: 16),
              onPressed: () {
                controller?.clear();
                onClear?.call();
                onChanged?.call('');
              },
            )
          : null,
    );
  }
}
