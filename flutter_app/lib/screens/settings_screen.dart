import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../presentation/blocs/theme/theme_cubit.dart';
import '../presentation/blocs/theme/theme_state.dart';
import '../presentation/widgets/widgets.dart';
import '../services/app_update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdate = false;
  String _updateStatusMsg = '';

  Future<void> _manualCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() { _checkingUpdate = true; _updateStatusMsg = 'جارٍ التحقق...'; });

    final info = await AppUpdateService.instance.checkForUpdate();

    if (!mounted) return;
    if (info == null) {
      setState(() {
        _checkingUpdate = false;
        _updateStatusMsg = 'التطبيق محدَّث ✅';
      });
    } else {
      setState(() {
        _checkingUpdate = false;
        _updateStatusMsg = 'يوجد تحديث v${info.version} — جارٍ التنزيل...';
      });
      await AppUpdateService.instance.checkAndDownloadSilently(
        onReadyToInstall: (i) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('تحديث v${i.version} جاهز للتثبيت'),
              action: SnackBarAction(
                label: 'تثبيت',
                onPressed: () => AppUpdateService.instance.installDownloadedApk(),
              ),
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      );
      if (mounted) setState(() => _updateStatusMsg = 'التحديث يُثبَّت في الخلفية...');
    }
  }

  TextStyle _getPreviewStyle(String fontFamily, double size, FontWeight weight, Color color) {
    switch (fontFamily) {
      case 'Cairo':
        return GoogleFonts.cairo(fontSize: size, fontWeight: weight, color: color);
      case 'Tajawal':
        return GoogleFonts.tajawal(fontSize: size, fontWeight: weight, color: color);
      case 'Amiri':
      default:
        return GoogleFonts.amiri(fontSize: size, fontWeight: weight, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.tune_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'إعدادات المظهر والخطوط',
                style: AppTypography.titleBold(context, fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          final cubit = context.read<ThemeCubit>();
          final currentScale = themeState.fontScale;
          final currentFamily = themeState.fontFamily;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تخصيص القراءة والنصوص', style: AppTypography.verveHeaderTitle(context)),
                          const SizedBox(height: 4),
                          Text(
                            'عدّل حجم ونوع الخط ولون الثيم بما يناسب راحة عينيك؛ تنعكس التغييرات فوراً على كامل التطبيق.',
                            style: AppTypography.verveSubtitle(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 1. Live Preview Box (آية المعاينة المباشرة)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFAF7F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'معاينة حيّة مباشرة',
                                  style: AppTypography.titleBold(context, fontSize: 13.5, color: primaryColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              UnifiedBadge(
                                label: '${(currentScale * 100).toInt()}% • $currentFamily',
                                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                                textColor: AppColors.goldDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              '﴿ إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ ﴾',
                              textAlign: TextAlign.center,
                              style: _getPreviewStyle(
                                currentFamily,
                                22 * currentScale,
                                FontWeight.bold,
                                isDark ? AppColors.goldBright : AppColors.obsidianEspresso,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'رعاية شؤون المساجد وحلقات تحفيظ القرآن الكريم والعلوم الشرعية وفق أعلى معايير الإتقان.',
                              textAlign: TextAlign.center,
                              style: _getPreviewStyle(
                                currentFamily,
                                13.5 * currentScale,
                                FontWeight.normal,
                                isDark ? Colors.white70 : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(height: 1, thickness: 0.8, color: dividerColor),
                    const SizedBox(height: 20),

                    // 2. Font Size & Font Shape (فوراً تحت المعاينة المباشرة)
                    Row(
                      children: [
                        Icon(Icons.text_fields_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'حجم الخط العام',
                            style: AppTypography.titleBold(context, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('اختر المقياس الأنسب لقراءة النصوص والآيات القرآنية:', style: AppTypography.verveSubtitle(context)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScaleChip(context, cubit, 'صغير (85%)', 0.85, currentScale, isDark),
                        _buildScaleChip(context, cubit, 'افتراضي (100%)', 1.0, currentScale, isDark),
                        _buildScaleChip(context, cubit, 'كبير (115%)', 1.15, currentScale, isDark),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Icon(Icons.font_download_outlined, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نوع وشكل الخط المعتمد',
                            style: AppTypography.titleBold(context, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('الخط المستخدم لعناوين ونصوص التطبيق:', style: AppTypography.verveSubtitle(context)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFamilyChip(context, cubit, 'أميري (القرآني الأصيل)', 'Amiri', currentFamily, isDark),
                        _buildFamilyChip(context, cubit, 'تجوال (هادئ ومعاصر)', 'Tajawal', currentFamily, isDark),
                        _buildFamilyChip(context, cubit, 'كايرو (هندسي عريض)', 'Cairo', currentFamily, isDark),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          cubit.setFontScale(1.0);
                          cubit.setFontFamily('Amiri');
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('استعادة الخط الافتراضي', style: AppTypography.buttonText(color: primaryColor).copyWith(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Divider(height: 1, thickness: 0.8, color: dividerColor),
                    const SizedBox(height: 20),

                    // 3. Theme Palettes Selector (دوائر ملونة أنيقة بدون أي عناوين أو أوصاف)
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ثيم التطبيق والألوان',
                            style: AppTypography.titleBold(context, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('اختر الدائرة اللونية المفضلة لتطبيقه فوراً:', style: AppTypography.verveSubtitle(context)),
                    const SizedBox(height: 18),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: AppColors.palettes.map((pal) {
                          final isSelected = themeState.paletteId == pal.id;

                          return InkWell(
                            onTap: () => cubit.setPalette(pal.id),
                            customBorder: const CircleBorder(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: pal.gradient,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : AppColors.goldDark)
                                      : Colors.white.withValues(alpha: 0.8),
                                  width: isSelected ? 3.2 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? pal.primary.withValues(alpha: 0.55)
                                        : Colors.black.withValues(alpha: 0.12),
                                    blurRadius: isSelected ? 12 : 6,
                                    spreadRadius: isSelected ? 2 : 0,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── قسم الإصدار والتحديث ──────────────────────
                    _buildVersionSection(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// قسم رقم الإصدار في الإعدادات
  Widget _buildVersionSection(bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 8),
              Text('معلومات التطبيق',
                  style: AppTypography.font(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54)),
            ],
          ),
          const SizedBox(height: 14),

          // رقم الإصدار
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإصدار الحالي',
                  style: AppTypography.font(fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'v${AppUpdateService.currentVersion}',
                  style: AppTypography.font(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // زر التحقق اليدوي
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checkingUpdate ? null : _manualCheckUpdate,
              icon: _checkingUpdate
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: primaryColor))
                  : Icon(Icons.refresh_rounded, size: 18, color: primaryColor),
              label: Text(
                _checkingUpdate ? 'جارٍ التحقق...' : 'التحقق من التحديثات',
                style: AppTypography.font(fontSize: 14, color: primaryColor),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // رسالة الحالة
          if (_updateStatusMsg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_updateStatusMsg,
                style: AppTypography.font(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black45)),
          ],
        ],
      ),
    );
  }

  Widget _buildScaleChip(
      BuildContext context,
      ThemeCubit cubit,
      String label,
      double value,
      double currentValue,
      bool isDark,
      ) {
    final isSelected = (currentValue - value).abs() < 0.01;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.buttonText(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.obsidianEspresso),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      onSelected: (v) {
        if (v) cubit.setFontScale(value);
      },
    );
  }

  Widget _buildFamilyChip(
      BuildContext context,
      ThemeCubit cubit,
      String label,
      String familyName,
      String currentFamily,
      bool isDark,
      ) {
    final isSelected = currentFamily == familyName;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.buttonText(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.obsidianEspresso),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      onSelected: (v) {
        if (v) cubit.setFontFamily(familyName);
      },
    );
  }
}
