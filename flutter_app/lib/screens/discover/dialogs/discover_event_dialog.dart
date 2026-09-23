import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/unified_dropdown.dart';
import '../../../services/data_service.dart';
import '../../../widgets/qr_dialogs.dart';
import '../widgets/discover_event_management_view.dart';
import 'lesson_speakers_field.dart';

class DiscoverEventDialog {
  static const List<String> kWeekDays = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  /// خيارات "الفئة المستهدفة" مقيَّدة بفرع الجهة المُعلِنة:
  /// القسم النسائي لا يمكنه إعلان درس للرجال، وفرع الرجال لا يمكنه إعلان درس
  /// للنساء. قبل هذا القيد كان الافتراضي "رجال فقط" لكل من يُعلن، فكان درس
  /// المعلمة يُنشر للرجال ويُحجب عن النساء.
  static List<DropdownMenuItem<String>> _audienceItems(String branch) {
    if (branch == 'female') {
      return const [
        DropdownMenuItem(value: 'female', child: Text('نساء فقط (القسم النسائي)')),
        DropdownMenuItem(value: 'general', child: Text('عائلي (للكل)')),
      ];
    }
    return const [
      DropdownMenuItem(value: 'male', child: Text('رجال فقط (افتراضي)')),
      DropdownMenuItem(value: 'general', child: Text('عائلي (للكل)')),
    ];
  }

  /// يُثبّت القيمة داخل الخيارات المسموحة لفرع المُعلِن.
  static String _coerceAudience(String branch, String audience) {
    if (branch == 'female') {
      return audience == 'general' ? 'general' : 'female';
    }
    return audience == 'general' ? 'general' : 'male';
  }

  static void showManagementModal(BuildContext context, DataService data, ActiveSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.event_note_outlined, color: Theme.of(ctx).colorScheme.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'إدارة دروسي العامة',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: DiscoverEventManagementView(
            session: session,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // --- دالة مساعدة لمسح باركود المسجد أو ربطه بحساب الشيخ ---
  static void _scanAndLinkMosque({
    required BuildContext modalCtx,
    required StateSetter setMState,
    required BuildContext parentContext,
    required DataService data,
    required ActiveSession session,
    required List<Mosque> availableMosques,
    required void Function(String mosqueId) onMosqueSelected,
  }) {
    showDialog(
      context: parentContext,
      builder: (scannerCtx) => UniversalQrScannerDialog(
        title: 'اعتماد المشيخة في جامع آخر',
        hintText: 'امسح باركود المسجد أو أدخل كوده الرسمي (مثال: MSQ-XXXX) لربطه بحسابك كشيخ',
        onCodeScanned: (scannedCode) {
          Navigator.pop(scannerCtx);
          final cleanCode = scannedCode.trim().toUpperCase();
          final foundMosque = data.getMosques().where((m) =>
            m.accessCode.trim().toUpperCase() == cleanCode ||
            m.id.trim().toUpperCase() == cleanCode ||
            m.accessCode.replaceAll('MSQ-', '').toUpperCase() == cleanCode.replaceAll('MSQ-', '')
          ).firstOrNull;

          if (foundMosque == null) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: Text('تعذر العثور على مسجد بهذا الرمز: $scannedCode'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // تسجيل أو التحقق من وجود الشيخ في هذا المسجد
          var sheikhInMosque = data.getSheikhs(mosqueId: foundMosque.id).where((s) =>
            (session.sheikhId != null && s.id == session.sheikhId) ||
            (session.code.isNotEmpty && s.code.trim().toUpperCase() == session.code.trim().toUpperCase()) ||
            (s.fullName.trim() == session.name.trim())
          ).firstOrNull;

          final existingSheikh = session.sheikhId != null ? data.getSheikhById(session.sheikhId!) : null;
          sheikhInMosque ??= data.addSheikh(
            foundMosque.id,
            session.name,
            existingSheikh?.phone ?? '',
            profileImageUrl: existingSheikh?.profileImageUrl ?? session.profileImageUrl,
          );

          setMState(() {
            if (!availableMosques.any((m) => m.id == foundMosque.id)) {
              availableMosques.add(foundMosque);
            }
            onMosqueSelected(foundMosque.id);
          });

          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(
              content: Text('تم ربط واعتماد مشيختك في جامع (${foundMosque.name}) بنجاح وتم اختياره لإعلان درسك!'),
              backgroundColor: Theme.of(parentContext).primaryColor,
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 1. نافذة إعلان درس عام للشيخ (شاشة اكتشف وشاشة الشيخ)
  // =========================================================================
  static void showSheikhAddPublicEventModal(
    BuildContext context,
    DataService data,
    ActiveSession session,
  ) {
    final mosques = data.getVisibleMosques();

    // جلب المساجد التي تم اعتماد هذا الشيخ فيها
    final activeSheikhs = data.getSheikhs().where((s) =>
      (session.sheikhId != null && s.id == session.sheikhId) ||
      (session.code.isNotEmpty && s.code.trim().toUpperCase() == session.code.trim().toUpperCase()) ||
      (s.fullName.trim() == session.name.trim())
    ).toList();

    final Set<String> sheikhMosqueIds = activeSheikhs.map((s) => s.mosqueId).toSet();
    if (session.mosqueId != null && session.mosqueId!.isNotEmpty) {
      sheikhMosqueIds.add(session.mosqueId!);
    }

    final List<Mosque> availableMosques = mosques.where((m) => sheikhMosqueIds.contains(m.id)).toList();
    String selectedMosqueId = availableMosques.isNotEmpty
        ? (availableMosques.any((m) => m.id == session.mosqueId) ? session.mosqueId! : availableMosques.first.id)
        : (session.mosqueId ?? (mosques.isNotEmpty ? mosques.first.id : ''));

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final customTypeCtrl = TextEditingController();
    String eventType = 'lesson';
    String timingType = 'prayer_linked';
    String prayerName = 'maghrib';
    String prayerRelation = 'after';
    String audience = 'male';

    DateTime selectedCustomDate = DateTime.now().add(const Duration(hours: 2));
    TimeOfDay selectedCustomTime = TimeOfDay.fromDateTime(selectedCustomDate);

    bool isQaEnabled = false;
    int maxQuestions = 10;
    bool isRecurring = true;
    final Set<String> selectedWeekDays = {'السبت', 'الاثنين', 'الخميس'};

    // درس فردي أو جماعي: الشيوخ المشاركون مع الشيخ المُعلِن
    bool isGroupLesson = false;
    final Set<String> coSheikhIds = {};

    bool isAnnouncer(Sheikh s) =>
        (session.sheikhId != null && s.id == session.sheikhId) ||
        (session.code.isNotEmpty && s.code.trim().toUpperCase() == session.code.trim().toUpperCase()) ||
        (s.fullName.trim() == session.name.trim());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final primaryColor = Theme.of(ctx).primaryColor;
          final announcerBranch = data.branchOfMosque(selectedMosqueId);
          audience = _coerceAudience(announcerBranch, audience);
          final mosqueSheikhs = data.getSheikhs(mosqueId: selectedMosqueId);
          final announcer = mosqueSheikhs.where(isAnnouncer).firstOrNull;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.record_voice_over_outlined, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'إعلان درس عام (فضيلة الشيخ)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- بطاقة تثبيت هوية الشيخ المحاضر ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : AppColors.goldSoftBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppColors.goldDark, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'المحاضر المعتمد للإعلان:',
                                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  session.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('فضيلة الشيخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.goldDark)),
                          ),
                        ],
                      ),
                    ),

                    LessonSpeakersField(
                      isGroup: isGroupLesson,
                      onFormatChanged: (v) => setMState(() => isGroupLesson = v),
                      sheikhs: mosqueSheikhs,
                      selectedIds: {if (announcer != null) announcer.id, ...coSheikhIds},
                      lockedSheikhId: announcer?.id,
                      onSelectionChanged: (ids) => setMState(() {
                        coSheikhIds
                          ..clear()
                          ..addAll(ids.where((id) => id != announcer?.id));
                      }),
                    ),

                    // --- اختيار المسجد أو مسح باركود مسجد آخر ---
                    if (availableMosques.isNotEmpty) ...[
                      MinisterialDropdownField<String>(
                        label: 'اختر المسجد من قائمة مساجدك المعتمدة',
                        isRequired: true,
                        value: availableMosques.any((m) => m.id == selectedMosqueId)
                            ? selectedMosqueId
                            : availableMosques.first.id,
                        items: availableMosques.map((m) {
                          final addr = (m.address != null && m.address!.trim().isNotEmpty)
                              ? ' - ${m.address!.trim()}'
                              : '';
                          return DropdownMenuItem<String>(
                            value: m.id,
                            child: Text(
                              '${m.name}$addr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setMState(() {
                          selectedMosqueId = v ?? selectedMosqueId;
                        }),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text(
                            '📷 تصوير باركود المسجد أو اعتماد المشيخة من جامع آخر',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: () => _scanAndLinkMosque(
                            modalCtx: ctx,
                            setMState: setMState,
                            parentContext: context,
                            data: data,
                            session: session,
                            availableMosques: availableMosques,
                            onMosqueSelected: (id) => selectedMosqueId = id,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_location_alt_outlined, size: 36, color: AppColors.goldDark),
                            const SizedBox(height: 8),
                            const Text(
                              'لست مسجلاً كشيخ في أي مسجد حتى الآن.\nيمكنك مسح باركود أي جامع لاعتماد مشيختك وإعلان الدرس فيه فوراً:',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                              label: const Text('مسح باركود المسجد الآن'),
                              onPressed: () => _scanAndLinkMosque(
                                modalCtx: ctx,
                                setMState: setMState,
                                parentContext: context,
                                data: data,
                                session: session,
                                availableMosques: availableMosques,
                                onMosqueSelected: (id) => selectedMosqueId = id,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الفعالية أو الدرس *',
                        hintText: 'مثال: شرح رياض الصالحين',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: eventType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع الفعالية'),
                      items: const [
                        DropdownMenuItem(value: 'lesson', child: Text('درس علم وفقه')),
                        DropdownMenuItem(value: 'mawlid', child: Text('مجلس صلاة على النبي ﷺ')),
                        DropdownMenuItem(value: 'tajweed', child: Text('دورة تجويد وإتقان')),
                        DropdownMenuItem(value: 'dhikr_circle', child: Text('مجلس ذكر وتلاوة')),
                        DropdownMenuItem(value: 'general', child: Text('محاضرة عامة')),
                        DropdownMenuItem(value: 'custom', child: Text('مخصص ✍️ (تصنيف جديد)')),
                      ],
                      onChanged: (v) => setMState(() => eventType = v ?? 'lesson'),
                    ),
                    if (eventType == 'custom') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم التصنيف المخصص *',
                          hintText: 'مثال: السيرة النبوية، التفسير، العقيدة...',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: timingType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نظام التوقيت'),
                      items: const [
                        DropdownMenuItem(value: 'prayer_linked', child: Text('مرتبط بمواقيت الصلاة')),
                        DropdownMenuItem(value: 'custom_time', child: Text('تاريخ ووقت مخصص')),
                      ],
                      onChanged: (v) => setMState(() => timingType = v ?? 'prayer_linked'),
                    ),
                    if (timingType == 'prayer_linked') ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isNarrow = MediaQuery.sizeOf(context).width < 420;
                          final relField = DropdownButtonFormField<String>(
                            initialValue: prayerRelation,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'العلاقة'),
                            items: const [
                              DropdownMenuItem(value: 'after', child: Text('مباشرة بعد')),
                              DropdownMenuItem(value: 'between_adhan_iqama', child: Text('بين أذان وإقامة')),
                              DropdownMenuItem(value: 'before', child: Text('قبل أذان')),
                            ],
                            onChanged: (v) => setMState(() => prayerRelation = v ?? 'after'),
                          );
                          final pField = DropdownButtonFormField<String>(
                            initialValue: prayerName,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'الصلاة'),
                            items: const [
                              DropdownMenuItem(value: 'fajr', child: Text('صلاة الفجر')),
                              DropdownMenuItem(value: 'dhuhr', child: Text('صلاة الظهر')),
                              DropdownMenuItem(value: 'asr', child: Text('صلاة العصر')),
                              DropdownMenuItem(value: 'maghrib', child: Text('صلاة المغرب')),
                              DropdownMenuItem(value: 'isha', child: Text('صلاة العشاء')),
                              DropdownMenuItem(value: 'jumua', child: Text('صلاة الجمعة')),
                            ],
                            onChanged: (v) => setMState(() => prayerName = v ?? 'maghrib'),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                relField,
                                const SizedBox(height: 8),
                                pField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: relField),
                              const SizedBox(width: 8),
                              Expanded(child: pField),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedCustomDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setMState(() {
                                    selectedCustomDate = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      selectedCustomTime.hour,
                                      selectedCustomTime.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${selectedCustomDate.year}/${selectedCustomDate.month.toString().padLeft(2, '0')}/${selectedCustomDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedCustomTime,
                                );
                                if (picked != null) {
                                  setMState(() {
                                    selectedCustomTime = picked;
                                    selectedCustomDate = DateTime(
                                      selectedCustomDate.year,
                                      selectedCustomDate.month,
                                      selectedCustomDate.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedCustomTime.format(ctx),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الفئة المستهدفة'),
                      items: _audienceItems(announcerBranch),
                      onChanged: (v) => setMState(
                        () => audience = _coerceAudience(announcerBranch, v ?? audience),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'وصف مختصر أو محاور الدرس'),
                    ),
                    const SizedBox(height: 16),

                    // الدرس المتكرر
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('درس دائم ومتكرر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('يعيد نفسه تلقائياً بعد كل تسجيل حسب الأيام المحددة', style: TextStyle(fontSize: 12)),
                            value: isRecurring,
                            activeThumbColor: primaryColor,
                            onChanged: (v) => setMState(() => isRecurring = v),
                          ),
                          if (isRecurring) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'أيام انعقاد الدرس أسبوعياً:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setMState(() {
                                            if (selectedWeekDays.length == kWeekDays.length) {
                                              selectedWeekDays.clear();
                                            } else {
                                              selectedWeekDays.addAll(kWeekDays);
                                            }
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          selectedWeekDays.length == kWeekDays.length ? 'مسح الكل' : 'كل الأيام',
                                          style: TextStyle(fontSize: 11.5, color: primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: kWeekDays.map((day) {
                                      final isSelected = selectedWeekDays.contains(day);
                                      return FilterChip(
                                        label: Text(day),
                                        selected: isSelected,
                                        selectedColor: primaryColor.withValues(alpha: 0.2),
                                        checkmarkColor: primaryColor,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? primaryColor : null,
                                        ),
                                        onSelected: (sel) {
                                          setMState(() {
                                            if (sel) {
                                              selectedWeekDays.add(day);
                                            } else {
                                              selectedWeekDays.remove(day);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // استقبال الأسئلة
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('تفعيل استقبال الأسئلة المجهولة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('يسمح للجمهور بطرح أسئلة بدون كشف هويتهم', style: TextStyle(fontSize: 12)),
                            value: isQaEnabled,
                            activeThumbColor: primaryColor,
                            onChanged: (v) => setMState(() => isQaEnabled = v),
                          ),
                          if (isQaEnabled)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: TextFormField(
                                initialValue: maxQuestions.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الحد الأقصى للأسئلة المسموحة',
                                  hintText: 'مثال: 10',
                                ),
                                onChanged: (v) => setMState(() => maxQuestions = int.tryParse(v) ?? 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال عنوان الفعالية أو الدرس')),
                    );
                    return;
                  }
                  if (selectedMosqueId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار المسجد أو مسح باركود المسجد لربطه أولاً')),
                    );
                    return;
                  }

                  final customName = eventType == 'custom' ? customTypeCtrl.text.trim() : null;
                  if (eventType == 'custom' && (customName == null || customName.isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم التصنيف المخصص')),
                    );
                    return;
                  }

                  final calculatedDateTime = timingType == 'custom_time'
                      ? DateTime(
                          selectedCustomDate.year,
                          selectedCustomDate.month,
                          selectedCustomDate.day,
                          selectedCustomTime.hour,
                          selectedCustomTime.minute,
                        )
                      : DateTime.now().add(const Duration(hours: 2));

                  // Only co-sheikhs of the mosque chosen now (the mosque may have changed).
                  final coIds = LessonSpeakersField.orderedSelection(
                    data.getSheikhs(mosqueId: selectedMosqueId),
                    coSheikhIds,
                  );
                  if (isGroupLesson && coIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اختر شيخاً آخر على الأقل للدرس الجماعي')),
                    );
                    return;
                  }

                  // التأكد من تسجيل الشيخ في المسجد المختار
                  var sheikhInMosque = data.getSheikhs(mosqueId: selectedMosqueId).where(isAnnouncer).firstOrNull;

                  sheikhInMosque ??= data.addSheikh(
                    selectedMosqueId,
                    session.name,
                    '',
                    profileImageUrl: session.profileImageUrl,
                  );
                  final announcerId = sheikhInMosque.id;
                  final groupIds = isGroupLesson
                      ? [announcerId, ...coIds.where((id) => id != announcerId)]
                      : const <String>[];
                  final organizer = isGroupLesson
                      ? LessonSpeakersField.joinNames([
                          session.name,
                          ...groupIds.skip(1).map((id) => data.getSheikhById(id)?.fullName ?? ''),
                        ])
                      : session.name;

                  try {
                    final newEv = data.addCommunityEvent(
                      mosqueId: selectedMosqueId,
                      title: title,
                      description: descCtrl.text.trim(),
                      eventType: eventType,
                      customTypeName: customName,
                      timingType: timingType,
                      prayerName: timingType == 'prayer_linked' ? prayerName : null,
                      prayerRelation: prayerRelation,
                      targetAudience: audience,
                      eventDateTime: calculatedDateTime,
                      organizerType: 'sheikh',
                      organizerName: organizer,
                      isQaEnabled: isQaEnabled,
                      maxQuestions: maxQuestions,
                      isRecurring: isRecurring,
                      recurringDays: isRecurring && selectedWeekDays.isNotEmpty ? selectedWeekDays.join(', ') : null,
                      sheikhId: announcerId,
                      lessonFormat: isGroupLesson ? 'group' : 'single',
                      sheikhIds: groupIds,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم نشر الدرس العام (${newEv.title}) بنجاح ✨', style: AppTypography.buttonText()),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تعذر نشر الفعالية: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('نشر الدرس العام'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 2. نافذة إعلان درس أو مجلس علم للإدارة (شاشة إدارة المسجد)
  // =========================================================================
  static void showAdminAddPublicEventModal(
    BuildContext context,
    DataService data,
    ActiveSession session,
  ) {
    final mosques = data.getVisibleMosques();
    final selectedMosqueId = session.mosqueId ?? (mosques.isNotEmpty ? mosques.first.id : '');
    final currentMosque = mosques.where((m) => m.id == selectedMosqueId).firstOrNull;

    // جلب قائمة الشيوخ المعتمدين في مسجد الإدارة
    List<Sheikh> mosqueSheikhs = data.getSheikhs(mosqueId: selectedMosqueId);
    String? selectedSheikhId;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final speakerCtrl = TextEditingController();
    final customTypeCtrl = TextEditingController();

    String eventType = 'lesson';
    String timingType = 'prayer_linked';
    String prayerName = 'maghrib';
    String prayerRelation = 'after';
    String audience = 'male';

    DateTime selectedCustomDate = DateTime.now().add(const Duration(hours: 2));
    TimeOfDay selectedCustomTime = TimeOfDay.fromDateTime(selectedCustomDate);

    bool isQaEnabled = false;
    int maxQuestions = 10;
    bool isRecurring = true;
    final Set<String> selectedWeekDays = {'السبت', 'الاثنين', 'الخميس'};

    // درس فردي أو جماعي
    bool isGroupLesson = false;
    final Set<String> groupSheikhIds = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final primaryColor = Theme.of(ctx).primaryColor;
          final announcerBranch = data.branchOfMosque(selectedMosqueId);
          audience = _coerceAudience(announcerBranch, audience);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.campaign_outlined, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'إعلان درس أو مجلس (إدارة المسجد)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة المسجد المضيف الثابتة (مسجد الإدارة)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mosque, color: primaryColor, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'المسجد المضيف (إدارة المسجد):',
                                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currentMosque?.name ?? 'مسجد الإدارة',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'إدارة المسجد',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // المحاضر: شيخ واحد (أو محاضر خارجي) أو عدة شيوخ لدرس جماعي
                    LessonSpeakersField(
                      isGroup: isGroupLesson,
                      onFormatChanged: (v) => setMState(() => isGroupLesson = v),
                      sheikhs: mosqueSheikhs,
                      selectedIds: groupSheikhIds,
                      onSelectionChanged: (ids) => setMState(() {
                        groupSheikhIds
                          ..clear()
                          ..addAll(ids);
                      }),
                      singleChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String?>(
                            key: ValueKey('admin_sheikh_select_$selectedSheikhId'),
                            initialValue: mosqueSheikhs.any((s) => s.id == selectedSheikhId) ? selectedSheikhId : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'المحاضر / الشيخ المشرف',
                              hintText: 'اختر الشيخ من القائمة',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('محاضر خارجي (كتابة يدوية)')),
                              ...mosqueSheikhs.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.fullName),
                              )),
                            ],
                            onChanged: (v) => setMState(() {
                              selectedSheikhId = v;
                              if (v != null) {
                                final s = mosqueSheikhs.firstWhere((sh) => sh.id == v);
                                speakerCtrl.text = s.fullName;
                              } else {
                                speakerCtrl.clear();
                              }
                            }),
                          ),
                          const SizedBox(height: 12),
                          if (selectedSheikhId == null) ...[
                            TextField(
                              controller: speakerCtrl,
                              decoration: const InputDecoration(
                                labelText: 'اسم المحاضر الخارجي *',
                                hintText: 'أدخل اسم الشيخ يدوياً',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الفعالية أو الدرس *',
                        hintText: 'مثال: شرح صحيح البخاري',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: eventType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع الفعالية'),
                      items: const [
                        DropdownMenuItem(value: 'lesson', child: Text('درس علم وفقه')),
                        DropdownMenuItem(value: 'mawlid', child: Text('مجلس صلاة على النبي ﷺ')),
                        DropdownMenuItem(value: 'tajweed', child: Text('دورة تجويد وإتقان')),
                        DropdownMenuItem(value: 'dhikr_circle', child: Text('مجلس ذكر وتلاوة')),
                        DropdownMenuItem(value: 'general', child: Text('محاضرة عامة')),
                        DropdownMenuItem(value: 'custom', child: Text('مخصص ✍️ (تصنيف جديد)')),
                      ],
                      onChanged: (v) => setMState(() => eventType = v ?? 'lesson'),
                    ),
                    if (eventType == 'custom') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم التصنيف المخصص *',
                          hintText: 'مثال: السيرة النبوية، التفسير، العقيدة...',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: timingType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نظام التوقيت'),
                      items: const [
                        DropdownMenuItem(value: 'prayer_linked', child: Text('مرتبط بمواقيت الصلاة')),
                        DropdownMenuItem(value: 'custom_time', child: Text('تاريخ ووقت مخصص')),
                      ],
                      onChanged: (v) => setMState(() => timingType = v ?? 'prayer_linked'),
                    ),
                    if (timingType == 'prayer_linked') ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isNarrow = MediaQuery.sizeOf(context).width < 420;
                          final relField = DropdownButtonFormField<String>(
                            initialValue: prayerRelation,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'العلاقة'),
                            items: const [
                              DropdownMenuItem(value: 'after', child: Text('مباشرة بعد')),
                              DropdownMenuItem(value: 'between_adhan_iqama', child: Text('بين أذان وإقامة')),
                              DropdownMenuItem(value: 'before', child: Text('قبل أذان')),
                            ],
                            onChanged: (v) => setMState(() => prayerRelation = v ?? 'after'),
                          );
                          final pField = DropdownButtonFormField<String>(
                            initialValue: prayerName,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'الصلاة'),
                            items: const [
                              DropdownMenuItem(value: 'fajr', child: Text('صلاة الفجر')),
                              DropdownMenuItem(value: 'dhuhr', child: Text('صلاة الظهر')),
                              DropdownMenuItem(value: 'asr', child: Text('صلاة العصر')),
                              DropdownMenuItem(value: 'maghrib', child: Text('صلاة المغرب')),
                              DropdownMenuItem(value: 'isha', child: Text('صلاة العشاء')),
                              DropdownMenuItem(value: 'jumua', child: Text('صلاة الجمعة')),
                            ],
                            onChanged: (v) => setMState(() => prayerName = v ?? 'maghrib'),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                relField,
                                const SizedBox(height: 8),
                                pField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: relField),
                              const SizedBox(width: 8),
                              Expanded(child: pField),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedCustomDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setMState(() {
                                    selectedCustomDate = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      selectedCustomTime.hour,
                                      selectedCustomTime.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${selectedCustomDate.year}/${selectedCustomDate.month.toString().padLeft(2, '0')}/${selectedCustomDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedCustomTime,
                                );
                                if (picked != null) {
                                  setMState(() {
                                    selectedCustomTime = picked;
                                    selectedCustomDate = DateTime(
                                      selectedCustomDate.year,
                                      selectedCustomDate.month,
                                      selectedCustomDate.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedCustomTime.format(ctx),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الفئة المستهدفة'),
                      items: _audienceItems(announcerBranch),
                      onChanged: (v) => setMState(
                        () => audience = _coerceAudience(announcerBranch, v ?? audience),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'وصف مختصر أو محاور الدرس'),
                    ),
                    const SizedBox(height: 16),

                    // الدرس المتكرر
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('درس دائم ومتكرر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('يعيد نفسه تلقائياً بعد كل تسجيل حسب الأيام المحددة', style: TextStyle(fontSize: 12)),
                            value: isRecurring,
                            activeThumbColor: primaryColor,
                            onChanged: (v) => setMState(() => isRecurring = v),
                          ),
                          if (isRecurring) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'أيام انعقاد الدرس أسبوعياً:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setMState(() {
                                            if (selectedWeekDays.length == kWeekDays.length) {
                                              selectedWeekDays.clear();
                                            } else {
                                              selectedWeekDays.addAll(kWeekDays);
                                            }
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          selectedWeekDays.length == kWeekDays.length ? 'مسح الكل' : 'كل الأيام',
                                          style: TextStyle(fontSize: 11.5, color: primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: kWeekDays.map((day) {
                                      final isSelected = selectedWeekDays.contains(day);
                                      return FilterChip(
                                        label: Text(day),
                                        selected: isSelected,
                                        selectedColor: primaryColor.withValues(alpha: 0.2),
                                        checkmarkColor: primaryColor,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? primaryColor : null,
                                        ),
                                        onSelected: (sel) {
                                          setMState(() {
                                            if (sel) {
                                              selectedWeekDays.add(day);
                                            } else {
                                              selectedWeekDays.remove(day);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // استقبال الأسئلة
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('تفعيل استقبال الأسئلة المجهولة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('يسمح للجمهور بطرح أسئلة بدون كشف هويتهم', style: TextStyle(fontSize: 12)),
                            value: isQaEnabled,
                            activeThumbColor: primaryColor,
                            onChanged: (v) => setMState(() => isQaEnabled = v),
                          ),
                          if (isQaEnabled)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: TextFormField(
                                initialValue: maxQuestions.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الحد الأقصى للأسئلة المسموحة',
                                  hintText: 'مثال: 10',
                                ),
                                onChanged: (v) => setMState(() => maxQuestions = int.tryParse(v) ?? 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال عنوان الفعالية أو الدرس')),
                    );
                    return;
                  }

                  final groupIds = LessonSpeakersField.orderedSelection(mosqueSheikhs, groupSheikhIds);
                  if (isGroupLesson && groupIds.length < LessonSpeakersField.minGroupSize) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اختر شيخين على الأقل للدرس الجماعي')),
                    );
                    return;
                  }

                  final speakerName = speakerCtrl.text.trim();
                  if (!isGroupLesson && speakerName.isEmpty && selectedSheikhId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار المحاضر أو إدخال اسم المحاضر الخارجي')),
                    );
                    return;
                  }

                  final customName = eventType == 'custom' ? customTypeCtrl.text.trim() : null;
                  if (eventType == 'custom' && (customName == null || customName.isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم التصنيف المخصص')),
                    );
                    return;
                  }

                  final calculatedDateTime = timingType == 'custom_time'
                      ? DateTime(
                          selectedCustomDate.year,
                          selectedCustomDate.month,
                          selectedCustomDate.day,
                          selectedCustomTime.hour,
                          selectedCustomTime.minute,
                        )
                      : DateTime.now().add(const Duration(hours: 2));

                  try {
                    final newEv = data.addCommunityEvent(
                      mosqueId: selectedMosqueId,
                      title: title,
                      description: descCtrl.text.trim(),
                      eventType: eventType,
                      customTypeName: customName,
                      timingType: timingType,
                      prayerName: timingType == 'prayer_linked' ? prayerName : null,
                      prayerRelation: prayerRelation,
                      targetAudience: audience,
                      eventDateTime: calculatedDateTime,
                      organizerType: 'mosque_admin',
                      organizerName: isGroupLesson
                          ? LessonSpeakersField.joinNames(
                              groupIds.map((id) => mosqueSheikhs.firstWhere((s) => s.id == id).fullName),
                            )
                          : (speakerName.isNotEmpty ? speakerName : 'إدارة المسجد'),
                      isQaEnabled: isQaEnabled,
                      maxQuestions: maxQuestions,
                      isRecurring: isRecurring,
                      recurringDays: isRecurring && selectedWeekDays.isNotEmpty ? selectedWeekDays.join(', ') : null,
                      sheikhId: isGroupLesson ? groupIds.first : selectedSheikhId,
                      lessonFormat: isGroupLesson ? 'group' : 'single',
                      sheikhIds: isGroupLesson ? groupIds : const [],
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم نشر الفعالية (${newEv.title}) بنجاح ✨', style: AppTypography.buttonText()),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تعذر نشر الفعالية: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('نشر الفعالية'),
              ),
            ],
          );
        },
      ),
    );
  }

  // موجه موحد للتوافق مع أي استدعاء قديم
  static void showAddPublicEventModal(
      BuildContext context,
      DataService data,
      ActiveSession session, {
        bool isFromAdmin = false,
      }) {
    if (isFromAdmin || session.role == 'mosque_admin') {
      showAdminAddPublicEventModal(context, data, session);
    } else {
      showSheikhAddPublicEventModal(context, data, session);
    }
  }

  static void showEditPublicEventModal(
      BuildContext context,
      DataService data,
      CommunityEvent ev, {
        bool isFromAdmin = false,
      }) {
    final mosques = data.getVisibleMosques();
    String selectedMosqueId = mosques.any((m) => m.id == ev.mosqueId)
        ? ev.mosqueId
        : (mosques.isNotEmpty ? mosques.first.id : ev.mosqueId);

    // جلب قائمة الشيوخ للمسجد المختار
    List<Sheikh> mosqueSheikhs = data.getSheikhs(mosqueId: selectedMosqueId);
    String? selectedSheikhId = ev.sheikhId;
    bool isGroupLesson = ev.lessonFormat == 'group';
    final Set<String> groupSheikhIds = {...ev.allSheikhIds};

    final titleCtrl = TextEditingController(text: ev.title);
    final descCtrl = TextEditingController(text: ev.description);
    final speakerCtrl = TextEditingController(text: ev.organizerName);
    final customTypeCtrl = TextEditingController(text: ev.customTypeName);
    String eventType = ev.eventType;
    String timingType = ev.timingType;
    String prayerName = ev.prayerName ?? 'maghrib';
    String prayerRelation = ev.prayerRelation ?? 'after';
    // الفئة المحفوظة تُحترم كما هي: قبل هذا الإصلاح كان تعديل أي درس نسائي
    // يحوّله تلقائياً إلى "رجال فقط" فيُكشف للرجال.
    String audience = ev.targetAudience;

    // جلب قيم الأسئلة المحفوظة مسبقاً
    bool isQaEnabled = ev.isQaEnabled;
    int maxQuestions = ev.maxQuestions;
    bool isRecurring = ev.isRecurring;

    DateTime selectedCustomDate = ev.eventDateTime;
    TimeOfDay selectedCustomTime = TimeOfDay.fromDateTime(ev.eventDateTime);

    final Set<String> selectedWeekDays = (ev.recurringDays != null && ev.recurringDays!.trim().isNotEmpty)
        ? ev.recurringDays!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
        : {'السبت', 'الاثنين', 'الخميس'};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final primaryColor = Theme.of(ctx).colorScheme.primary;
          final announcerBranch = data.branchOfMosque(selectedMosqueId);
          audience = _coerceAudience(announcerBranch, audience);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isFromAdmin && mosques.isNotEmpty) ...[
                      MinisterialDropdownField<String>(
                        label: 'المسجد المقامة فيه الفعالية',
                        isRequired: true,
                        value: selectedMosqueId,
                        items: mosques.map((m) {
                          final addr = (m.address != null && m.address!.trim().isNotEmpty)
                              ? ' - ${m.address!.trim()}'
                              : '';
                          return DropdownMenuItem<String>(
                            value: m.id,
                            child: Text(
                              '${m.name}$addr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setMState(() {
                          selectedMosqueId = v ?? selectedMosqueId;
                          mosqueSheikhs = data.getSheikhs(mosqueId: selectedMosqueId);
                          selectedSheikhId = null;
                          groupSheikhIds.clear();
                          speakerCtrl.clear();
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --- المحاضر: فردي أو جماعي ---
                    LessonSpeakersField(
                      isGroup: isGroupLesson,
                      onFormatChanged: (v) => setMState(() => isGroupLesson = v),
                      sheikhs: mosqueSheikhs,
                      selectedIds: groupSheikhIds,
                      onSelectionChanged: (ids) => setMState(() {
                        groupSheikhIds
                          ..clear()
                          ..addAll(ids);
                      }),
                      singleChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String?>(
                            key: ValueKey('sheikh_select_edit_$selectedSheikhId'),
                            initialValue: mosqueSheikhs.any((s) => s.id == selectedSheikhId) ? selectedSheikhId : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'المحاضر / الشيخ المشرف',
                              hintText: 'اختر الشيخ من القائمة',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('محاضر خارجي (كتابة يدوية)')),
                              ...mosqueSheikhs.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.fullName),
                              )),
                            ],
                            onChanged: (v) => setMState(() {
                              selectedSheikhId = v;
                              if (v != null) {
                                final s = mosqueSheikhs.firstWhere((sh) => sh.id == v);
                                speakerCtrl.text = s.fullName;
                              }
                            }),
                          ),
                          const SizedBox(height: 12),

                          if (selectedSheikhId == null) ...[
                            TextField(
                              controller: speakerCtrl,
                              decoration: const InputDecoration(
                                labelText: 'اسم المحاضر الخارجي *',
                                hintText: 'أدخل اسم الشيخ يدوياً',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'عنوان الفعالية *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: eventType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع الفعالية'),
                      items: const [
                        DropdownMenuItem(value: 'lesson', child: Text('درس علم وفقه')),
                        DropdownMenuItem(value: 'mawlid', child: Text('مجلس صلاة على النبي ﷺ')),
                        DropdownMenuItem(value: 'tajweed', child: Text('دورة تجويد وإتقان')),
                        DropdownMenuItem(value: 'dhikr_circle', child: Text('مجلس ذكر وتلاوة')),
                        DropdownMenuItem(value: 'general', child: Text('محاضرة عامة')),
                        DropdownMenuItem(value: 'custom', child: Text('مخصص ✍️ (تصنيف جديد)')),
                      ],
                      onChanged: (v) => setMState(() => eventType = v ?? 'lesson'),
                    ),
                    if (eventType == 'custom') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم التصنيف المخصص *',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: timingType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نظام التوقيت'),
                      items: const [
                        DropdownMenuItem(value: 'prayer_linked', child: Text('مرتبط بمواقيت الصلاة')),
                        DropdownMenuItem(value: 'custom_time', child: Text('تاريخ ووقت مخصص')),
                      ],
                      onChanged: (v) => setMState(() => timingType = v ?? 'prayer_linked'),
                    ),
                    if (timingType == 'prayer_linked') ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isNarrow = MediaQuery.sizeOf(context).width < 420;
                          final relationField = DropdownButtonFormField<String>(
                            initialValue: prayerRelation,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'العلاقة'),
                            items: const [
                              DropdownMenuItem(value: 'after', child: Text('مباشرة بعد')),
                              DropdownMenuItem(value: 'between_adhan_iqama', child: Text('بين أذان وإقامة')),
                              DropdownMenuItem(value: 'before', child: Text('قبل أذان')),
                            ],
                            onChanged: (v) => setMState(() => prayerRelation = v ?? 'after'),
                          );
                          final prayerField = DropdownButtonFormField<String>(
                            initialValue: prayerName,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'الصلاة'),
                            items: const [
                              DropdownMenuItem(value: 'fajr', child: Text('صلاة الفجر')),
                              DropdownMenuItem(value: 'dhuhr', child: Text('صلاة الظهر')),
                              DropdownMenuItem(value: 'asr', child: Text('صلاة العصر')),
                              DropdownMenuItem(value: 'maghrib', child: Text('صلاة المغرب')),
                              DropdownMenuItem(value: 'isha', child: Text('صلاة العشاء')),
                              DropdownMenuItem(value: 'jumua', child: Text('صلاة الجمعة')),
                            ],
                            onChanged: (v) => setMState(() => prayerName = v ?? 'maghrib'),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                relationField,
                                const SizedBox(height: 8),
                                prayerField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: relationField),
                              const SizedBox(width: 8),
                              Expanded(child: prayerField),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedCustomDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setMState(() {
                                    selectedCustomDate = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      selectedCustomTime.hour,
                                      selectedCustomTime.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${selectedCustomDate.year}/${selectedCustomDate.month.toString().padLeft(2, '0')}/${selectedCustomDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedCustomTime,
                                );
                                if (picked != null) {
                                  setMState(() {
                                    selectedCustomTime = picked;
                                    selectedCustomDate = DateTime(
                                      selectedCustomDate.year,
                                      selectedCustomDate.month,
                                      selectedCustomDate.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedCustomTime.format(ctx),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الفئة المستهدفة'),
                      items: _audienceItems(announcerBranch),
                      onChanged: (v) => setMState(
                        () => audience = _coerceAudience(announcerBranch, v ?? audience),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'الوصف أو المحاور'),
                    ),
                    const SizedBox(height: 16),

                    // --- خيار الدرس الدائم وتحديد أيام التكرار ---
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('درس دائم ومتكرر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('يعيد نفسه تلقائياً بعد كل تسجيل حسب الأيام المحددة', style: TextStyle(fontSize: 12)),
                            value: isRecurring,
                            activeThumbColor: primaryColor,
                            onChanged: (v) => setMState(() => isRecurring = v),
                          ),
                          if (isRecurring) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'أيام انعقاد الدرس أسبوعياً:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setMState(() {
                                            if (selectedWeekDays.length == kWeekDays.length) {
                                              selectedWeekDays.clear();
                                            } else {
                                              selectedWeekDays.addAll(kWeekDays);
                                            }
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          selectedWeekDays.length == kWeekDays.length ? 'مسح الكل' : 'كل الأيام',
                                          style: TextStyle(fontSize: 11.5, color: primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: kWeekDays.map((day) {
                                      final isSelected = selectedWeekDays.contains(day);
                                      return FilterChip(
                                        label: Text(day),
                                        selected: isSelected,
                                        selectedColor: primaryColor.withValues(alpha: 0.2),
                                        checkmarkColor: primaryColor,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? primaryColor : null,
                                        ),
                                        onSelected: (sel) {
                                          setMState(() {
                                            if (sel) {
                                              selectedWeekDays.add(day);
                                            } else {
                                              selectedWeekDays.remove(day);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // --- قسم الأسئلة والتفاعل ---
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('تفعيل استقبال الأسئلة المجهولة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('يسمح للجمهور بطرح أسئلة بدون كشف هويتهم', style: TextStyle(fontSize: 12)),
                            value: isQaEnabled,
                            activeThumbColor: primaryColor,
                            onChanged: (v) => setMState(() => isQaEnabled = v),
                          ),
                          if (isQaEnabled)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: TextFormField(
                                initialValue: maxQuestions.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الحد الأقصى للأسئلة المسموحة',
                                  hintText: 'مثال: 10',
                                ),
                                onChanged: (v) => setMState(() => maxQuestions = int.tryParse(v) ?? 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final groupIds = LessonSpeakersField.orderedSelection(mosqueSheikhs, groupSheikhIds);
                  if (isGroupLesson && groupIds.length < LessonSpeakersField.minGroupSize) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اختر شيخين على الأقل للدرس الجماعي')),
                    );
                    return;
                  }
                  final calculatedDateTime = timingType == 'custom_time'
                      ? DateTime(
                          selectedCustomDate.year,
                          selectedCustomDate.month,
                          selectedCustomDate.day,
                          selectedCustomTime.hour,
                          selectedCustomTime.minute,
                        )
                      : ev.eventDateTime;

                  data.updateCommunityEvent(
                    eventId: ev.id,
                    title: title,
                    description: descCtrl.text.trim(),
                    eventType: eventType,
                    customTypeName: eventType == 'custom' ? customTypeCtrl.text.trim() : null,
                    timingType: timingType,
                    prayerName: timingType == 'prayer_linked' ? prayerName : null,
                    prayerRelation: prayerRelation,
                    targetAudience: audience,
                    organizerName: isGroupLesson
                        ? LessonSpeakersField.joinNames(
                            groupIds.map((id) => mosqueSheikhs.firstWhere((s) => s.id == id).fullName),
                          )
                        : speakerCtrl.text.trim(),
                    eventDateTime: calculatedDateTime,
                    isQaEnabled: isQaEnabled,
                    maxQuestions: maxQuestions,
                    isRecurring: isRecurring,
                    recurringDays: isRecurring && selectedWeekDays.isNotEmpty ? selectedWeekDays.join(', ') : null,
                    sheikhId: isGroupLesson ? groupIds.first : selectedSheikhId,
                    lessonFormat: isGroupLesson ? 'group' : 'single',
                    sheikhIds: isGroupLesson ? groupIds : const [],
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }
}