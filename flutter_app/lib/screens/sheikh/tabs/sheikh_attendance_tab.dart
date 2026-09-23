import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class SheikhAttendanceTab extends StatefulWidget {
  final Sheikh sheikh;
  final List<Student> students;
  final List<Halaqa> halaqat;
  final bool isDark;

  const SheikhAttendanceTab({
    super.key,
    required this.sheikh,
    required this.students,
    required this.halaqat,
    this.isDark = false,
  });

  @override
  State<SheikhAttendanceTab> createState() => _SheikhAttendanceTabState();
}

class _SheikhAttendanceTabState extends State<SheikhAttendanceTab> {
  DateTime _attendanceDate = DateTime.now();
  bool _enableAttendancePoints = false;
  int _presentPoints = 5;
  int _latePoints = 2;
  int _absentPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadPointsSettings();
  }

  Future<void> _loadPointsSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sheikhId = widget.sheikh.id;
      if (mounted) {
        setState(() {
          _enableAttendancePoints = prefs.getBool('att_points_enabled_$sheikhId') ?? false;
          _presentPoints = prefs.getInt('att_points_present_$sheikhId') ?? widget.sheikh.defaultAttendancePoints;
          _latePoints = prefs.getInt('att_points_late_$sheikhId') ?? 2;
          _absentPoints = prefs.getInt('att_points_absent_$sheikhId') ?? 0;
        });
      }
    } catch (_) {}
  }

  void _showAttendancePointsDialog(BuildContext context, DataService data) {
    bool tempEnable = _enableAttendancePoints;
    final presentCtrl = TextEditingController(text: _presentPoints.toString());
    final lateCtrl = TextEditingController(text: _latePoints.toString());
    final absentCtrl = TextEditingController(text: _absentPoints.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'إعدادات نقاط الحضور والغياب (اختياري)',
            style: AppTypography.dialogTitle(context),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'احتساب نقاط الحضور تلقائياً',
                    style: AppTypography.titleBold(context, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    'عند الإيقاف، لا يتم منح نقاط، ويسجل الحضور والغياب فقط',
                    style: AppTypography.verveSubtitle(context),
                  ),
                  value: tempEnable,
                  activeThumbColor: AppColors.terracottaPrimary,
                  onChanged: (v) => setMState(() => tempEnable = v),
                ),
                if (tempEnable) ...[
                  const Divider(),
                  TextField(
                    controller: presentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نقاط الحاضر',
                      suffixText: 'نقطة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نقاط المتأخر',
                      suffixText: 'نقطة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: absentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نقاط الغائب (عادة صفر)',
                      suffixText: 'نقطة',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: AppTypography.buttonText(color: AppColors.terracottaPrimary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                final newEnable = tempEnable;
                final newPresent = int.tryParse(presentCtrl.text) ?? 5;
                final newLate = int.tryParse(lateCtrl.text) ?? 2;
                final newAbsent = int.tryParse(absentCtrl.text) ?? 0;

                setState(() {
                  _enableAttendancePoints = newEnable;
                  _presentPoints = newPresent;
                  _latePoints = newLate;
                  _absentPoints = newAbsent;
                });

                SharedPreferences.getInstance().then((prefs) {
                  final sheikhId = widget.sheikh.id;
                  prefs.setBool('att_points_enabled_$sheikhId', newEnable);
                  prefs.setInt('att_points_present_$sheikhId', newPresent);
                  prefs.setInt('att_points_late_$sheikhId', newLate);
                  prefs.setInt('att_points_absent_$sheikhId', newAbsent);
                }).catchError((_) {});

                data.updateSheikh(
                  sheikhId: widget.sheikh.id,
                  fullName: widget.sheikh.fullName,
                  phone: widget.sheikh.phone,
                  profileImageUrl: widget.sheikh.profileImageUrl,
                  defaultAttendancePoints: newPresent,
                );

                Navigator.pop(ctx);
              },
              child: Text('حفظ', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
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
          'لا يوجد طلاب مسجلون في حلقاتك حالياً. يمكنك تسجيل أول طالب من تبويب (طلاب الحلقة).',
          style: AppTypography.verveSubtitle(context),
          textAlign: TextAlign.center,
        ),
      );
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    final displayDateStr = DateFormat('yyyy/MM/dd').format(_attendanceDate);
    final activeHalaqa = widget.halaqat.firstOrNull;
    final isToday = _attendanceDate.year == DateTime.now().year &&
        _attendanceDate.month == DateTime.now().month &&
        _attendanceDate.day == DateTime.now().day;
    final isScheduledToday = activeHalaqa != null && activeHalaqa.isScheduledToday();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verve Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رصد الحضور اليومي ($displayDateStr)',
                    style: AppTypography.verveHeaderTitle(context),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UnifiedBadge(
                          label: isScheduledToday
                              ? 'جلسة اليوم مجدولة رسمياً (${activeHalaqa.formattedDays})'
                              : 'جلسة إضافية (أيام الحلقة: ${activeHalaqa?.formattedDays ?? "غير محدد"})',
                          backgroundColor: isScheduledToday
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.12),
                          textColor: isScheduledToday ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => _showAttendancePointsDialog(context, data),
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text(
                      _enableAttendancePoints ? 'نقاط الحضور: مفعل (+$_presentPoints)' : 'نقاط الحضور: اختياري',
                      style: AppTypography.bodyRegular(context, fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _attendanceDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setState(() => _attendanceDate = d);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      'تغيير التاريخ',
                      style: AppTypography.bodyRegular(context, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimal Attendance List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: widget.students.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا يوجد طلاب مسجلون في هذه الحلقة بعد',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: widget.students.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final student = widget.students[idx];
              final existingAtt = data
                  .getAttendanceForDate(student.halaqaId, dateStr)
                  .where((a) => a.studentId == student.id)
                  .firstOrNull;
              final currentStatus = existingAtt?.status;
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final serialWidget = SizedBox(
                    width: isNarrow ? 36 : 52,
                    child: Text(
                      serialNumber,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.verveNumber(context),
                    ),
                  );

                  final avatarWidget = ProfileImagePicker(
                    radius: isNarrow ? 18 : 20,
                    isEditable: false,
                    initialImageUrl: student.profileImageUrl,
                    fallbackName: student.fullName,
                    onImageChanged: (_) {},
                  );

                  final nameWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: AppTypography.verveTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student.totalPoints} نقطة • الحالة: ${currentStatus != null ? (currentStatus == "present" ? "حاضر ✅" : (currentStatus == "late" ? "متأخر ⏳" : "غائب ❌")) : "لم يرصد بعد"}',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  );

                  final buttonsWidget = Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentStatus == 'present'
                              ? AppColors.terracottaPrimary
                              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          foregroundColor: currentStatus == 'present'
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.obsidianEspresso),
                          elevation: 0,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () {
                          data.recordAttendance(
                            studentId: student.id,
                            halaqaId: student.halaqaId,
                            sessionDate: dateStr,
                            status: 'present',
                            pointsEarned: _enableAttendancePoints ? _presentPoints : 0,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_enableAttendancePoints
                                  ? 'تم رصد حضور ${student.fullName} (+$_presentPoints نقطة)'
                                  : 'تم رصد حضور ${student.fullName}'),
                              duration: const Duration(milliseconds: 700),
                            ),
                          );
                        },
                        child: Text(
                          'حاضر',
                          style: AppTypography.buttonText(
                            color: currentStatus == 'present'
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.obsidianEspresso),
                          ),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: currentStatus == 'late'
                              ? AppColors.gold.withValues(alpha: 0.2)
                              : Colors.transparent,
                          side: BorderSide(
                            color: currentStatus == 'late'
                                ? AppColors.gold
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          data.recordAttendance(
                            studentId: student.id,
                            halaqaId: student.halaqaId,
                            sessionDate: dateStr,
                            status: 'late',
                            pointsEarned: _enableAttendancePoints ? _latePoints : 0,
                          );
                        },
                        child: Text(
                          'متأخر',
                          style: AppTypography.bodyRegular(
                            context,
                            color: currentStatus == 'late' ? AppColors.goldDark : null,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: currentStatus == 'absent'
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          side: BorderSide(
                            color: currentStatus == 'absent'
                                ? Colors.redAccent
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          data.recordAttendance(
                            studentId: student.id,
                            halaqaId: student.halaqaId,
                            sessionDate: dateStr,
                            status: 'absent',
                            pointsEarned: _enableAttendancePoints ? _absentPoints : 0,
                          );
                        },
                        child: Text(
                          'غائب',
                          style: AppTypography.bodyRegular(
                            context,
                            color: currentStatus == 'absent' ? Colors.redAccent : null,
                          ),
                        ),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              serialWidget,
                              const SizedBox(width: 6),
                              avatarWidget,
                              const SizedBox(width: 10),
                              Expanded(child: nameWidget),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 42),
                            child: buttonsWidget,
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        serialWidget,
                        const SizedBox(width: 8),
                        avatarWidget,
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: nameWidget),
                        buttonsWidget,
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );
}
}