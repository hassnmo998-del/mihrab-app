import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'zad_card.dart';

/// Modal dialog for immersive reading of Zad Al-Muslim cards.
class ZadDetailDialog extends StatelessWidget {
  final ZadItemCard cardData;
  final double fontSize;
  final bool isDark;

  const ZadDetailDialog({
    super.key,
    required this.cardData,
    required this.fontSize,
    required this.isDark,
  });

  static void show(BuildContext context, ZadItemCard cardData, double fontSize, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => ZadDetailDialog(
        cardData: cardData,
        fontSize: fontSize,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cardData.categoryName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cardData.accentColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cardData.title,
                style: GoogleFonts.notoNaskhArabic(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardData.accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  cardData.content,
                  style: GoogleFonts.amiri(
                    fontSize: fontSize + 2,
                    height: 1.9,
                  ),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (cardData.instructionOrDua != null && cardData.instructionOrDua!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cardData.instructionOrDua!,
                    style: GoogleFonts.notoNaskhArabic(
                      fontSize: 14,
                      color: AppColors.emeraldPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (cardData.reflectionOrBenefit != null && cardData.reflectionOrBenefit!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'الفائدة والأثر الوجداني: ${cardData.reflectionOrBenefit}',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
              if (cardData.source != null && cardData.source!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'المصدر والتخريج: [${cardData.source}]',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
