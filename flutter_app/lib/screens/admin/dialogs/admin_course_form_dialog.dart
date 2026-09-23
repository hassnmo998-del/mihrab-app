import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../theme/app_theme.dart';

class AdminCourseFormDialog extends StatefulWidget {
  final Mosque mosque;
  final IntensiveCourse? course;
  final List<Sheikh> sheikhs;
  final List<Halaqa> halaqat;
  final List<Student> allStudents;

  const AdminCourseFormDialog({
    super.key,
    required this.mosque,
    this.course,
    required this.sheikhs,
    required this.halaqat,
    required this.allStudents,
  });

  static Future<void> show({
    required BuildContext context,
    required Mosque mosque,
    IntensiveCourse? course,
    required List<Sheikh> sheikhs,
    required List<Halaqa> halaqat,
    required List<Student> allStudents,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AdminCourseFormDialog(
        mosque: mosque,
        course: course,
        sheikhs: sheikhs,
        halaqat: halaqat,
        allStudents: allStudents,
      ),
    );
  }

  static String getDayName(int day) {
    switch (day) {
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      default:
        return '';
    }
  }

  @override
  State<AdminCourseFormDialog> createState() => _AdminCourseFormDialogState();
}

class _AdminCourseFormDialogState extends State<AdminCourseFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late final Set<int> _selectedDays;
  late bool _enrollAll;
  late final Set<String> _selectedStudentIds;
  String _studentFilter = '';
  late bool _countsTowardsQuran;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _descCtrl = TextEditingController(text: c?.description ?? '');
    _startDate = c?.startDate ?? DateTime.now();
    _endDate = c?.endDate ?? DateTime.now().add(const Duration(days: 30));

    _startTime = const TimeOfDay(hour: 16, minute: 0);
    if (c?.startTime != null && c!.startTime!.contains(':')) {
      final parts = c.startTime!.split(':');
      _startTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 16,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    _endTime = const TimeOfDay(hour: 18, minute: 0);
    if (c?.endTime != null && c!.endTime!.contains(':')) {
      final parts = c.endTime!.split(':');
      _endTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 18,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    _selectedDays = c != null ? <int>{...c.daysOfWeek} : <int>{6, 1, 3};
    _enrollAll = c == null ? true : c.studentIds.isEmpty;
    _selectedStudentIds = c == null ? <String>{} : <String>{...c.studentIds};
    _countsTowardsQuran = c?.countsTowardsQuranProgress ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  static String getDayName(int day) {
    switch (day) {
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      default:
        return '';
    }
  }

  void _save(BuildContext context) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final data = context.read<DataService>();
    final sTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final eTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    if (widget.course == null) {
      data.addIntensiveCourse(
        mosqueId: widget.mosque.id,
        name: name,
        description: _descCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        studentIds: _enrollAll ? [] : _selectedStudentIds.toList(),
        daysOfWeek: _selectedDays.toList()..sort(),
        startTime: sTimeStr,
        endTime: eTimeStr,
        countsTowardsQuranProgress: _countsTowardsQuran,
      );
    } else {
      final updated = IntensiveCourse(
        id: widget.course!.id,
        mosqueId: widget.course!.mosqueId,
        name: name,
        description: _descCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        sheikhIds: widget.course!.sheikhIds,
        halaqaIds: widget.course!.halaqaIds,
        studentIds: _enrollAll ? [] : _selectedStudentIds.toList(),
        daysOfWeek: _selectedDays.toList()..sort(),
        startTime: sTimeStr,
        endTime: eTimeStr,
        countsTowardsQuranProgress: _countsTowardsQuran,
        createdAt: widget.course!.createdAt,
      );
      data.updateIntensiveCourse(updated);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.course != null;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.workspace_premium, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEdit ? 'تعديل الدورة الاستثنائية' : 'إضافة دورة قرآنية استثنائية',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الدورة *',
                  hintText: 'مثال: مخيم الهمة القرآني، معسكر تثبيت الأجزاء الخمسة',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'وصف الدورة وأهدافها'),
              ),
              const SizedBox(height: 14),

              // Dates (Start and End)
              const Text('فترة إقامة الدورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final isNarrow = MediaQuery.sizeOf(context).width < 420;
                  final startDateBtn = OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text('من: ${_startDate.year}/${_startDate.month}/${_startDate.day}', style: const TextStyle(fontSize: 11.5)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  );
                  final endDateBtn = OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 14),
                    label: Text('إلى: ${_endDate.year}/${_endDate.month}/${_endDate.day}', style: const TextStyle(fontSize: 11.5)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        startDateBtn,
                        const SizedBox(height: 6),
                        endDateBtn,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: startDateBtn),
                      const SizedBox(width: 8),
                      Expanded(child: endDateBtn),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Scheduled Hours
              const Text('أوقات التسميع اليومية المقررة في الدورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final isNarrow = MediaQuery.sizeOf(context).width < 420;
                  final startTimeBtn = OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 14),
                    label: Text('البدء: ${_startTime.format(context)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  );
                  final endTimeBtn = OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_filled, size: 14),
                    label: Text('الانتهاء: ${_endTime.format(context)}', style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _endTime);
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        startTimeBtn,
                        const SizedBox(height: 6),
                        endTimeBtn,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: startTimeBtn),
                      const SizedBox(width: 8),
                      Expanded(child: endTimeBtn),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Days of Week
              const Text('أيام انعقاد جلسات الدورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [6, 7, 1, 2, 3, 4, 5].map((d) {
                  final isSelected = _selectedDays.contains(d);
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return FilterChip(
                    label: Text(
                      getDayName(d),
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: primaryColor,
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDays.add(d);
                        } else if (_selectedDays.length > 1) {
                          _selectedDays.remove(d);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Enrolled Students
              const Text('الطلاب المشاركون في الدورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      'جميع طلاب المسجد والحلقات',
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        fontWeight: _enrollAll ? FontWeight.bold : FontWeight.w600,
                        color: _enrollAll ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    selected: _enrollAll,
                    selectedColor: primaryColor,
                    onSelected: (val) => setState(() => _enrollAll = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'تحديد طلاب معينين (${_selectedStudentIds.length})',
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        fontWeight: !_enrollAll ? FontWeight.bold : FontWeight.w600,
                        color: !_enrollAll ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                    selected: !_enrollAll,
                    selectedColor: primaryColor,
                    onSelected: (val) => setState(() => _enrollAll = false),
                  ),
                ],
              ),
              if (!_enrollAll) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'بحث باسم الطالب...',
                                prefixIcon: Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (v) => setState(() => _studentFilter = v.trim().toLowerCase()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedStudentIds.length == widget.allStudents.length) {
                                  _selectedStudentIds.clear();
                                } else {
                                  _selectedStudentIds.addAll(widget.allStudents.map((s) => s.id));
                                }
                              });
                            },
                            child: Text(_selectedStudentIds.length == widget.allStudents.length ? 'إلغاء الكل' : 'تحديد الكل', style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView(
                          shrinkWrap: true,
                          children: widget.allStudents
                              .where((s) => _studentFilter.isEmpty || s.fullName.toLowerCase().contains(_studentFilter))
                              .map((s) {
                                final checked = _selectedStudentIds.contains(s.id);
                                final halaqa = widget.halaqat.firstWhere((h) => h.id == s.halaqaId, orElse: () => Halaqa(id: '', mosqueId: '', name: ''));
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(s.fullName, style: const TextStyle(fontSize: 12.5)),
                                  subtitle: Text(halaqa.name.isNotEmpty ? 'حلقة: ${halaqa.name}' : '', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  value: checked,
                                  activeColor: primaryColor,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedStudentIds.add(s.id);
                                      } else {
                                        _selectedStudentIds.remove(s.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Counts Towards Quran
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('احتساب التسميع ضمن الـ 30 جزء الرسمية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('إذا عُطّل، يحصل الطالب على نقاط تنافسية فقط دون زيادة عدّاد أجزائه الرسمية', style: TextStyle(fontSize: 11)),
                value: _countsTowardsQuran,
                activeThumbColor: primaryColor,
                onChanged: (val) => setState(() => _countsTowardsQuran = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
          onPressed: () => _save(context),
          child: Text(isEdit ? 'حفظ التعديلات' : 'إنشاء الدورة'),
        ),
      ],
    );
  }
}
