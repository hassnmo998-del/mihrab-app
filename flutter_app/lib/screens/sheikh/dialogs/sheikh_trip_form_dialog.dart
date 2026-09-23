import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../core/theme/app_theme.dart';

void showSheikhTripFormDialog(
  BuildContext context,
  DataService data,
  Sheikh currentSheikh,
  List<Student> students,
  List<Halaqa> halaqat,
  List<Sheikh> allSheikhs, {
  Trip? trip,
  VoidCallback? onSaved,
}) {
  final titleCtrl = TextEditingController(text: trip?.title ?? '');
  final destinationCtrl = TextEditingController(text: trip?.destination ?? '');
  DateTime tripDate = trip?.tripDate ?? DateTime.now().add(const Duration(days: 7));
  final meetingTimeCtrl = TextEditingController(text: trip?.meetingTime ?? 'الساعة 8:00 صباحاً أمام المسجد');
  final requirementsCtrl = TextEditingController(text: trip?.requiredItems ?? 'قبعة شمس، وجبة خفيفة، مطرة ماء');
  
  // Supervisor management - ensure safe, distinct list containing currentSheikh
  final Map<String, Sheikh> sheikhMap = {};
  sheikhMap[currentSheikh.id] = currentSheikh;
  for (final s in allSheikhs) {
    sheikhMap[s.id] = s;
  }
  final effectiveSheikhs = sheikhMap.values.toList();

  String? selectedLeaderId;
  if (trip?.leaderName != null && effectiveSheikhs.any((s) => s.fullName == trip!.leaderName)) {
    selectedLeaderId = effectiveSheikhs.firstWhere((s) => s.fullName == trip!.leaderName).id;
  } else if (sheikhMap.containsKey(currentSheikh.id)) {
    selectedLeaderId = currentSheikh.id;
  } else if (effectiveSheikhs.isNotEmpty) {
    selectedLeaderId = effectiveSheikhs.first.id;
  }
  
  final leaderPhoneCtrl = TextEditingController(
    text: trip?.leaderPhone ?? (selectedLeaderId != null ? sheikhMap[selectedLeaderId]?.phone : null) ?? currentSheikh.phone ?? '',
  );

  // Target management
  String targetMode = (trip?.targetHalaqaIds.isNotEmpty ?? false) ? 'halaqat' : 'students';
  final Set<String> targetedStudentIds = Set.from(trip?.targetStudentIds ?? []);
  final Set<String> targetedHalaqaIds = Set.from(trip?.targetHalaqaIds ?? []);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: AppColors.emeraldPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip == null ? 'تنظيم رحلة أو نشاط جديد' : 'تعديل بيانات الرحلة',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الرحلة أو النشاط *',
                      hintText: 'مثال: رحلة المسجد الترفيهية لمدينة الألعاب',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destinationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الوجهة / المكان المقصود *',
                      hintText: 'مثال: حديقة الملك سلمان',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today, color: AppColors.emeraldPrimary),
                    title: const Text('تاريخ الرحلة *'),
                    subtitle: Text(DateFormat('yyyy/MM/dd (EEEE)', 'ar').format(tripDate)),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tripDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => tripDate = picked);
                      },
                      child: const Text('تغيير'),
                    ),
                  ),
                  TextField(
                    controller: meetingTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'وقت ومكان التجمع *',
                      hintText: 'مثال: 7:30 صباحاً بساحة المسجد',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: requirementsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ما يلزم إحضاره مع الطالب 🎒 *',
                      hintText: 'قبعة شمسية، وجبة خفيفة، دفتر ملاحظات وقلم، مطرة ماء',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Supervisor Selection
                  Builder(
                    builder: (context) {
                      final isNarrow = MediaQuery.sizeOf(context).width < 420;
                      final leaderField = DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: selectedLeaderId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'المشرف المسؤول *'),
                        items: effectiveSheikhs.map((s) => DropdownMenuItem(
                          // ignore: deprecated_member_use
                          value: s.id,
                          child: Text(s.fullName, style: AppTypography.bodyRegular(context, fontSize: 13)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final sh = sheikhMap[val] ?? currentSheikh;
                            setDialogState(() {
                              selectedLeaderId = val;
                              leaderPhoneCtrl.text = sh.phone ?? '';
                            });
                          }
                        },
                      );
                      final phoneField = TextField(
                        controller: leaderPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'هاتف التواصل'),
                        readOnly: true, // Auto-filled from sheikh
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            leaderField,
                            const SizedBox(height: 8),
                            phoneField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: leaderField),
                          const SizedBox(width: 8),
                          Expanded(child: phoneField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Target Mode Toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'students', label: Text('طلاب محددين'), icon: Icon(Icons.person_outline)),
                      ButtonSegment(value: 'halaqat', label: Text('حلقات كاملة'), icon: Icon(Icons.groups_outlined)),
                    ],
                    selected: {targetMode},
                    onSelectionChanged: (newSelection) {
                      setDialogState(() => targetMode = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 14),

                  if (targetMode == 'students') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الطلاب المستهدفون (${targetedStudentIds.length} من ${students.length})',
                          style: AppTypography.titleBold(context, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              if (targetedStudentIds.length == students.length) {
                                targetedStudentIds.clear();
                              } else {
                                targetedStudentIds.addAll(students.map((s) => s.id));
                              }
                            });
                          },
                          child: Text(targetedStudentIds.length == students.length ? 'إلغاء الكل' : 'تحديد الكل'),
                        ),
                      ],
                    ),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: students.length,
                        itemBuilder: (ctx, i) {
                          final st = students[i];
                          final isSelected = targetedStudentIds.contains(st.id);
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            title: Text(st.fullName, style: AppTypography.bodyRegular(context)),
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  targetedStudentIds.add(st.id);
                                } else {
                                  targetedStudentIds.remove(st.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الحلقات المستهدفة (${targetedHalaqaIds.length} من ${halaqat.length})',
                          style: AppTypography.titleBold(context, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              if (targetedHalaqaIds.length == halaqat.length) {
                                targetedHalaqaIds.clear();
                              } else {
                                targetedHalaqaIds.addAll(halaqat.map((h) => h.id));
                              }
                            });
                          },
                          child: Text(targetedHalaqaIds.length == halaqat.length ? 'إلغاء الكل' : 'تحديد الكل'),
                        ),
                      ],
                    ),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: halaqat.length,
                        itemBuilder: (ctx, i) {
                          final h = halaqat[i];
                          final isSelected = targetedHalaqaIds.contains(h.id);
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            title: Text(h.name, style: AppTypography.bodyRegular(context)),
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  targetedHalaqaIds.add(h.id);
                                } else {
                                  targetedHalaqaIds.remove(h.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: AppTypography.buttonText(color: AppColors.terracottaPrimary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || destinationCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى كتابة عنوان ووجهة الرحلة')),
                  );
                  return;
                }
                
                final leader = allSheikhs.firstWhere((s) => s.id == selectedLeaderId, orElse: () => currentSheikh);
                final description = 'المشرف: ${leader.fullName} - هاتف: ${leader.phone ?? ""}';

                if (trip == null) {
                  data.addTrip(
                    mosqueId: currentSheikh.mosqueId,
                    title: titleCtrl.text.trim(),
                    destination: destinationCtrl.text.trim(),
                    tripDate: tripDate,
                    meetingTime: meetingTimeCtrl.text.trim(),
                    deadlineDate: tripDate, // Removed from UI, default to trip date
                    targetHalaqaIds: targetMode == 'halaqat' ? targetedHalaqaIds.toList() : [],
                    targetStudentIds: targetMode == 'students' ? targetedStudentIds.toList() : [],
                    requiredItems: requirementsCtrl.text.trim(),
                    description: description,
                  );
                } else {
                  data.updateTrip(trip.copyWith(
                    title: titleCtrl.text.trim(),
                    destination: destinationCtrl.text.trim(),
                    tripDate: tripDate,
                    meetingTime: meetingTimeCtrl.text.trim(),
                    deadlineDate: tripDate,
                    targetHalaqaIds: targetMode == 'halaqat' ? targetedHalaqaIds.toList() : [],
                    targetStudentIds: targetMode == 'students' ? targetedStudentIds.toList() : [],
                    requiredItems: requirementsCtrl.text.trim(),
                    description: description,
                  ));
                }
                
                Navigator.pop(ctx);
                onSaved?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(trip == null
                        ? 'تم إنشاء الرحلة بنجاح وإشعار الطلاب المستهدفين! 🚌'
                        : 'تم تعديل بيانات الرحلة بنجاح'),
                    backgroundColor: AppColors.emeraldPrimary,
                  ),
                );
              },
              child: Text(trip == null ? 'إنشاء وحفظ الرحلة' : 'حفظ التعديلات'),
            ),
          ],
        );
      },
    ),
  );
  });
}
