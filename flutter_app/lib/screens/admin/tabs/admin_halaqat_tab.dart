import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';
import '../../../widgets/qr_dialogs.dart';

class AdminHalaqatTab extends StatefulWidget {
  final Mosque mosque;
  final List<Halaqa> halaqat;
  final List<Sheikh> sheikhs;
  final bool isDark;

  const AdminHalaqatTab({
    super.key,
    required this.mosque,
    required this.halaqat,
    required this.sheikhs,
    this.isDark = false,
  });

  @override
  State<AdminHalaqatTab> createState() => _AdminHalaqatTabState();
}

class _AdminHalaqatTabState extends State<AdminHalaqatTab> {
  Widget _buildSheikhAvatar(Sheikh s, {double radius = 13}) {
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
        : 'ش';

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

  void _showAddHalaqaModal(BuildContext context, DataService data) {
    final nameCtrl = TextEditingController();
    final schedCtrl = TextEditingController(text: 'السبت - الإثنين - الأربعاء (عصراً)');
    final ageMinCtrl = TextEditingController(text: '6');
    final ageMaxCtrl = TextEditingController(text: '18');
    String? selectedSheikhId = widget.sheikhs.isNotEmpty ? widget.sheikhs.first.id : null;
    List<int> selectedDays = [6, 1, 3];
    String selectedPrayer = 'عصراً';

    const weekdays = [
      {'day': 6, 'name': 'السبت'},
      {'day': 7, 'name': 'الأحد'},
      {'day': 1, 'name': 'الإثنين'},
      {'day': 2, 'name': 'الثلاثاء'},
      {'day': 3, 'name': 'الأربعاء'},
      {'day': 4, 'name': 'الخميس'},
      {'day': 5, 'name': 'الجمعة'},
    ];

    const prayerOptions = ['فجراً', 'ظهراً', 'عصراً', 'مغرباً', 'عشاءً', 'مخصص'];

    void updateSchedule(void Function(void Function()) setMState) {
      final daysNames = selectedDays.map((d) {
        final found = weekdays.firstWhere((w) => w['day'] == d, orElse: () => {'name': ''});
        return found['name'];
      }).where((s) => (s as String).isNotEmpty).join(' - ');
      setMState(() {
        schedCtrl.text = '$daysNames ($selectedPrayer)'.trim();
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'إنشاء حلقة قرآنية جديدة',
            style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الحلقة *', hintText: 'مثال: حلقة الإمام الشاطبي'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedSheikhId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المحفظ المشرف *',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  selectedItemBuilder: (context) {
                    return widget.sheikhs.map((s) {
                      return Row(
                        children: [
                          _buildSheikhAvatar(s, radius: 13),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.fullName,
                              style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: widget.sheikhs.map((s) => DropdownMenuItem(
                    // ignore: deprecated_member_use
                    value: s.id,
                    child: Row(
                      children: [
                        _buildSheikhAvatar(s, radius: 13),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.fullName, style: GoogleFonts.amiri(fontSize: 14), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  )).toList(),
                  onChanged: (val) => setMState(() => selectedSheikhId = val),
                ),
                const SizedBox(height: 16),
                Text(
                  'أيام انعقاد الحلقة في الأسبوع:',
                  style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: weekdays.map((w) {
                    final d = w['day'] as int;
                    final isSel = selectedDays.contains(d);
                    return FilterChip(
                      label: Text(w['name'] as String),
                      selected: isSel,
                      selectedColor: AppColors.terracottaPrimary,
                      checkmarkColor: Colors.white,
                      labelStyle: GoogleFonts.amiri(
                        fontSize: 13,
                        color: isSel ? Colors.white : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        setMState(() {
                          if (selected) {
                            selectedDays.add(d);
                            selectedDays.sort();
                          } else {
                            selectedDays.remove(d);
                          }
                        });
                        updateSchedule(setMState);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'توقيت الحلقة بالنسبة للصلاة:',
                  style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: prayerOptions.map((p) {
                    final isSel = selectedPrayer == p;
                    return ChoiceChip(
                      label: Text(p),
                      selected: isSel,
                      selectedColor: AppColors.obsidianEspresso,
                      labelStyle: GoogleFonts.amiri(
                        fontSize: 13,
                        color: isSel ? Colors.white : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setMState(() => selectedPrayer = p);
                          updateSchedule(setMState);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: schedCtrl,
                  decoration: const InputDecoration(labelText: 'صيغة المواعيد (قابلة للتعديل الحر)'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'من عمر (سنة)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: ageMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'إلى عمر (سنة)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final newHalaqa = data.addHalaqa(
                  mosqueId: widget.mosque.id,
                  sheikhId: selectedSheikhId,
                  name: name,
                  schedule: schedCtrl.text.trim(),
                  daysOfWeek: selectedDays,
                  ageGroupMin: int.tryParse(ageMinCtrl.text) ?? 6,
                  ageGroupMax: int.tryParse(ageMaxCtrl.text) ?? 18,
                );
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => SectionQrCodeDialog(
                    title: 'رمز اعتماد حلقة (${newHalaqa.name})',
                    subtitle: 'باركود الانضمام المباشر لطلاب وأولياء أمور ${newHalaqa.name}',
                    code: 'HLQ-${newHalaqa.id.length > 6 ? newHalaqa.id.substring(0, 6).toUpperCase() : newHalaqa.id.toUpperCase()}',
                    icon: Icons.menu_book_rounded,
                    primaryColor: AppColors.trackTeal,
                  ),
                );
              },
              child: Text('إنشاء الحلقة', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHalaqaModal(BuildContext context, DataService data, Halaqa halaqa) {
    final nameCtrl = TextEditingController(text: halaqa.name);
    final schedCtrl = TextEditingController(text: halaqa.schedule);
    final ageMinCtrl = TextEditingController(text: halaqa.ageGroupMin.toString());
    final ageMaxCtrl = TextEditingController(text: halaqa.ageGroupMax.toString());
    String? selectedSheikhId = halaqa.sheikhId;
    List<int> selectedDays = List<int>.from(halaqa.daysOfWeek);
    String selectedPrayer = 'عصراً';

    const weekdays = [
      {'day': 6, 'name': 'السبت'},
      {'day': 7, 'name': 'الأحد'},
      {'day': 1, 'name': 'الإثنين'},
      {'day': 2, 'name': 'الثلاثاء'},
      {'day': 3, 'name': 'الأربعاء'},
      {'day': 4, 'name': 'الخميس'},
      {'day': 5, 'name': 'الجمعة'},
    ];

    const prayerOptions = ['فجراً', 'ظهراً', 'عصراً', 'مغرباً', 'عشاءً', 'مخصص'];

    void updateSchedule(void Function(void Function()) setMState) {
      final daysNames = selectedDays.map((d) {
        final found = weekdays.firstWhere((w) => w['day'] == d, orElse: () => {'name': ''});
        return found['name'];
      }).where((s) => (s as String).isNotEmpty).join(' - ');
      setMState(() {
        schedCtrl.text = '$daysNames ($selectedPrayer)'.trim();
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعديل الحلقة القرآنية',
            style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحلقة *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedSheikhId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المحفظ المشرف',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  selectedItemBuilder: (context) {
                    return widget.sheikhs.map((s) {
                      return Row(
                        children: [
                          _buildSheikhAvatar(s, radius: 13),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.fullName,
                              style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  items: widget.sheikhs.map((s) => DropdownMenuItem(
                    // ignore: deprecated_member_use
                    value: s.id,
                    child: Row(
                      children: [
                        _buildSheikhAvatar(s, radius: 13),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.fullName, style: GoogleFonts.amiri(fontSize: 14), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setMState(() => selectedSheikhId = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'أيام انعقاد الحلقة في الأسبوع:',
                  style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: weekdays.map((w) {
                    final d = w['day'] as int;
                    final isSel = selectedDays.contains(d);
                    return FilterChip(
                      label: Text(w['name'] as String),
                      selected: isSel,
                      selectedColor: AppColors.terracottaPrimary,
                      checkmarkColor: Colors.white,
                      labelStyle: GoogleFonts.amiri(
                        fontSize: 13,
                        color: isSel ? Colors.white : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        setMState(() {
                          if (selected) {
                            selectedDays.add(d);
                            selectedDays.sort();
                          } else {
                            selectedDays.remove(d);
                          }
                        });
                        updateSchedule(setMState);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'توقيت الحلقة بالنسبة للصلاة:',
                  style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: prayerOptions.map((p) {
                    final isSel = selectedPrayer == p;
                    return ChoiceChip(
                      label: Text(p),
                      selected: isSel,
                      selectedColor: AppColors.obsidianEspresso,
                      labelStyle: GoogleFonts.amiri(
                        fontSize: 13,
                        color: isSel ? Colors.white : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setMState(() => selectedPrayer = p);
                          updateSchedule(setMState);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(controller: schedCtrl, decoration: const InputDecoration(labelText: 'مواعيد الجلسات')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'من عمر (سنة)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: ageMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'إلى عمر (سنة)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                data.updateHalaqa(
                  id: halaqa.id,
                  name: name,
                  sheikhId: selectedSheikhId,
                  schedule: schedCtrl.text.trim(),
                  daysOfWeek: selectedDays,
                  ageGroupMin: int.tryParse(ageMinCtrl.text) ?? halaqa.ageGroupMin,
                  ageGroupMax: int.tryParse(ageMaxCtrl.text) ?? halaqa.ageGroupMax,
                );
                Navigator.pop(ctx);
              },
              child: Text('حفظ التعديلات', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteHalaqa(BuildContext context, DataService data, Halaqa halaqa) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد حذف الحلقة',
          style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        content: Text(
          'هل تريد حذف حلقة "${halaqa.name}"؟ سيتم إلغاء قيد الطلاب التابعين لها.',
          style: GoogleFonts.amiri(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              data.deleteHalaqa(halaqa.id);
              Navigator.pop(ctx);
            },
            child: Text('حذف', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final halaqat = widget.halaqat;
    final sheikhs = widget.sheikhs;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action & Title Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الحلقات القرآنية النموذجية (${halaqat.length})',
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddHalaqaModal(context, data),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'إضافة حلقة جديدة',
                  style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14),
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
        const SizedBox(height: 8),

        // List of Halaqat
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: halaqat.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد حلقات معلنة بالمسجد بعد',
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: halaqat.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 0.8,
                      color: dividerColor,
                    ),
                    itemBuilder: (context, idx) {
              final h = halaqat[idx];
              final s = sheikhs.firstWhere(
                    (sk) => sk.id == h.sheikhId,
                orElse: () => Sheikh(id: '', mosqueId: '', fullName: 'غير معيّن', code: ''),
              );
              final stCount = data.getStudents(halaqaId: h.id).length;
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
                      style: GoogleFonts.amiri(
                        fontSize: isNarrow ? 20 : 26,
                        fontWeight: FontWeight.normal,
                        color: isDark ? Colors.white30 : AppColors.terracottaPrimary.withValues(alpha: 0.65),
                        height: 1,
                      ),
                    ),
                  );

                  final nameWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.name,
                        style: GoogleFonts.amiri(
                          fontSize: isNarrow ? 17 : 19,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ProfileImagePicker(
                            radius: 12,
                            isEditable: false,
                            initialImageUrl: s.profileImageUrl,
                            fallbackName: s.fullName,
                            onImageChanged: (_) {},
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'المحفظ: ${s.fullName}',
                              style: GoogleFonts.amiri(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  final detailsWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isNarrow)
                        Text(
                          h.schedule,
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                          ),
                        ),
                      if (!isNarrow) const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (isNarrow && h.schedule.isNotEmpty)
                            UnifiedBadge(
                              label: h.schedule,
                              backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              textColor: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                            ),
                          UnifiedBadge(
                            label: 'الفئة: ${h.ageGroupMin}-${h.ageGroupMax} سنة',
                            backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                            textColor: AppColors.terracottaPrimary,
                          ),
                          UnifiedBadge(
                            label: '$stCount طلاب مسجلين',
                            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                            textColor: AppColors.goldDark,
                          ),
                        ],
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
                        tooltip: 'تعديل الحلقة',
                        icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 19),
                        onPressed: () => _showEditHalaqaModal(context, data, h),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'حذف الحلقة',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
                        onPressed: () => _confirmDeleteHalaqa(context, data, h),
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
                              Expanded(child: nameWidget),
                              actionsWidget,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 42),
                            child: detailsWidget,
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        serialWidget,
                        const SizedBox(width: 8),
                        Expanded(flex: 4, child: nameWidget),
                        Expanded(flex: 3, child: detailsWidget),
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