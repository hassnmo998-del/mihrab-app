import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/data_service.dart';
import '../../widgets/code_scanner_dialog.dart';

class ManagementPortalScreen extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(ActiveSession session)? onSessionUnlocked;

  const ManagementPortalScreen({
    super.key,
    this.onNavigateToTab,
    this.onSessionUnlocked,
  });

  void _scanRole(BuildContext context, {String? targetRole}) {
    showDialog(
      context: context,
      builder: (ctx) => CodeScannerDialog(
        targetRole: targetRole,
        onSessionUnlocked: (session) {
          onSessionUnlocked?.call(session);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mosqueSession = data.getSessionForRole('mosque_admin');
    final sheikhSession = data.getSessionForRole('sheikh');
    final cashierSession = data.getSessionForRole('cashier');
    final studentSession = data.getSessionForRole('student');

    final hasAnyAdmin = mosqueSession != null ||
        sheikhSession != null ||
        cashierSession != null ||
        studentSession != null;

    void lockAll() {
      data.disconnectRole('mosque_admin');
      data.disconnectRole('sheikh');
      data.disconnectRole('cashier');
      data.disconnectRole('student');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء كافة الجلسات وإعادة إخفاء التبويبات'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Hero Banner
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: isDark
                          ? [
                              AppColors.terracottaPrimary.withValues(alpha: 0.22),
                              const Color(0xFF1E293B),
                            ]
                          : [
                              AppColors.terracottaPrimary.withValues(alpha: 0.12),
                              const Color(0xFFFAF7F2),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.terracottaPrimary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.terracottaPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              color: AppColors.terracottaPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'بوابة الإدارة والتفويض',
                                      style: AppTypography.font(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppRadius.rPill),
                                      ),
                                      child: Text(
                                        'الفتح التدريجي',
                                        style: AppTypography.font(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.goldDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'المنظومة مصممة بحيث تظهر لك التبويبات والصلاحيات فور مسح رمز الاعتماد المخصص لرتبتك.',
                                  style: AppTypography.font(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hasAnyAdmin) ...[
                        const SizedBox(height: 18),
                        Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isSmall = constraints.maxWidth < 460;
                            if (isSmall) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_user_rounded, color: AppColors.emeraldSuccess, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'توجد جلسات مفوضة ونشطة حالياً على هذا الجهاز.',
                                          style: AppTypography.font(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.emeraldSuccess,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: lockAll,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.lock_reset, size: 18),
                                      label: Text('قفل وإنهاء الكل', style: AppTypography.font(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, color: AppColors.emeraldSuccess, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'توجد جلسات مفوضة ونشطة حالياً على هذا الجهاز.',
                                    style: AppTypography.font(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emeraldSuccess,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: lockAll,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.lock_reset, size: 18),
                                  label: Text('قفل وإنهاء الكل', style: AppTypography.font(fontSize: 12)),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section Title
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppColors.terracottaPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'بطاقات التفويض والاعتماد الإداري',
                        style: AppTypography.font(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Mosque Admin Card
                _buildRoleCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.mosque_rounded,
                  title: 'إدارة المسجد ولجان الإشراف',
                  description: 'امسح رمز QR لمدير المسجد لفتح لوحة التحكم الإدارية الكاملة للمسجد، المشايخ، الحلقات، والفعاليات.',
                  session: mosqueSession,
                  onScan: () => _scanRole(context, targetRole: 'mosque_admin'),
                  onOpenTab: () => onNavigateToTab?.call(1),
                  onDisconnect: () {
                    data.disconnectRole('mosque_admin');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم قفل جلسة مدير المسجد بنجاح')),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 2. Sheikh Card
                _buildRoleCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.menu_book_rounded,
                  title: 'الشيخ المحفظ وإدارة الحلقة',
                  description: 'امسح بطاقة اعتماد الشيخ للوصول الفوري إلى سجلات تسميع الطلاب، تسجيل الحضور، وجداول الدروس.',
                  session: sheikhSession,
                  onScan: () => _scanRole(context, targetRole: 'sheikh'),
                  onOpenTab: () => onNavigateToTab?.call(2),
                  onDisconnect: () {
                    data.disconnectRole('sheikh');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم قفل جلسة الشيخ بنجاح')),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 3. Student Card
                _buildRoleCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.school_rounded,
                  title: 'الطالب وولي الأمر',
                  description: 'امسح بطاقة الطالب لمتابعة الحفظ والحضور والنقاط وسجل التسميع.',
                  session: studentSession,
                  onScan: () => _scanRole(context, targetRole: 'student'),
                  onOpenTab: () => onNavigateToTab?.call(3),
                  onDisconnect: () {
                    data.disconnectRole('student');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم قفل جلسة الطالب بنجاح')),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 4. Cashier Card
                _buildRoleCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.point_of_sale_rounded,
                  title: 'أمين الصندوق وصراف الجوائز',
                  description: 'امسح كود الاعتماد المالي الممنوح لك (CSH-) لصرف مكافآت الطلاب واستبدال قسائم الجوائز فورياً.',
                  session: cashierSession,
                  onScan: () => _scanRole(context, targetRole: 'cashier'),
                  onOpenTab: () => onNavigateToTab?.call(5),
                  onDisconnect: () {
                    data.disconnectRole('cashier');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم قفل جلسة صراف الجوائز بنجاح')),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
    required ActiveSession? session,
    required VoidCallback onScan,
    required VoidCallback onOpenTab,
    required VoidCallback onDisconnect,
  }) {
    final isUnlocked = session != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? (isUnlocked ? const Color(0xFF132A1C) : const Color(0xFF1E293B).withValues(alpha: 0.6))
            : (isUnlocked ? const Color(0xFFF0FDF4) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? AppColors.emeraldSuccess.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
          width: isUnlocked ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.emeraldSuccess.withValues(alpha: 0.18)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isUnlocked ? AppColors.emeraldSuccess : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.font(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? (isDark ? Colors.white : const Color(0xFF065F46)) : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? AppColors.emeraldSuccess.withValues(alpha: 0.15)
                                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(AppRadius.rPill),
                            border: Border.all(
                              color: isUnlocked
                                  ? AppColors.emeraldSuccess.withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUnlocked ? Icons.check_circle : Icons.lock_outline,
                                size: 12,
                                color: isUnlocked ? AppColors.emeraldSuccess : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isUnlocked ? 'مفوض ومفتوح' : 'غير مفعل',
                                style: AppTypography.font(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked ? AppColors.emeraldSuccess : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'الحساب المعتمد: ${session.name} (${session.code})',
                        style: AppTypography.font(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.emeraldSuccess : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isUnlocked
                ? 'تم فتح التبويب المخصص بنجاح وأصبح متاحاً للتنقل المباشر من شريط التبويبات العلوي.'
                : description,
            style: AppTypography.font(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!isUnlocked)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracottaPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(
                      'مسح رمز QR أو إدخال الكود',
                      style: AppTypography.font(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOpenTab,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldSuccess,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      'الانتقال إلى التبويب المخصص',
                      style: AppTypography.font(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onDisconnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  icon: const Icon(Icons.lock, size: 16),
                  label: Text('قفل', style: AppTypography.font(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
