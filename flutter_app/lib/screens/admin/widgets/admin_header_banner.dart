import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/printable_badge_dialog.dart';
import '../../../widgets/qr_dialogs.dart';
import 'women_branch_provision_dialog.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../services/data_service.dart';

class AdminHeaderBanner extends StatelessWidget {
  final Mosque mosque;
  final int sheikhsCount;
  final int halaqatCount;
  final int studentsCount;
  final int coursesCount;
  final int tripsCount;
  final int tracksCount;
  final int rewardsCount;
  final int eventsCount;
  final bool isDark;

  const AdminHeaderBanner({
    super.key,
    required this.mosque,
    required this.sheikhsCount,
    required this.halaqatCount,
    required this.studentsCount,
    required this.coursesCount,
    required this.tripsCount,
    required this.tracksCount,
    required this.rewardsCount,
    required this.eventsCount,
    required this.isDark,
  });

  Widget _buildVerveStatItem({
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTypography.font(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTypography.font(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark ? Colors.white12 : const Color(0x1F2A211D);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Mosque Header Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.sunsetTwilightGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.heroBanner,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          mosque.gender == 'female' ? 'مجمع نسائي معتمد' : 'مسجد معتمد رسمياً',
                          style: AppTypography.font(
                            color: AppColors.goldBright,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Header Action Buttons
                  Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        tooltip: 'بطاقة مدير المسجد والباركود',
                        icon: const Icon(Icons.badge_outlined, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PrintableBadgeDialog(
                              title: 'بطاقة مدير المسجد الرسمية',
                              name: 'إدارة ${mosque.name}',
                              roleLabel: 'مدير المسجد المعتمد',
                              mosqueName: mosque.name,
                              code: mosque.accessCode,
                            ),
                          );
                        },
                      ),
                      // زر القسم النسائي يظهر في إدارة الرجال فقط: هو المنفذ
                      // الوحيد لإنشاء إدارة نسائية، ولا يعرض أي بيانات للفرع
                      // النسائي بعد إنشائه.
                      if (!mosque.isWomenSection)
                        IconButton(
                          tooltip: mosque.hasWomenBranch
                              ? 'القسم النسائي (منشأ)'
                              : 'إنشاء إدارة القسم النسائي',
                          icon: Icon(
                            mosque.hasWomenBranch
                                ? Icons.verified_user_outlined
                                : Icons.female,
                            color: Colors.white,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            shape: const CircleBorder(),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) =>
                                  WomenBranchProvisionDialog(mosqueId: mosque.id),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: 'رمز اعتماد الصراف ',
                        icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => SectionQrCodeDialog(
                              title: 'رمز اعتماد الصراف ',
                              subtitle: 'اعطِ هذا الباركود لأمين الصندوق أو صراف المسجد لفتح واجهة صرف الجوائز للطلاب',
                              code: mosque.effectiveCashierCode,
                              icon: Icons.point_of_sale,
                              primaryColor: AppColors.gold,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'تحديث موقع المسجد الحالي 📍',
                        icon: const Icon(Icons.location_searching, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          shape: const CircleBorder(),
                        ),
                        onPressed: () async {
                          try {
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                            }
                            if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                              final pos = await Geolocator.getCurrentPosition();
                              if (context.mounted) {
                                final data = context.read<DataService>();
                                data.updateMosque(
                                  id: mosque.id,
                                  name: mosque.name,
                                  address: mosque.address ?? '',
                                  city: mosque.city,
                                  phone: mosque.phone,
                                  latitude: pos.latitude,
                                  longitude: pos.longitude,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('تم تحديث موقع المسجد إلى موقعك الحالي بنجاح! 📍'),
                                    backgroundColor: AppColors.emeraldPrimary,
                                  ),
                                );
                              }
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('حدث خطأ أثناء تحديث الموقع')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                mosque.name,
                style: AppTypography.font(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${mosque.city} • ${mosque.address ?? "الموقع المعتمد لوزارة الأوقاف"}',
                style: AppTypography.font(
                  color: const Color(0xFFF9EAE1),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Verve Open Stats Grid
        Divider(height: 1, thickness: 0.8, color: dividerColor),
        IntrinsicHeight(
          child: Row(
            children: [
              _buildVerveStatItem(
                value: '$sheikhsCount',
                label: 'المحفظون',
                valueColor: AppColors.terracottaPrimary,
              ),
              VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
              _buildVerveStatItem(
                value: '$halaqatCount',
                label: 'الحلقات',
                valueColor: AppColors.gold,
              ),
              VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
              _buildVerveStatItem(
                value: '$studentsCount',
                label: 'الطلاب',
                valueColor: isDark ? Colors.white : AppColors.obsidianEspresso,
              ),
              VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
              _buildVerveStatItem(
                value: '$coursesCount',
                label: 'الدورات',
                valueColor: AppColors.terracottaPrimary,
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.8, color: dividerColor),
        IntrinsicHeight(
          child: Row(
            children: [
              _buildVerveStatItem(
                value: '$tripsCount',
                label: 'الرحلات',
                valueColor: AppColors.gold,
              ),
              VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
              _buildVerveStatItem(
                value: '$tracksCount',
                label: 'المناهج',
                valueColor: isDark ? Colors.white : AppColors.obsidianEspresso,
              ),
              VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
              _buildVerveStatItem(
                value: '$rewardsCount',
                label: 'الجوائز',
                valueColor: AppColors.terracottaPrimary,
              ),
              VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
              _buildVerveStatItem(
                value: '$eventsCount',
                label: 'الفعاليات',
                valueColor: AppColors.gold,
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.8, color: dividerColor),
      ],
    );
  }
}