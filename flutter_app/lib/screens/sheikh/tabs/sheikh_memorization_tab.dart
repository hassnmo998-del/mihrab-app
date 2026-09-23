import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';
import '../widgets/sheikh_quran_recitation_inputs.dart';
import '../widgets/sheikh_today_recitations_card.dart';

class SheikhMemorizationTab extends StatefulWidget {
  final Sheikh sheikh;
  final List<Student> students;
  final List<Halaqa> halaqat;
  final bool isDark;

  const SheikhMemorizationTab({
    super.key,
    required this.sheikh,
    required this.students,
    required this.halaqat,
    required this.isDark,
  });

  @override
  State<SheikhMemorizationTab> createState() => _SheikhMemorizationTabState();
}

class _SheikhMemorizationTabState extends State<SheikhMemorizationTab> {
  String? _selectedStudentId;
  String? _selectedCourseId;
  String? _selectedRecitationTrackId;

  // Custom Track Recitation State (Hadith, Mutun, Books)
  final TextEditingController _trackFromCtrl = TextEditingController(text: '1');
  final TextEditingController _trackToCtrl = TextEditingController(text: '1');
  final TextEditingController _trackPointsCtrl = TextEditingController(text: '10');
  final TextEditingController _trackNotesCtrl = TextEditingController();
  bool _trackCountsTowardsStatistics = true;

  @override
  void initState() {
    super.initState();
    if (widget.students.isNotEmpty) {
      _selectedStudentId = widget.students.first.id;
    }
  }

  @override
  void dispose() {
    _trackFromCtrl.dispose();
    _trackToCtrl.dispose();
    _trackPointsCtrl.dispose();
    _trackNotesCtrl.dispose();
    super.dispose();
  }

  // صورة الطالب المصغرة للدروب داون
  Widget _buildStudentAvatar(Student s, {double radius = 14}) {
    ImageProvider? provider;
    final url = s.profileImageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        provider = NetworkImage(url);
      } else {
        provider = FileImage(File(url));
      }
    }
    final firstLetter = s.fullName.trim().isNotEmpty
        ? s.fullName.trim().substring(0, 1)
        : 'ط';

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.15),
      backgroundImage: provider,
      child: provider == null
          ? Text(
        firstLetter,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
          color: AppColors.terracottaPrimary,
        ),
      )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    if (widget.students.isEmpty) {
      return Center(
        child: Text(
          'الرجاء تسجيل طلاب في الحلقة أولاً لتفعيل التسميع',
          style: AppTypography.verveSubtitle(context),
        ),
      );
    }

    if (_selectedStudentId == null || !widget.students.any((s) => s.id == _selectedStudentId)) {
      _selectedStudentId = widget.students.first.id;
    }

    final selectedStudent =
        widget.students.where((s) => s.id == _selectedStudentId).firstOrNull ?? widget.students.first;
    final currentHalaqaId = selectedStudent.halaqaId;
    final timingDetection = data.detectSessionTimingMode(
      halaqaId: currentHalaqaId,
      studentId: selectedStudent.id,
    );
    final isCourseTiming = timingDetection['mode'] == 'course';
    final isHalaqaTiming = timingDetection['mode'] == 'normal';
    final timingCourse = timingDetection['course'] as IntensiveCourse?;
    final timingDescription = (timingDetection['reason'] ?? '') as String;

    final todayRecitations = data.getTodayMemorizations(sheikhId: widget.sheikh.id);
    final intensiveCourses = data.getIntensiveCourses(sheikhId: widget.sheikh.id);
    final selectedCourse = intensiveCourses.where((c) => c.id == _selectedCourseId).firstOrNull;
    final recitationTracks =
    data.getRecitationTracks(mosqueId: widget.sheikh.mosqueId, halaqaId: currentHalaqaId);
    final selectedTrack = recitationTracks.where((t) => t.id == _selectedRecitationTrackId).firstOrNull;

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Verve Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تسجيل جلسة تسميع ومنهج',
                      style: AppTypography.verveHeaderTitle(context),
                    ),
                    Text(
                      'جلسة اليوم',
                      style: AppTypography.bodyRegular(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'رصد التسميع اليومي للقرآن الكريم، الأحاديث، والمتون العلمية مع احتساب النقاط التنافسية.',
                  style: AppTypography.verveSubtitle(context),
                ),
                const SizedBox(height: 16),

                // Smart Timing Detection Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCourseTiming
                        ? Colors.amber.withValues(alpha: 0.1)
                        : (isHalaqaTiming
                        ? AppColors.terracottaPrimary.withValues(alpha: 0.08)
                        : Colors.blue.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCourseTiming
                          ? Colors.amber.shade600
                          : (isHalaqaTiming
                          ? AppColors.terracottaPrimary.withValues(alpha: 0.35)
                          : Colors.blue.withValues(alpha: 0.35)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCourseTiming
                            ? Icons.stars_rounded
                            : (isHalaqaTiming ? Icons.mosque_rounded : Icons.schedule_rounded),
                        color: isCourseTiming
                            ? Colors.amber.shade800
                            : (isHalaqaTiming ? AppColors.terracottaPrimary : Colors.blue.shade700),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isCourseTiming
                                      ? 'موعد دورة استثنائية'
                                      : (isHalaqaTiming ? 'موعد جلسة الحلقة الاعتيادية' : 'وقت إضافي مخصص'),
                                  style: AppTypography.titleBold(context, fontSize: 13.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              timingDescription,
                              style: AppTypography.bodyRegular(context, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isCourseTiming && timingCourse != null && _selectedCourseId != timingCourse.id)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedCourseId = timingCourse.id;
                            });
                          },
                          child: Text('تفعيل الدورة', style: AppTypography.buttonText()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Primary Selectors (Responsive Layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    final studentField = DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedStudentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الطالب المسمّع *',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      // كيف يظهر الطالب من برّا (والحقل مسكّر)
                      selectedItemBuilder: (context) {
                        return widget.students.map((s) {
                          return Row(
                            children: [
                              _buildStudentAvatar(s, radius: 14),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s.fullName,
                                  style: AppTypography.titleBold(context, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                      // كيف تظهر عناصر القائمة من جوّا
                      items: widget.students
                          .map((s) => DropdownMenuItem(
                        // ignore: deprecated_member_use
                        value: s.id,
                        child: Row(
                          children: [
                            _buildStudentAvatar(s, radius: 14),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.fullName,
                                style: AppTypography.bodyRegular(context, fontSize: 13.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedStudentId = val),
                    );

                    final trackField = DropdownButtonFormField<String?>(
                      initialValue: _selectedRecitationTrackId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'المادة / المنهج المطلوب تسميعه *',
                        prefixIcon: Icon(Icons.menu_book),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('📖 القرآن الكريم (30 جزءاً)', style: AppTypography.bodyRegular(context), overflow: TextOverflow.ellipsis),
                        ),
                        ...recitationTracks.map((t) => DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text('📚 ${t.title} (${t.totalUnits} ${t.unitLabel})',
                              style: AppTypography.bodyRegular(context), overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedRecitationTrackId = val;
                          if (val != null) {
                            final trk = recitationTracks.where((t) => t.id == val).firstOrNull;
                            if (trk != null) {
                              _trackFromCtrl.text = '1';
                              _trackToCtrl.text = '1';
                              _trackPointsCtrl.text = trk.pointsPerUnit.toString();
                            }
                          }
                        });
                      },
                    );

                    if (isMobile) {
                      return Column(
                        children: [
                          studentField,
                          const SizedBox(height: 12),
                          trackField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: studentField),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: trackField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Course Context Selector
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCourseId,
                  decoration: const InputDecoration(
                    labelText: 'المسار أو الدورة المقامة *',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      // ignore: deprecated_member_use
                      value: null,
                      child: Text('جلسة الحلقة الاعتيادية بالمسجد', style: AppTypography.bodyRegular(context)),
                    ),
                    ...intensiveCourses.map((c) => DropdownMenuItem<String?>(
                      // ignore: deprecated_member_use
                      value: c.id,
                      child: Text(
                        'دورة: ${c.name}${c.countsTowardsQuranProgress ? "" : " (خارج خطة المصحف)"}',
                        style: AppTypography.bodyRegular(context),
                      ),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedCourseId = val),
                ),

                if (selectedCourse != null && !selectedCourse.countsTowardsQuranProgress) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'تنبيه: هذه الدورة استثنائية (تمنح نقاطاً للطالب، ولكن لا تحتسب في شريط تقدم حفظ القرآن الكريم).',
                      style: AppTypography.bodyRegular(context, color: Colors.amber.shade900, fontSize: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Divider(height: 1, thickness: 0.8, color: dividerColor),
                const SizedBox(height: 20),

                // SECTION A: HOLY QURAN
                if (_selectedRecitationTrackId == null)
                  SheikhQuranRecitationInputs(
                    selectedStudent: selectedStudent,
                    sheikh: widget.sheikh,
                    selectedCourseId: _selectedCourseId,
                    onRecitationSaved: () => setState(() {}),
                  )
                else ...[
                  // SECTION B: CUSTOM CURRICULUM TRACK
                  if (selectedTrack != null) ...[
                    Row(
                      children: [
                        Text(
                          'مسار المنهج: ${selectedTrack.title}',
                          style: AppTypography.verveTitle(context),
                        ),
                        const SizedBox(width: 10),
                        UnifiedBadge(
                          label: '${selectedTrack.totalUnits} ${selectedTrack.unitLabel}',
                          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                          textColor: AppColors.goldDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 380;
                        final fromField = TextField(
                          controller: _trackFromCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'من ${selectedTrack.unitLabel} *',
                            prefixIcon: const Icon(Icons.pin),
                            helperText: 'بداية المقطع',
                          ),
                          onChanged: (_) {
                            final from = int.tryParse(_trackFromCtrl.text) ?? 1;
                            final to = int.tryParse(_trackToCtrl.text) ?? from;
                            if (to >= from) {
                              _trackPointsCtrl.text =
                                  ((to - from + 1) * selectedTrack.pointsPerUnit).toString();
                            }
                          },
                        );

                        final toField = TextField(
                          controller: _trackToCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'إلى ${selectedTrack.unitLabel} *',
                            prefixIcon: const Icon(Icons.pin_end),
                            helperText: 'نهاية المقطع (أقصى: ${selectedTrack.totalUnits})',
                          ),
                          onChanged: (_) {
                            final from = int.tryParse(_trackFromCtrl.text) ?? 1;
                            final to = int.tryParse(_trackToCtrl.text) ?? from;
                            if (to >= from) {
                              _trackPointsCtrl.text =
                                  ((to - from + 1) * selectedTrack.pointsPerUnit).toString();
                            }
                          },
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              fromField,
                              const SizedBox(height: 12),
                              toField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: fromField),
                            const SizedBox(width: 12),
                            Expanded(child: toField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _trackPointsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'النقاط المستحقة للطالب *',
                        prefixIcon: Icon(Icons.stars, color: AppTheme.gold),
                        helperText: 'يمكن تعديل النقاط بحرية حسب إتقان الطالب',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _trackNotesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات التسميع والإتقان',
                        hintText: 'مثال: حفظ متقن ومتميز مع فهم المعاني',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Toggle: Count towards general statistics & leaderboard
                    Container(
                      decoration: BoxDecoration(
                        color: _trackCountsTowardsStatistics
                            ? AppColors.terracottaPrimary.withValues(alpha: 0.08)
                            : Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _trackCountsTowardsStatistics
                              ? AppColors.terracottaPrimary.withValues(alpha: 0.3)
                              : Colors.amber.shade400,
                        ),
                      ),
                      child: SwitchListTile(
                        // ignore: deprecated_member_use
                        value: _trackCountsTowardsStatistics,
                        onChanged: (val) => setState(() => _trackCountsTowardsStatistics = val),
                        title: Text(
                          'احتساب هذا التسميع ضمن الإحصائيات العامة للطالب',
                          style: AppTypography.titleBold(context, fontSize: 13),
                        ),
                        subtitle: Text(
                          _trackCountsTowardsStatistics
                              ? 'مفعّل: يُحسب في تقدم المسار وتحديث النقاط والترتيب العام'
                              : 'معطّل: يُحفظ في سجل الطالب فقط ولا يدخل في إحصائيات الترتيب العام',
                          style: AppTypography.verveSubtitle(context),
                        ),
                        activeThumbColor: AppColors.terracottaPrimary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final fromUnit = (int.tryParse(_trackFromCtrl.text.trim()) ?? 1)
                              .clamp(1, selectedTrack.totalUnits);
                          final toUnit = (int.tryParse(_trackToCtrl.text.trim()) ?? fromUnit)
                              .clamp(fromUnit, selectedTrack.totalUnits);
                          final pts = int.tryParse(_trackPointsCtrl.text.trim()) ??
                              ((toUnit - fromUnit + 1) * selectedTrack.pointsPerUnit);

                          data.recordSubjectRecitation(
                            trackId: selectedTrack.id,
                            trackName: selectedTrack.name,
                            studentId: selectedStudent.id,
                            halaqaId: selectedStudent.halaqaId,
                            sheikhId: widget.sheikh.id,
                            fromUnit: fromUnit,
                            toUnit: toUnit,
                            pointsEarned: pts,
                            notes: _trackNotesCtrl.text.trim(),
                            countsTowardsStatistics: _trackCountsTowardsStatistics,
                          );

                          _trackNotesCtrl.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_trackCountsTowardsStatistics
                                  ? 'تم تسجيل تسميع (${selectedTrack.title}) بنجاح ورصد +$pts نقطة! 🎉'
                                  : 'تم حفظ التسميع في السجل كجلسة خاصة.'),
                              backgroundColor: AppTheme.emeraldPrimary,
                            ),
                          );
                          setState(() {});
                        },
                        icon: const Icon(Icons.save),
                        label: Text(
                          'حفظ تسميع ${selectedTrack.title} ورصد النقاط',
                          style: AppTypography.buttonText(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.obsidianEspresso,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 0.8, color: dividerColor),
                const SizedBox(height: 16),

                // Today's Recitations
                SheikhTodayRecitationsCard(
                  todayRecitations: todayRecitations,
                  students: widget.students,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}