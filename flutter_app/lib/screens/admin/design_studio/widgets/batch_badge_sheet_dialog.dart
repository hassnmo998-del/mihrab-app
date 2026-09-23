import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/badge_design_config.dart';
import '../services/design_export_service.dart';
import 'badge_card_render_view.dart';

class BatchItemData {
  final String name;
  final String roleLabel;
  final String code;
  final String? halaqaName;
  final String? sheikhName;
  final String? phone;
  final String? birthDate;
  final String? profileImageUrl;

  const BatchItemData({
    required this.name,
    required this.roleLabel,
    required this.code,
    this.halaqaName,
    this.sheikhName,
    this.phone,
    this.birthDate,
    this.profileImageUrl,
  });
}

class BatchBadgeSheetDialog extends StatefulWidget {
  final String mosqueName;
  final String title;
  final List<BatchItemData> items;
  final BadgeDesignConfig config;

  const BatchBadgeSheetDialog({
    super.key,
    required this.mosqueName,
    required this.title,
    required this.items,
    required this.config,
  });

  @override
  State<BatchBadgeSheetDialog> createState() => _BatchBadgeSheetDialogState();
}

class _BatchBadgeSheetDialogState extends State<BatchBadgeSheetDialog> {
  final GlobalKey _sheetKey = GlobalKey();
  int _currentPage = 0;
  static const int _itemsPerPage = 6; // 6 cards per A4 page for balanced fit

  int get _totalPages => (widget.items.length / _itemsPerPage).ceil().clamp(1, 9999);

  List<BatchItemData> get _currentPageItems {
    final start = _currentPage * _itemsPerPage;
    return widget.items.skip(start).take(_itemsPerPage).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.print_outlined, color: AppColors.goldDark, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppTypography.font(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.obsidianEspresso,
                            ),
                          ),
                          Text(
                            'إجمالي البطاقات: ${widget.items.length} بطاقة • صفحة ${_currentPage + 1} من $_totalPages',
                            style: AppTypography.font(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // A4 Sheet Canvas Preview
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: _sheetKey,
                      child: Container(
                        width: 720,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header of printable sheet
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'مسرد بطاقات الاعتماد الرسمية - ${widget.mosqueName}',
                                    style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  Text(
                                    'ورقة A4 مجهزة للقص والتغليف الحراري (الصفحة ${_currentPage + 1})',
                                    style: AppTypography.font(fontSize: 10, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            // Grid of 6 badges (2 cols x 3 rows)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: _currentPageItems.map((item) {
                                return Transform.scale(
                                  scale: 0.68,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                        width: 1,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: BadgeCardRenderView(
                                      name: item.name,
                                      roleLabel: item.roleLabel,
                                      code: item.code,
                                      mosqueName: widget.mosqueName,
                                      halaqaName: item.halaqaName,
                                      sheikhName: item.sheikhName,
                                      phone: item.phone,
                                      birthDate: item.birthDate,
                                      profileImageUrl: item.profileImageUrl,
                                      config: widget.config,
                                      isDark: false, // Print sheets always white
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pagination and Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page controller
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        tooltip: 'الصفحة السابقة',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentPage + 1} / $_totalPages',
                        style: AppTypography.font(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                        onPressed: _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        tooltip: 'الصفحة التالية',
                      ),
                    ],
                  ),

                  // Actions
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('حفظ الصفحة كصورة'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          DesignExportService.saveToDevice(
                            context: context,
                            boundaryKey: _sheetKey,
                            fileNamePrefix: 'batch_badges_page_${_currentPage + 1}',
                            pixelRatio: 2.5,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('مشاركة / طباعة الصفحة'),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          DesignExportService.shareDesign(
                            context: context,
                            boundaryKey: _sheetKey,
                            fileNamePrefix: 'batch_badges_page_${_currentPage + 1}',
                            shareMessage: 'مسرد بطاقات الاعتماد الرسمية لـ ${widget.mosqueName} (صفحة ${_currentPage + 1})',
                            pixelRatio: 2.5,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
