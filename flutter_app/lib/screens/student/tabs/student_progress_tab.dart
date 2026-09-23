import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/quran_data.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';
import '../dialogs/student_juz_modal.dart';

class StudentProgressTab extends StatelessWidget {
  final Student student;
  final List<PointsLog> logs;
  final bool isDark;

  const StudentProgressTab({
    super.key,
    required this.student,
    required this.logs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    final overallProg = data.getStudentOverallQuranProgress(student.id);
    final completedAjzaCount = overallProg['completedAjza'] as int;
    final totalMemorizedAyahs = overallProg['memorizedAyahs'] as int;
    final totalAyahs = overallProg['totalAyahs'] as int;
    final overallPct = ((overallProg['progress'] as double) * 100).toStringAsFixed(1);

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master Quran Progress Banner (Verve Sunset Twilight Gradient)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.sunsetTwilightGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.heroBanner,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_stories, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الإنجاز العام لختم القرآن الكريم',
                            style: AppTypography.titleBold(context, color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المجموع الكلي للآيات المتقنة من المصحف الشريف (6,236 آية)',
                            style: AppTypography.bodyRegular(
                              context,
                              color: const Color(0xFFF9EAE1),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.goldBright,
                        borderRadius: BorderRadius.circular(AppRadius.rPill),
                      ),
                      child: Text(
                        '$overallPct%',
                        style: AppTypography.titleBold(
                          context,
                          color: AppColors.obsidianEspresso,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: overallProg['progress'] as double,
                    minHeight: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldBright),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'تم إتقان $totalMemorizedAyahs من أصل $totalAyahs آية',
                      style: AppTypography.bodyRegular(context, color: Colors.white, fontSize: 12.5),
                    ),
                    Text(
                      '$completedAjzaCount من 30 جزءاً مكتملاً',
                      style: AppTypography.titleBold(context, color: const Color(0xFFA7F3D0), fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 30 Ajza Section Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'متابعة الحفظ في الأجزاء الثلاثين',
                style: AppTypography.verveHeaderTitle(context),
              ),
              UnifiedBadge(
                label: '$completedAjzaCount جزء مكتمل من 30',
                backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                textColor: AppColors.terracottaPrimary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'احتساب دقيق للآيات المحفوظة لكل جزء وفق التسميعات المعتمدة من فضيلة الشيخ:',
            style: AppTypography.verveSubtitle(context),
          ),
          const SizedBox(height: 16),

          // The 30 Ajza Open Verve List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 30,
            separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
            itemBuilder: (context, idx) {
              final juzNumber = idx + 1;
              final juzInfo = quranAjzaInfo[idx];
              final juzProg = data.getStudentJuzProgress(student.id, juzNumber);
              final count = juzProg['memorizedAyahs'] as int;
              final total = juzProg['totalAyahs'] as int;
              final prog = juzProg['progress'] as double;
              final isComp = juzProg['isCompleted'] as bool;
              final inProg = !isComp && count > 0;
              final pctStr = (prog * 100).toStringAsFixed(1);
              final serialNumber = juzNumber.toString().padLeft(2, '0');

              return InkWell(
                onTap: () => showStudentJuzModal(context, juzNumber, juzInfo, juzProg, isDarkTheme),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 01, 02 Serial Number
                          SizedBox(
                            width: 44,
                            child: Text(
                              serialNumber,
                              style: AppTypography.verveNumber(context).copyWith(
                                color: isComp
                                    ? AppColors.terracottaPrimary
                                    : (inProg ? AppColors.goldDark : null),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Juz Name & Starting Ayah
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  juzInfo.name,
                                  style: AppTypography.verveTitle(context),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  juzInfo.startDescription,
                                  style: AppTypography.verveSubtitle(context),
                                ),
                              ],
                            ),
                          ),

                          // Status Badge
                          UnifiedBadge(
                            label: isComp ? 'مكتمل ✨' : (inProg ? '$count / $total آية' : 'لم يبدأ'),
                            backgroundColor: isComp
                                ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                : (inProg ? AppColors.gold.withValues(alpha: 0.15) : (isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9))),
                            textColor: isComp
                                ? AppColors.terracottaPrimary
                                : (inProg ? AppColors.goldDark : (isDarkTheme ? Colors.white60 : AppColors.obsidianEspresso)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: prog,
                                minHeight: 6,
                                backgroundColor: isDarkTheme ? Colors.white10 : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isComp
                                      ? AppColors.terracottaPrimary
                                      : (inProg ? AppColors.gold : Colors.grey.shade400),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$pctStr%',
                            style: AppTypography.bodyRegular(
                              context,
                              color: isComp
                                  ? AppColors.terracottaPrimary
                                  : (inProg ? AppColors.goldDark : Colors.grey),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Divider(height: 1, thickness: 0.8, color: dividerColor),
          const SizedBox(height: 24),

          // Custom Subjects & Curricula Section
          Builder(
            builder: (ctx) {
              final subjectProgresses = data.getAllStudentSubjectProgresses(student.id);
              if (subjectProgresses.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المناهج والمتون الإضافية 📚',
                    style: AppTypography.verveHeaderTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'متابعة إنجاز الأحاديث والمتون والمنظومات العلمية:',
                    style: AppTypography.verveSubtitle(context),
                  ),
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subjectProgresses.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
                      final sp = subjectProgresses[idx];
                      final track = sp['track'] as RecitationTrack;
                      final uniqueUnits = sp['uniqueUnitsCount'] as int;
                      final totalUnits = sp['totalUnits'] as int;
                      final unitLabel = sp['unitLabel'] as String;
                      final progress = sp['progress'] as double;
                      final isCompleted = sp['isCompleted'] as bool;
                      final pct = (progress * 100).toStringAsFixed(1);
                      final serial = (idx + 1).toString().padLeft(2, '0');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(serial, style: AppTypography.verveNumber(context)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(track.name, style: AppTypography.verveTitle(context)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'أنجز $uniqueUnits من أصل $totalUnits $unitLabel',
                                        style: AppTypography.verveSubtitle(context),
                                      ),
                                    ],
                                  ),
                                ),
                                UnifiedBadge(
                                  label: isCompleted ? 'مكتمل بحمد الله 🎉' : '$pct%',
                                  backgroundColor: isCompleted
                                      ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                      : AppColors.gold.withValues(alpha: 0.15),
                                  textColor: isCompleted ? AppColors.terracottaPrimary : AppColors.goldDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: isDarkTheme ? Colors.white10 : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted ? AppColors.terracottaPrimary : AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 0.8, color: dividerColor),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // Last Recitations Section
          Text(
            'آخر جلسات التسميع المعتمدة',
            style: AppTypography.verveHeaderTitle(context),
          ),
          const SizedBox(height: 12),
          logs.where((l) => l.category == 'memorization').isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'لم يتم تسجيل تسميع بعد',
                style: AppTypography.verveSubtitle(context),
              ),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.where((l) => l.category == 'memorization').take(6).length,
            separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
            itemBuilder: (context, idx) {
              final log = logs.where((l) => l.category == 'memorization').take(6).toList()[idx];
              final serial = (idx + 1).toString().padLeft(2, '0');
              final dateFormatted = DateFormat('yyyy/MM/dd - hh:mm a').format(log.createdAt);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(serial, style: AppTypography.verveNumber(context)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.reason, style: AppTypography.verveTitle(context)),
                          const SizedBox(height: 2),
                          Text(dateFormatted, style: AppTypography.verveSubtitle(context)),
                        ],
                      ),
                    ),
                    UnifiedBadge(
                      label: '+${log.points} نقطة',
                      backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                      textColor: AppColors.goldDark,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
    );
  }
}