import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../presentation/widgets/unified_badge.dart';

/// Reusable, responsive presentation card for Zad Al-Muslim items.
/// Supports Allah Names, Ruqyah/Duas, Great Reward Deeds, and Prophetic Pearls.
class ZadItemCard extends StatelessWidget {
  final String title;
  final String categoryName;
  final String content;
  final String? subtitle;
  final String? reflectionOrBenefit;
  final String? source;
  final String? instructionOrDua;
  final IconData categoryIcon;
  final Color accentColor;
  final double fontSize;
  final bool isDark;
  final VoidCallback? onTap;

  const ZadItemCard({
    super.key,
    required this.title,
    required this.categoryName,
    required this.content,
    this.subtitle,
    this.reflectionOrBenefit,
    this.source,
    this.instructionOrDua,
    required this.categoryIcon,
    required this.accentColor,
    required this.fontSize,
    required this.isDark,
    this.onTap,
  });

  void _copyToClipboard(BuildContext context) {
    HapticFeedback.lightImpact();
    final buffer = StringBuffer();
    buffer.writeln('✦ $title ✦');
    if (subtitle != null && subtitle!.isNotEmpty) {
      buffer.writeln('[$subtitle]');
    }
    buffer.writeln('\n$content');
    if (instructionOrDua != null && instructionOrDua!.isNotEmpty) {
      buffer.writeln('\nالصيغة / التوجيه: $instructionOrDua');
    }
    if (reflectionOrBenefit != null && reflectionOrBenefit!.isNotEmpty) {
      buffer.writeln('\nالفائدة والأثر: $reflectionOrBenefit');
    }
    if (source != null && source!.isNotEmpty) {
      buffer.writeln('\nالمصدر والتخريج: [$source]');
    }
    buffer.writeln('\n— عبر منصة محراب وزاد المسلم');

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('تم نسخ "$title" إلى الحافظة بنجاح ✨'),
          ],
        ),
        backgroundColor: AppColors.emeraldPrimary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareContent() {
    HapticFeedback.lightImpact();
    final buffer = StringBuffer();
    buffer.writeln('✨ $title ✨');
    if (subtitle != null && subtitle!.isNotEmpty) {
      buffer.writeln('[$subtitle]');
    }
    buffer.writeln('\n$content');
    if (instructionOrDua != null && instructionOrDua!.isNotEmpty) {
      buffer.writeln('\nالصيغة / التوجيه:\n$instructionOrDua');
    }
    if (reflectionOrBenefit != null && reflectionOrBenefit!.isNotEmpty) {
      buffer.writeln('\nالفائدة الوجدانية:\n$reflectionOrBenefit');
    }
    if (source != null && source!.isNotEmpty) {
      buffer.writeln('\nالمصدر المعتمد: $source');
    }
    buffer.writeln('\n— عبر منصة محراب');
    Share.share(buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppRadius.card,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Badge + Category Icon + Action Buttons
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(categoryIcon, size: 18, color: accentColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          UnifiedBadge(
                            label: categoryName,
                            backgroundColor: accentColor.withValues(alpha: 0.12),
                            textColor: accentColor,
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'نسخ النص',
                      visualDensity: VisualDensity.compact,
                      color: isDark ? Colors.white70 : Colors.black54,
                      onPressed: () => _copyToClipboard(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 18),
                      tooltip: 'مشاركة',
                      visualDensity: VisualDensity.compact,
                      color: isDark ? Colors.white70 : Colors.black54,
                      onPressed: _shareContent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Main Title
                Text(
                  title,
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: fontSize + 1.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.obsidianEspresso,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),

                // Main Arabic / Descriptive Content
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFBF9F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    content,
                    style: GoogleFonts.amiri(
                      fontSize: fontSize,
                      fontWeight: FontWeight.normal,
                      height: 1.8,
                      color: isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF232B2B),
                    ),
                    textAlign: TextAlign.justify,
                    textDirection: TextDirection.rtl,
                  ),
                ),

                // Supplemental: Dua, Formula or Instruction if present
                if (instructionOrDua != null && instructionOrDua!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, size: 16, color: AppColors.emeraldPrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            instructionOrDua!,
                            style: GoogleFonts.notoNaskhArabic(
                              fontSize: fontSize * 0.88,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Reflection or Benefit
                if (reflectionOrBenefit != null && reflectionOrBenefit!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.goldDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reflectionOrBenefit!,
                          style: TextStyle(
                            fontSize: fontSize * 0.82,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Footer: Source and Tap indicator
                if (source != null && source!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 0.6),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 14, color: AppColors.emeraldPrimary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          source!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTap != null) ...[
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
