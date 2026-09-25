import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/printable_badge_dialog.dart';

/// Ultra-compact, responsive header banner for the student profile view.
/// Optimally arranged in 2 sleek rows to minimize vertical footprint on mobile devices.
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
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 10 : 14),
      decoration: BoxDecoration(
        gradient: AppColors.sunsetTwilightGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.heroBanner,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Student Avatar + Info + Points Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: isSmall ? 22 : 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Text(
                          firstLetter,
                          style: AppTypography.font(
                            color: Colors.white,
                            fontSize: isSmall ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),

              // Name & Halaqa/Sheikh
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: AppTypography.font(
                        color: Colors.white,
                        fontSize: isSmall ? 17 : 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${mosque.name} • ${halaqa.name} • إشراف ${sheikh.fullName}',
                      style: AppTypography.font(
                        color: const Color(0xFFF9EAE1),
                        fontSize: isSmall ? 11.5 : 13,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Points Trophy Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: AppColors.goldBright, size: 16),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'رصيد النقاط',
                          style: AppTypography.font(
                            color: const Color(0xFFF9EAE1),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${student.totalPoints}',
                          style: AppTypography.font(
                            color: AppColors.goldBright,
                            fontSize: isSmall ? 15 : 18,
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
          const SizedBox(height: 8),

          // Row 2: Role Badge + Digital QR Badge Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Guardian Verification Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: AppColors.goldBright, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      student.gender == 'female' ? 'ملف الطالبة وولية الأمر' : 'ملف الطالب وولي الأمر',
                      style: AppTypography.font(
                        color: AppColors.goldBright,
                        fontSize: isSmall ? 10.5 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // QR Digital Badge Button
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
                      profileImageUrl: student.profileImageUrl,
                    ),
                  );
                },
                icon: Icon(Icons.qr_code, size: 14, color: AppColors.obsidianEspresso),
                label: Text(
                  'بطاقتي الرقمية / QR',
                  style: AppTypography.buttonText(color: AppColors.obsidianEspresso).copyWith(
                    fontSize: isSmall ? 11 : 12.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.obsidianEspresso,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: 4),
                  minimumSize: const Size(0, 28),
                  elevation: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}