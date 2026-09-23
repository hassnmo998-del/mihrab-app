import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/printable_badge_dialog.dart';

class StudentHeaderBanner extends StatelessWidget {
  final Student student;
  final Mosque mosque;
  final Halaqa halaqa;
  final Sheikh sheikh;

  const StudentHeaderBanner({
    super.key,
    required this.student,
    required this.mosque,
    required this.halaqa,
    required this.sheikh,
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
    final isSmall = MediaQuery.of(context).size.width < 600;
    final imageProvider = _resolveImage(student.profileImageUrl);
    final firstLetter = student.fullName.trim().isNotEmpty
        ? student.fullName.trim().substring(0, 1)
        : '';

    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.sunsetTwilightGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.heroBanner,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف العلوي: الشارة + صندوق النقاط
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
                      student.gender == 'female' ? 'ملف الطالبة وولية الأمر' : 'ملف الطالب وولي الأمر',
                      style: AppTypography.font(
                        color: AppColors.goldBright,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Points Trophy Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: AppColors.goldBright, size: 18),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'رصيد النقاط',
                          style: AppTypography.font(
                            color: const Color(0xFFF9EAE1),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${student.totalPoints}',
                          style: AppTypography.font(
                            color: AppColors.goldBright,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 12 : 18),

          // تفاصيل الطالب مع صورته الشخصية
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // إطار الصورة الشخصية للطالب
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
                  radius: isSmall ? 28 : 36,
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

              // اسم وبيانات الطالب
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: AppTypography.font(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${mosque.name} • ${halaqa.name} • إشراف ${sheikh.fullName}',
                      style: AppTypography.font(
                        color: const Color(0xFFF9EAE1),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 18),

          // زر بطاقة QR
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => PrintableBadgeDialog(
                      title: 'بطاقة الطالب الرسمية',
                      name: student.fullName,
                      roleLabel: student.gender == 'female' ? 'طالبة في الحلقة' : 'طالب في الحلقة',
                      mosqueName: mosque.name,
                      code: student.code,
                    ),
                  );
                },
                icon: Icon(Icons.qr_code, size: 18, color: AppColors.obsidianEspresso),
                label: Text(
                  'بطاقتي الرقمية / QR',
                  style: AppTypography.buttonText(color: AppColors.obsidianEspresso),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.obsidianEspresso,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}