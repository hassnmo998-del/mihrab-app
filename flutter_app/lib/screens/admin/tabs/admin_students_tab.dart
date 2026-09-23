import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';
import '../../../widgets/manual_points_dialog.dart';
import '../../../widgets/printable_badge_dialog.dart';

class AdminStudentsTab extends StatefulWidget {
  final Mosque mosque;
  final List<Student> students;
  final List<Halaqa> halaqat;
  final bool isDark;

  const AdminStudentsTab({
    super.key,
    required this.mosque,
    required this.students,
    required this.halaqat,
    this.isDark = false,
  });

  @override
  State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<AdminStudentsTab> {
  String _studentSearchQuery = '';
  String _selectedHalaqaFilter = 'all';
  String _sortBy = 'name_asc';

  void _showAddStudentModal(BuildContext context, DataService data) {
    if (widget.halaqat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إنشاء حلقة قرآنية أولاً لتسجيل الطالب فيها')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final birthDateCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final welcomePointsCtrl = TextEditingController(text: '0');
    String selectedHalaqaId = widget.halaqat.first.id;
    File? pickedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تسجيل طالب جديد في حلقة بالمسجد',
            style: AppTypography.dialogTitle(context),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                // مكوّن اختيار الصورة الشخصية
                ProfileImagePicker(
                  selectedImageFile: pickedImage,
                  fallbackName: nameCtrl.text,
                  radius: 44,
                  onImageChanged: (file) => setMState(() => pickedImage = file),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الثلاثي للطالب *'),
                  onChanged: (_) => setMState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم هاتف التواصل (ولي الأمر) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: birthDateCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'عمر الطالب (بالسنوات)',
                    hintText: 'مثال: 12',
                    prefixIcon: Icon(Icons.cake_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedHalaqaId,
                  decoration: const InputDecoration(labelText: 'الحلقة القرآنية *'),
                  items: widget.halaqat
                      .map((h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, style: AppTypography.bodyRegular(context)),
                  ))
                      .toList(),
                  onChanged: (val) => setMState(() => selectedHalaqaId = val ?? selectedHalaqaId),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: welcomePointsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نقاط الانضمام والترحيب (تخصيص يدوي)',
                    hintText: '0 أو 50 نقطة مثلاً',
                    prefixIcon: Icon(Icons.star, color: AppTheme.gold),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات وتوجيهات'),
                ),
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
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الطالب ورقم الهاتف')),
                  );
                  return;
                }
                final pts = int.tryParse(welcomePointsCtrl.text.trim()) ?? 0;
                final bDate = birthDateCtrl.text.trim().isEmpty ? null : birthDateCtrl.text.trim();
                final newStudent = data.addStudent(
                  mosqueId: widget.mosque.id,
                  halaqaId: selectedHalaqaId,
                  fullName: name,
                  gender: widget.mosque.gender,
                  phone: phone,
                  birthDate: bDate,
                  notes: notesCtrl.text.trim(),
                  welcomePoints: pts,
                  profileImageUrl: pickedImage?.path,
                );
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => PrintableBadgeDialog(
                    title: 'بطاقة الطالب المعتمد والباركود',
                    name: newStudent.fullName,
                    roleLabel: 'طالب حلقة',
                    mosqueName: widget.mosque.name,
                    code: newStudent.code,
                    profileImageUrl: newStudent.profileImageUrl,
                  ),
                );
              },
              child: Text('تسجيل الطالب', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentModal(BuildContext context, DataService data, Student student) {
    final nameCtrl = TextEditingController(text: student.fullName);
    final phoneCtrl = TextEditingController(text: student.phone);
    final birthDateCtrl = TextEditingController(text: student.birthDate ?? '');
    final notesCtrl = TextEditingController(text: student.notes ?? '');
    String selectedHalaqaId = student.halaqaId;
    File? pickedImage;
    String? currentImageUrl = student.profileImageUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعديل ونقل الطالب',
            style: AppTypography.dialogTitle(context),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                ProfileImagePicker(
                  selectedImageFile: pickedImage,
                  initialImageUrl: currentImageUrl,
                  fallbackName: nameCtrl.text,
                  radius: 44,
                  onImageChanged: (file) {
                    setMState(() {
                      pickedImage = file;
                      if (file == null) currentImageUrl = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل للطالب *'),
                  onChanged: (_) => setMState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم هاتف التواصل *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: birthDateCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'عمر الطالب (بالسنوات)',
                    hintText: 'مثال: 12',
                    prefixIcon: Icon(Icons.cake_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: widget.halaqat.any((h) => h.id == selectedHalaqaId)
                      ? selectedHalaqaId
                      : (widget.halaqat.isNotEmpty ? widget.halaqat.first.id : null),
                  decoration: const InputDecoration(labelText: 'الحلقة المسجل بها (النقل)'),
                  items: widget.halaqat
                      .map((h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, style: AppTypography.bodyRegular(context)),
                  ))
                      .toList(),
                  onChanged: (val) => setMState(() => selectedHalaqaId = val ?? selectedHalaqaId),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات')),
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
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الطالب ورقم الهاتف')),
                  );
                  return;
                }
                final finalPath = pickedImage != null ? pickedImage!.path : currentImageUrl;
                final bDate = birthDateCtrl.text.trim().isEmpty ? null : birthDateCtrl.text.trim();
                data.updateStudent(
                  studentId: student.id,
                  fullName: name,
                  halaqaId: selectedHalaqaId,
                  phone: phone,
                  birthDate: bDate,
                  notes: notesCtrl.text.trim(),
                  profileImageUrl: finalPath,
                );
                Navigator.pop(ctx);
              },
              child: Text('حفظ التعديلات', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStudent(BuildContext context, DataService data, Student student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد حذف الطالب',
          style: AppTypography.dialogTitle(context),
        ),
        content: Text(
          'هل تريد حذف سجل الطالب "${student.fullName}" نهائياً من المنظومة؟',
          style: AppTypography.verveSubtitle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.buttonText(color: AppColors.terracottaPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              data.deleteStudent(student.id);
              Navigator.pop(ctx);
            },
            child: Text('حذف', style: AppTypography.buttonText()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final halaqat = widget.halaqat;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    var filtered = widget.students;
    if (_selectedHalaqaFilter != 'all') {
      filtered = filtered.where((s) => s.halaqaId == _selectedHalaqaFilter).toList();
    }
    if (_studentSearchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
      s.fullName.contains(_studentSearchQuery) ||
          s.code.contains(_studentSearchQuery.toUpperCase()))
          .toList();
    }

    filtered = List<Student>.from(filtered);
    switch (_sortBy) {
      case 'name_asc':
        filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'points_desc':
        filtered.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
        break;
      case 'progress_desc':
        filtered.sort((a, b) {
          final countA = data.getStudentCompletedAjzaCount(a.id);
          final countB = data.getStudentCompletedAjzaCount(b.id);
          return countB.compareTo(countA);
        });
        break;
      case 'code_asc':
        filtered.sort((a, b) => a.code.compareTo(b.code));
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'قائمة طلاب حلقات المسجد (${widget.students.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddStudentModal(context, data),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(
                  'تسجيل طالب جديد',
                  style: AppTypography.buttonText(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Search & Filter Row
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final searchField = TextField(
              onChanged: (v) => setState(() => _studentSearchQuery = v.trim()),
              decoration: const InputDecoration(
                hintText: 'بحث باسم الطالب أو الكود المعتمد...',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
            );

            final halaqaFilter = DropdownButtonFormField<String>(
              initialValue: _selectedHalaqaFilter,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                labelText: 'تصفية حسب الحلقة',
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('جميع الحلقات', style: AppTypography.bodyRegular(context)),
                ),
                ...halaqat.map((h) => DropdownMenuItem(
                  value: h.id,
                  child: Text(
                    h.name,
                    style: AppTypography.bodyRegular(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
              onChanged: (val) => setState(() => _selectedHalaqaFilter = val ?? 'all'),
            );

            final sortFilter = DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                labelText: 'ترتيب حسب',
              ),
              items: [
                DropdownMenuItem(value: 'name_asc', child: Text('الاسم (أ-ي)', style: AppTypography.bodyRegular(context))),
                DropdownMenuItem(value: 'points_desc', child: Text('النقاط (الأكثر)', style: AppTypography.bodyRegular(context))),
                DropdownMenuItem(value: 'progress_desc', child: Text('الإتقان (الأكثر أجزاءً)', style: AppTypography.bodyRegular(context))),
                DropdownMenuItem(value: 'code_asc', child: Text('الكود المعتمد', style: AppTypography.bodyRegular(context))),
              ],
              onChanged: (val) => setState(() => _sortBy = val ?? 'name_asc'),
            );

            if (isNarrow) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: halaqaFilter),
                      const SizedBox(width: 8),
                      Expanded(child: sortFilter),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: halaqaFilter),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: sortFilter),
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // Students List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لم يتم العثور على طلاب مطابقين للمعايير',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final st = filtered[idx];
              final h = halaqat.firstWhere(
                    (ha) => ha.id == st.halaqaId,
                orElse: () => Halaqa(id: '', mosqueId: '', name: 'حلقة غير معينة'),
              );
              final completedAjza = data.getStudentCompletedAjzaCount(st.id);
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
                    initialImageUrl: st.profileImageUrl,
                    fallbackName: st.fullName,
                    onImageChanged: (_) {},
                  );

                  final nameWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st.fullName,
                        style: AppTypography.verveTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الحلقة: ${h.name}${st.phone.isNotEmpty ? " • هاتف: ${st.phone}" : ""}',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  );

                  final badgesWidget = Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      UnifiedBadge(
                        label: 'كود: ${st.code}',
                        backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                        textColor: AppColors.terracottaPrimary,
                      ),
                      UnifiedBadge(
                        label: '${st.totalPoints} نقطة',
                        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                        textColor: AppColors.goldDark,
                      ),
                      UnifiedBadge(
                        label: '$completedAjza / 30 جزء',
                        backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        textColor: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                      ),
                    ],
                  );

                  final actionsWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'وضع نقاط يدوي (إضافة / خصم)',
                        icon: Icon(Icons.exposure, color: AppColors.goldDark, size: 19),
                        onPressed: () => showManualPointsDialog(
                          context: context,
                          student: st,
                          actorName: 'إدارة ${widget.mosque.name}',
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'تعديل ونقل الطالب بين الحلقات',
                        icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 19),
                        onPressed: () => _showEditStudentModal(context, data, st),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'بطاقة الطالب الرقمية QR',
                        icon: Icon(Icons.qr_code, color: AppColors.terracottaPrimary, size: 19),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PrintableBadgeDialog(
                              title: 'بطاقة الطالب الرسمية',
                              name: st.fullName,
                              roleLabel: st.gender == 'female' ? 'طالبة في الحلقة' : 'طالب في الحلقة',
                              mosqueName: widget.mosque.name,
                              code: st.code,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'حذف الطالب',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
                        onPressed: () => _confirmDeleteStudent(context, data, st),
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
                              actionsWidget,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 42),
                            child: badgesWidget,
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
                        Expanded(flex: 3, child: nameWidget),
                        Expanded(flex: 4, child: badgesWidget),
                        actionsWidget,
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