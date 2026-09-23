import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class CompetitionLeaderboardTab extends StatefulWidget {
  final String gender;
  final bool isDark;
  final String? initialCourseId;

  const CompetitionLeaderboardTab({
    super.key,
    required this.gender,
    this.isDark = false,
    this.initialCourseId,
  });

  @override
  State<CompetitionLeaderboardTab> createState() => _CompetitionLeaderboardTabState();
}

class _CompetitionLeaderboardTabState extends State<CompetitionLeaderboardTab> {
  late String _selectedCourseId;
  String _selectedMosqueId = 'all';
  String _selectedHalaqaId = 'all';
  
  // خيارات التصفية الزمنية الجديدة
  String _timeRange = 'all'; // 'all', 'week', 'month', 'year', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final mosques = data.getMosques(gender: widget.gender);
    final branchMosqueIds = mosques.map((m) => m.id).toSet();
    final courses = data
        .getIntensiveCourses()
        .where((c) => branchMosqueIds.contains(c.mosqueId))
        .toList();
    
    // تم فك القيد: الآن نجلب الحلقات حتى لو كان "جميع المساجد" مختاراً
    final halaqat = data.getHalaqat(
      mosqueId: _selectedMosqueId == 'all' ? null : _selectedMosqueId,
    ).where((h) {
      // تصفية إضافية للتأكد من مطابقة الجنس في حال عرض قائمة عامة
      final m = data.getMosqueById(h.mosqueId);
      return m?.gender == widget.gender;
    }).toList();

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    // تجهيز تواريخ التصفية بناءً على الخيار المختار
    DateTime? filterStart;
    DateTime? filterEnd;
    final now = DateTime.now();

    if (_timeRange == 'week') {
      filterStart = now.subtract(const Duration(days: 7));
      filterEnd = now;
    } else if (_timeRange == 'month') {
      filterStart = now.subtract(const Duration(days: 30));
      filterEnd = now;
    } else if (_timeRange == 'year') {
      filterStart = DateTime(now.year, 1, 1);
      filterEnd = now;
    } else if (_timeRange == 'custom') {
      filterStart = _startDate;
      filterEnd = _endDate;
    }

    final rankings = data.getRankings(
      mosqueId: _selectedMosqueId,
      halaqaId: _selectedHalaqaId,
      gender: widget.gender,
      courseId: _selectedCourseId == 'all' ? null : _selectedCourseId,
      startDate: filterStart,
      endDate: filterEnd,
    );

    final selectedCourse = _selectedCourseId != 'all'
        ? courses.firstWhere(
          (c) => c.id == _selectedCourseId,
      orElse: () => IntensiveCourse(
        id: '',
        mosqueId: '',
        name: 'الدورة',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Course Filter Dropdown
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey('rank_course_$_selectedCourseId'),
          initialValue: _selectedCourseId,
          decoration: InputDecoration(
            labelText: 'نوع الترتيب والمنافسة',
            prefixIcon: Icon(Icons.emoji_events_outlined, size: 20, color: AppColors.goldDark),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text(
                '⭐ الترتيب العام الشامل (جميع النقاط المعتمدة)',
                style: AppTypography.titleBold(context, fontSize: 13),
              ),
            ),
            ...courses.map((c) => DropdownMenuItem(
              value: c.id,
              child: Text(
                '🎓 دورة استثنائية: ${c.name}',
                style: AppTypography.bodyRegular(context, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: (val) => setState(() => _selectedCourseId = val ?? 'all'),
        ),
        const SizedBox(height: 10),

        // Time Range Filter
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _timeRange,
          decoration: const InputDecoration(
            labelText: 'النطاق الزمني للترتيب',
            prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('🏆 الترتيب التاريخي العام (منذ البداية)')),
            DropdownMenuItem(value: 'week', child: Text('📅 أبطال هذا الأسبوع (آخر 7 أيام)')),
            DropdownMenuItem(value: 'month', child: Text('🗓️ أبطال هذا الشهر (آخر 30 يوم)')),
            DropdownMenuItem(value: 'year', child: Text('✨ أبطال العام الحالي')),
            DropdownMenuItem(value: 'custom', child: Text('🛠️ فترة مخصصة (من تاريخ إلى تاريخ)')),
          ],
          onChanged: (val) => setState(() {
            _timeRange = val ?? 'all';
            if (_timeRange != 'custom') {
              _startDate = null;
              _endDate = null;
            }
          }),
        ),
        
        if (_timeRange == 'custom') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? now,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'اختر تاريخ البداية',
                    );
                    if (d != null) setState(() => _startDate = d);
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_startDate == null ? 'من تاريخ' : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? now,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: 'اختر تاريخ النهاية',
                    );
                    if (d != null) setState(() => _endDate = d);
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_endDate == null ? 'إلى تاريخ' : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),

        // Mosque & Halaqa Scope Filters
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('rank_mosque_$_selectedMosqueId'),
                initialValue: _selectedMosqueId,
                decoration: const InputDecoration(
                  labelText: 'المسجد',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('جميع المساجد', style: AppTypography.bodyRegular(context, fontSize: 13)),
                  ),
                  ...mosques.map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(m.name, style: AppTypography.bodyRegular(context, fontSize: 13), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (val) => setState(() {
                  _selectedMosqueId = val ?? 'all';
                  _selectedHalaqaId = 'all';
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('rank_halaqa_${_selectedMosqueId}_$_selectedHalaqaId'),
                initialValue: _selectedHalaqaId,
                decoration: const InputDecoration(
                  labelText: 'الحلقة القرآنية',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('جميع الحلقات', style: AppTypography.bodyRegular(context, fontSize: 13)),
                  ),
                  ...halaqat.map((h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, style: AppTypography.bodyRegular(context, fontSize: 13), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: _selectedMosqueId == 'all'
                    ? (val) => setState(() => _selectedHalaqaId = val ?? 'all')
                    : (val) => setState(() {
                  _selectedHalaqaId = val ?? 'all';
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Course Info Note
        if (selectedCourse != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'ترتيب خاص بدورة: "${selectedCourse.name}" • تُحتسب حصراً نقاط التسميع القرآني والمتون المسجلة خلال هذه الدورة.',
              style: AppTypography.bodyRegular(context, color: AppColors.terracottaPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Leaderboard Content (Podium + Open List)
        Expanded(
          child: rankings.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'لا توجد بيانات ترتيب مسجلة في هذا النطاق حالياً',
                style: AppTypography.verveSubtitle(context),
              ),
            ),
          )
              : ListView(
            children: [
              // Open Minimalist Podium
              if (rankings.isNotEmpty) _buildPodium(context, rankings, isDarkTheme),
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 0.8, color: dividerColor),
              const SizedBox(height: 8),

              // Full Rankings List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rankings.length,
                separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                itemBuilder: (context, idx) {
                  final item = rankings[idx];
                  final st = item['student'] as Student;
                  final score = item['score'] as int;
                  final rank = item['rank'] as int;
                  final rankStr = rank.toString().padLeft(2, '0');

                  Color? rankColor;
                  if (rank == 1) {
                    rankColor = const Color(0xFFD97706);
                  } else if (rank == 2) {
                    rankColor = const Color(0xFF64748B);
                  } else if (rank == 3) {
                    rankColor = const Color(0xFFB45309);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Serial Rank Number
                        SizedBox(
                          width: 50,
                          child: Text(
                            rankStr,
                            maxLines: 1,
                            softWrap: false,
                            style: AppTypography.verveNumber(context).copyWith(
                              color: rankColor,
                              fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // صورة الطالب
                        ProfileImagePicker(
                          radius: 19,
                          isEditable: false,
                          initialImageUrl: st.profileImageUrl,
                          fallbackName: st.fullName,
                          onImageChanged: (_) {},
                        ),
                        const SizedBox(width: 12),

                        // Student Name & Halaqa
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    st.fullName,
                                    style: AppTypography.verveTitle(context),
                                  ),
                                  if (rank == 1) const Text(' ', style: TextStyle(fontSize: 14)),
                                  if (rank == 2) const Text(' ', style: TextStyle(fontSize: 14)),
                                  if (rank == 3) const Text(' ', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item['mosqueName']} • ${item['halaqaName']}',
                                style: AppTypography.verveSubtitle(context),
                              ),
                            ],
                          ),
                        ),

                        // Score Badge
                        UnifiedBadge(
                          label: '$score نقطة 🪙',
                          backgroundColor: rank <= 3
                              ? AppColors.gold.withValues(alpha: 0.15)
                              : (isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9)),
                          textColor: rank <= 3
                              ? AppColors.goldDark
                              : (isDarkTheme ? Colors.white70 : AppColors.obsidianEspresso),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Top 3 Podium (Verve Editorial Style)
  Widget _buildPodium(BuildContext context, List<Map<String, dynamic>> rankings, bool isDark) {
    final top1 = rankings.isNotEmpty ? rankings[0] : null;
    final top2 = rankings.length > 1 ? rankings[1] : null;
    final top3 = rankings.length > 2 ? rankings[2] : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2 (Silver)
          if (top2 != null)
            Expanded(child: _buildPodiumStep(context, top2, rank: 2, height: 85, medalColor: const Color(0xFF64748B), medalEmoji: '🥈', isDark: isDark))
          else
            const Expanded(child: SizedBox()),

          // Rank 1 (Gold)
          if (top1 != null)
            Expanded(child: _buildPodiumStep(context, top1, rank: 1, height: 110, medalColor: const Color(0xFFD97706), medalEmoji: '🥇', isDark: isDark))
          else
            const Expanded(child: SizedBox()),

          // Rank 3 (Bronze)
          if (top3 != null)
            Expanded(child: _buildPodiumStep(context, top3, rank: 3, height: 70, medalColor: const Color(0xFFB45309), medalEmoji: '🥉', isDark: isDark))
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(
      BuildContext context,
      Map<String, dynamic> item, {
        required int rank,
        required double height,
        required Color medalColor,
        required String medalEmoji,
        required bool isDark,
      }) {
    final st = item['student'] as Student;
    final score = item['score'] as int;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // صورة بطل التتويج مع شارة الميدالية
        Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileImagePicker(
              radius: rank == 1 ? 26 : 22,
              isEditable: false,
              initialImageUrl: st.profileImageUrl,
              fallbackName: st.fullName,
              onImageChanged: (_) {},
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(medalEmoji, style: TextStyle(fontSize: rank == 1 ? 14 : 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          st.fullName,
          style: AppTypography.titleBold(
            context,
            fontSize: rank == 1 ? 13 : 11.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '$score ن',
          style: AppTypography.bodyRegular(
            context,
            color: medalColor,
            fontSize: rank == 1 ? 13 : 11.5,
          ),
        ),
        Text(
          item['halaqaName'] ?? '',
          style: AppTypography.verveSubtitle(context).copyWith(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          height: height * 0.4,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: AppTypography.verveNumber(context).copyWith(
              color: medalColor,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}