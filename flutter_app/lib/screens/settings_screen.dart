import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppUpdateService.instance.state == SilentUpdateState.idle &&
          AppUpdateService.instance.latestInfo == null) {
        AppUpdateService.instance.checkForUpdate();
      }
    });
  }

  Future<void> _manualCheckUpdate() async {
    await AppUpdateService.instance.checkForUpdate();
  }

  TextStyle _getPreviewStyle(String fontFamily, double size, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
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
                    const SizedBox(height: 20),

                    // ── بطاقة الموقع الرسمي ──────────────────────
                    _buildOfficialWebsiteCard(isDark),
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

  /// قسم رقم الإصدار والتحديث التفاعلي في الإعدادات
  Widget _buildVersionSection(bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return ListenableBuilder(
      listenable: AppUpdateService.instance,
      builder: (context, _) {
        final service = AppUpdateService.instance;
        final state = service.state;
        final latest = service.latestInfo;

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
                  Icon(Icons.system_update_rounded, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'معلومات التطبيق والتحديثات',
                      style: AppTypography.titleBold(context, fontSize: 14.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // رقم الإصدار الحالي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('الإصدار المثبت حالياً', style: AppTypography.font(fontSize: 14.5)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'v${AppUpdateService.currentVersion}',
                      style: AppTypography.font(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── حالة التحديثات التفاعلية ──
              if (state == SilentUpdateState.checking) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'جارٍ التحقق من وجود إصدار جديد...',
                        style: AppTypography.font(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (state == SilentUpdateState.updateAvailable && latest != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.new_releases_rounded, color: AppColors.goldDark, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يتوفر إصدار جديد: v${latest.version}',
                              style: AppTypography.titleBold(context, fontSize: 14, color: AppColors.goldDark),
                            ),
                          ),
                        ],
                      ),
                      if (latest.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          latest.releaseNotes,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.font(
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => service.startDownload(latest),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('تنزيل التحديث الآن'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (state == SilentUpdateState.downloading) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'جارٍ تنزيل التحديث...',
                                style: AppTypography.titleBold(context, fontSize: 13.5),
                              ),
                            ],
                          ),
                          Text(
                            service.formattedProgress,
                            style: AppTypography.titleBold(context, fontSize: 14, color: primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: service.downloadProgress > 0 ? service.downloadProgress : null,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        service.formattedSize,
                        style: AppTypography.font(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => service.pauseOrCancelDownload(),
                              icon: const Icon(Icons.pause_circle_outline, size: 18),
                              label: const Text('إيقاف مؤقت'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => service.cancelDownload(),
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                            label: Text(
                              'إلغاء',
                              style: AppTypography.font(fontSize: 13, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (state == SilentUpdateState.paused) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Text('تم الإيقاف المؤقت', style: AppTypography.titleBold(context, fontSize: 13.5)),
                            ],
                          ),
                          Text(service.formattedProgress, style: AppTypography.titleBold(context, fontSize: 13.5, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: service.downloadProgress,
                          minHeight: 8,
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(service.formattedSize, style: AppTypography.font(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => service.resumeDownload(),
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: const Text('استئناف التنزيل'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => service.cancelDownload(),
                            child: Text('إلغاء', style: AppTypography.font(fontSize: 13, color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (state == SilentUpdateState.readyToInstall) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'اكتمل التنزيل بنجاح! جاهز للتثبيت 🚀',
                              style: AppTypography.titleBold(context, fontSize: 14, color: Colors.green.shade800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Platform.isAndroid
                            ? 'انقر بالأسفل لفتح مثبت الأندرويد. إذا طُلب منك، فعّل «السماح بتثبيت التطبيقات من هذا المصدر» لمحراب.'
                            : 'انقر بالأسفل لإعادة تشغيل محراب وتثبيت التحديث الجديد بسلاسة.',
                        style: AppTypography.font(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => service.installDownloadedUpdate(),
                          icon: Icon(
                            Platform.isAndroid ? Icons.system_update_rounded : Icons.restart_alt_rounded,
                            size: 20,
                          ),
                          label: Text(
                            Platform.isAndroid ? 'تثبيت التحديث الآن 🚀' : 'إعادة التشغيل وتثبيت التحديث 🔄',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () async {
                            await service.cancelDownload();
                            if (latest != null) service.startDownload(latest);
                          },
                          child: Text(
                            'إعادة التنزيل من البداية',
                            style: AppTypography.font(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (state == SilentUpdateState.installing) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'جارٍ فتح مثبت النظام...',
                        style: AppTypography.font(fontSize: 13, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ] else if (state == SilentUpdateState.error) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              service.errorMessage ?? 'تعذر تنزيل التحديث',
                              style: AppTypography.font(fontSize: 13, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () => service.resumeDownload(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // الحالة الافتراضية: idle
                if (service.statusMessage.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          service.statusMessage,
                          style: AppTypography.font(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _manualCheckUpdate,
                    icon: Icon(Icons.refresh_rounded, size: 18, color: primaryColor),
                    label: Text(
                      'التحقق من وجود تحديثات',
                      style: AppTypography.font(fontSize: 14, color: primaryColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// بطاقة الموقع الرسمي لتطبيق محراب
  Widget _buildOfficialWebsiteCard(bool isDark) {
    const websiteUrl = 'https://hassnmo998-del.github.io/mihrab-app/';
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموقع الرسمي لتطبيق محراب',
                      style: AppTypography.font(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.obsidianEspresso,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تحميل الإصدارات لجميع الأجهزة ومتابعة التحديثات',
                      style: AppTypography.font(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    websiteUrl,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    textDirection: TextDirection.ltr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(websiteUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('زيارة الموقع الرسمي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: websiteUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ رابط الموقع الرسمي بنجاح 📋'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('نسخ'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                ),
              ),
            ],
          ),
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
        style: TextStyle(
          fontFamily: familyName,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
