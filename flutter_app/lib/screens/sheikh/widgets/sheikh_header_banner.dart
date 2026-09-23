import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/printable_badge_dialog.dart';

class SheikhHeaderBanner extends StatelessWidget {
  final Sheikh sheikh;
  final String mosqueName;
  final int halaqatCount;
  final int studentsCount;
  final bool isDark;

  const SheikhHeaderBanner({
    super.key,
    required this.sheikh,
    required this.mosqueName,
    required this.halaqatCount,
    required this.studentsCount,
    required this.isDark,
  });

  ImageProvider? _resolveImage(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    return FileImage(File(trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImage(sheikh.profileImageUrl);
    final firstLetter = sheikh.fullName.trim().isNotEmpty
        ? sheikh.fullName.trim().substring(0, 1)
        : 'ش';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.sunsetTwilightGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.heroBanner,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف العلوي: الشارة وزر الـ QR
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: AppColors.goldBright, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'المحفظ المعتمد بالحلقات',
                      style: AppTypography.font(
                        color: AppColors.goldBright,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => PrintableBadgeDialog(
                      title: 'بطاقة المحفظ المعتمد',
                      name: sheikh.fullName,
                      roleLabel: 'محفظ حلقة معتمد',
                      mosqueName: mosqueName,
                      code: sheikh.code,
                    ),
                  );
                },
                icon: Icon(Icons.qr_code, color: AppColors.obsidianEspresso, size: 18),
                label: Text(
                  'بطاقة المحفظ والباركود',
                  style: AppTypography.font(
                    color: AppColors.obsidianEspresso,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.obsidianEspresso,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // تفاصيل الشيخ مع الصورة الشخصية
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // إطار الصورة الشخصية للشيخ
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Text(
                    firstLetter,
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // الاسم والإحصائيات التابعة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheikh.fullName,
                      style: AppTypography.font(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$mosqueName • $halaqatCount حلقات قرآنية • $studentsCount طالباً مسجلاً',
                      style: AppTypography.font(
                        color: const Color(0xFFF9EAE1),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}