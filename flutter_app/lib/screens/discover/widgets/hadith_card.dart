import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hadith_service.dart';

class HadithCard extends StatefulWidget {
  final NawawiHadith hadith;
  final bool isDark;
  final double fontSize;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const HadithCard({
    super.key,
    required this.hadith,
    required this.isDark,
    required this.fontSize,
    required this.onCopy,
    required this.onShare,
  });

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.hadith;
    final isDark = widget.isDark;
    final primaryColor = Theme.of(context).primaryColor;
    final isLong = h.matn.length > 280;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.goldDark),
                ),
                child: Text(
                  '${h.number}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.goldDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(h.narrator, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54)),
                        if (h.book == 'riyad')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.goldDark.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(h.chapter, style: TextStyle(fontSize: 10, color: AppColors.goldDark, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'نسخ الحديث',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: widget.onCopy,
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, size: 18, color: primaryColor),
                tooltip: 'مشاركة الحديث',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: widget.onShare,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Matn Container with expand/collapse capability
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFFFFDF9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  h.matn,
                  maxLines: _isExpanded ? null : (isLong ? 5 : null),
                  overflow: _isExpanded ? TextOverflow.clip : (isLong ? TextOverflow.ellipsis : TextOverflow.clip),
                  style: GoogleFonts.amiri(
                    fontSize: widget.fontSize,
                    height: 1.85,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                if (isLong) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _isExpanded ? 'طي الحديث' : 'قراءة الحديث كاملاً',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Educational values & benefits
          if (h.fawaid.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'فوائد تربوية: ${h.fawaid}',
                      style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? Colors.white70 : AppColors.obsidianEspresso),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),

          // Source
          Align(
            alignment: Alignment.centerLeft,
            child: Text(h.source, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: primaryColor)),
          ),
        ],
      ),
    );
  }
}
