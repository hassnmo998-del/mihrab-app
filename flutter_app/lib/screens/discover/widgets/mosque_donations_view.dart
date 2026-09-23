import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/unified_badge.dart';
import '../../../services/data_service.dart';

/// Mosque Electronic Donations View: Allows worshippers to browse mosques,
/// view Sham Cash barcodes, copy account numbers, and donate seamlessly.
class MosqueDonationsView extends StatefulWidget {
  final bool isDark;

  const MosqueDonationsView({super.key, this.isDark = false});

  @override
  State<MosqueDonationsView> createState() => _MosqueDonationsViewState();
}

class _MosqueDonationsViewState extends State<MosqueDonationsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label إلى الحافظة بنجاح: $text ✨'),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget? _buildSafeBarcode(Mosque mosque, double size) {
    final imgUrl = mosque.donationImageUrl;
    if (imgUrl == null || imgUrl.trim().isEmpty) {
      return null;
    }
    if (imgUrl.startsWith('data:image')) {
      try {
        final commaIndex = imgUrl.indexOf(',');
        final base64String = commaIndex != -1 ? imgUrl.substring(commaIndex + 1) : imgUrl;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        );
      } catch (_) {
        return null;
      }
    }
    if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
      return Image.network(
        imgUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey),
        ),
      );
    }
    try {
      final file = File(imgUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        );
      }
    } catch (_) {}
    return null;
  }

  void _showFullScreenBarcode(BuildContext context, Mosque mosque) {
    if (mosque.donationImageUrl == null || mosque.donationImageUrl!.trim().isEmpty) {
      return;
    }
    final primary = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'باركود التبرع الإلكتروني',
                          style: AppTypography.titleBold(context, fontSize: 16),
                        ),
                        Text(
                          mosque.name,
                          style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Barcode Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildSafeBarcode(mosque, 230) ?? const SizedBox.shrink(),
              ),
              const SizedBox(height: 18),

              if (mosque.donationAccountNumber != null && mosque.donationAccountNumber!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        mosque.donationAccountNumber!,
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy_rounded, size: 20, color: primary),
                        onPressed: () => _copyToClipboard(context, mosque.donationAccountNumber!, 'رقم الحساب'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('مشاركة بطاقة التبرع', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final shareText = '''
تبرع لمسجد ${mosque.name}:
اسم الحساب: ${mosque.donationAccountName ?? mosque.name}
رقم الحساب / شام كاش: ${mosque.donationAccountNumber ?? "غير محدد"}
الوصف: ${mosque.donationDescription ?? "صدقة جارية وبناء لبيوت الله"}
— تم النشر عبر منصة محراب
'''.trim();
                    Share.share(shareText);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    // قائمة التبرعات عامة: لا تُعرض المجمعات النسائية لزائر أو مستخدم من فرع الرجال
    final mosques = data.getVisibleMosques();
    final isDark = widget.isDark;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final filteredMosques = mosques.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.name.contains(_searchQuery) ||
          m.city.contains(_searchQuery) ||
          (m.address != null && m.address!.contains(_searchQuery));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sham Cash Info Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التبرع الإلكتروني ودعم بيوت الله',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'يمكنكم التبرع بسهولة عبر مسح باركود (شام كاش) أو نسخ أرقام الحسابات المعتمدة مباشرة لكل مسجد.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search Box
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المسجد أو المدينة للتبرع...',
            prefixIcon: Icon(Icons.search, color: primaryColor),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                : null,
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: dividerColor)),
          ),
        ),
        const SizedBox(height: 16),

        // Mosques Donation Cards List
        if (filteredMosques.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('لا توجد مساجد مسجلة حالياً', style: AppTypography.verveSubtitle(context)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredMosques.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, idx) {
              final mosque = filteredMosques[idx];
              final hasActive = mosque.hasActiveDonation;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasActive
                        ? primaryColor.withValues(alpha: 0.35)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: hasActive ? 1.5 : 1.0,
                  ),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.mosque_rounded, color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mosque.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${mosque.city} • ${mosque.address ?? "العنوان"}',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        UnifiedBadge(
                          label: hasActive ? 'التبرع متاح ✨' : 'بانتظار التفعيل',
                          backgroundColor: hasActive
                              ? primaryColor.withValues(alpha: 0.15)
                              : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
                          textColor: hasActive ? primaryColor : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (hasActive) ...[
                      // Donation Details Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Row(
                          children: [
                            // Barcode Preview / Tap to Zoom (Shown ONLY if an image was uploaded)
                            if (mosque.donationImageUrl != null && mosque.donationImageUrl!.trim().isNotEmpty) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showFullScreenBarcode(context, mosque),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                      ),
                                      child: _buildSafeBarcode(mosque, 64) ?? const SizedBox.shrink(),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],

                            // Account Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mosque.donationAccountName ?? 'حساب التبرعات المعتمد',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  if (mosque.donationAccountNumber != null && mosque.donationAccountNumber!.isNotEmpty)
                                    Row(
                                      children: [
                                        Text(
                                          mosque.donationAccountNumber!,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _copyToClipboard(context, mosque.donationAccountNumber!, 'رقم الحساب'),
                                          child: Icon(Icons.copy_rounded, size: 15, color: primaryColor),
                                        ),
                                      ],
                                    ),
                                  if (mosque.donationDescription != null && mosque.donationDescription!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      mosque.donationDescription!,
                                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Actions Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(side: BorderSide(color: primaryColor), shape: const StadiumBorder()),
                              icon: Icon(Icons.qr_code_scanner_rounded, size: 16, color: primaryColor),
                              label: Text('تكبير الباركود', style: TextStyle(color: primaryColor, fontSize: 12)),
                              onPressed: () => _showFullScreenBarcode(context, mosque),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: const StadiumBorder()),
                              icon: const Icon(Icons.copy_all_rounded, size: 16),
                              label: const Text('نسخ الحساب', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                if (mosque.donationAccountNumber != null && mosque.donationAccountNumber!.isNotEmpty) {
                                  _copyToClipboard(context, mosque.donationAccountNumber!, 'رقم الحساب');
                                } else {
                                  _copyToClipboard(context, mosque.name, 'اسم المسجد');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Inactive Donation Notice
                      Text(
                        'لم تقم إدارة هذا المسجد بإدراج باركود التبرع الإلكتروني حتى الآن.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
