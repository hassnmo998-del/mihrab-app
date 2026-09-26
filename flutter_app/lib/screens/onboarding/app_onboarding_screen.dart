import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/data_service.dart';
import '../../services/app_update_service.dart';

class AppOnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const AppOnboardingScreen({super.key, this.onFinished});

  @override
  State<AppOnboardingScreen> createState() => _AppOnboardingScreenState();
}

class _AppOnboardingScreenState extends State<AppOnboardingScreen> {
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            AppUpdateService.instance.checkAndPromptUpdate(context: context);
          }
        });
      });
    }
  }

  Future<void> _handleConfirm() async {
    setState(() => _isSubmitting = true);
    final data = context.read<DataService>();
    // الدخول التلقائي والمباشر على وضع المستخدم الشخصي العادي
    await data.completeOnboarding('personal');
    if (mounted) {
      widget.onFinished?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFBF9F5),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Emblem
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.terracottaPrimary.withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.mosque,
                                size: 48,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title & Subtitle
                    Text(
                      'مَرْحَباً بِكُمْ فِي مَنَصَّة مِحْرَاب',
                      textAlign: TextAlign.center,
                      style: AppTypography.font(
                        fontSize: isWide ? 26 : 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'المنظومة الرقمية الشاملة لرعاية بيوت الله وحلقات تحفيظ القرآن الكريم',
                      textAlign: TextAlign.center,
                      style: AppTypography.font(
                        fontSize: isWide ? 15 : 13.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Feature highlights container for normal user mode
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkInputFill
                            : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 16,
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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 22,
                                  color: AppColors.terracottaPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'خدمات ومميزات المنصة للمستخدمين والطلاب',
                                  style: AppTypography.font(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureBullet(Icons.menu_book, 'المصحف الشريف الملون بأحكام التجويد والحفظ', isDark),
                          _buildFeatureBullet(Icons.access_time_filled, 'الأذكار اليومية ومواقيت الصلاة وبوصلة القبلة', isDark),
                          _buildFeatureBullet(Icons.school, 'متابعة حفظ الطالب وسجل النقاط والجوائز', isDark),
                          _buildFeatureBullet(Icons.emoji_events, 'لوحة الشرف وتنافس الحلقات القرآنية', isDark),
                          _buildFeatureBullet(Icons.volunteer_activism, 'تصفح تبرعات المساجد ودعمها عبر الباركود', isDark),
                          _buildFeatureBullet(Icons.qr_code_scanner, 'بوابة التفويض لمسح بطاقة الشيخ أو الإدارة فورياً', isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Confirm CTA Button
                    Center(
                      child: SizedBox(
                        width: isWide ? 380 : double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.terracottaPrimary,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: AppColors.terracottaPrimary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'بدء استخدام المنصة',
                                      style: AppTypography.font(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.terracottaPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.font(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
