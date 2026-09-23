import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class AdminOverviewTab extends StatefulWidget {
  final Mosque mosque;
  final bool isDark;

  const AdminOverviewTab({
    super.key,
    required this.mosque,
    this.isDark = false,
  });

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  String _overviewSearch = '';
  String _overviewHalaqaFilter = 'all';
  DateTime _overviewDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final halaqat = data.getHalaqat(mosqueId: widget.mosque.id);
    final overviewItems = data.getExecutiveOverview(
      mosqueId: widget.mosque.id,
      halaqaId: _overviewHalaqaFilter == 'all' ? null : _overviewHalaqaFilter,
      searchQuery: _overviewSearch,
      date: _overviewDate,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final dateStr =
        '${_overviewDate.year}/${_overviewDate.month.toString().padLeft(2, '0')}/${_overviewDate.day.toString().padLeft(2, '0')}';

    final currentMosque = data.getMosqueById(widget.mosque.id) ?? widget.mosque;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header & Summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'لوحة المتابعة الشاملة لطلاب وحلقات المسجد',
                style: AppTypography.verveHeaderTitle(context),
              ),
              Text(
                'إجمالي السجلات: ${overviewItems.length}',
                style: AppTypography.titleBold(context, color: AppColors.terracottaPrimary, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // بطاقة إعدادات التبرع الإلكتروني (شام كاش)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentMosque.hasActiveDonation
                ? AppColors.emeraldPrimary.withValues(alpha: 0.08)
                : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: currentMosque.hasActiveDonation
                  ? AppColors.emeraldPrimary.withValues(alpha: 0.35)
                  : dividerColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentMosque.hasActiveDonation ? AppColors.emeraldPrimary : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'نظام التبرعات الإلكترونية (شام كاش)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const SizedBox(width: 8),
                        UnifiedBadge(
                          label: currentMosque.hasActiveDonation ? 'مفعل للعموم 🟢' : 'معطل ⚪',
                          backgroundColor: currentMosque.hasActiveDonation ? const Color(0xFFD1FAE5) : Colors.grey.withValues(alpha: 0.2),
                          textColor: currentMosque.hasActiveDonation ? const Color(0xFF047857) : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentMosque.hasActiveDonation
                          ? 'الحساب: ${currentMosque.donationAccountName ?? ""} (${currentMosque.donationAccountNumber ?? ""})'
                          : 'اضغط لضبط الحساب ورفع باركود التبرع للمصلين في شاشة استكشف',
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: currentMosque.hasActiveDonation ? AppColors.emeraldPrimary : Colors.grey),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                label: const Text('إعدادات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showDonationSettingsDialog(context, data, currentMosque),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Filter Bar (Clean Verve Style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final searchField = TextField(
                decoration: const InputDecoration(
                  hintText: 'بحث باسم الطالب أو الكود المعتمد...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (v) => setState(() => _overviewSearch = v.trim()),
              );

              final halaqaFilter = DropdownButtonFormField<String>(
                initialValue: _overviewHalaqaFilter,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('جميع الحلقات', style: AppTypography.bodyRegular(context)),
                  ),
                  ...halaqat.map((h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, style: AppTypography.bodyRegular(context)),
                  )),
                ],
                onChanged: (v) => setState(() => _overviewHalaqaFilter = v ?? 'all'),
              );

              final dateButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _overviewDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _overviewDate = d);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  dateStr,
                  style: AppTypography.bodyRegular(context, fontSize: 13),
                ),
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
                        dateButton,
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
                  dateButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Full-Width Comprehensive Data Table
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: overviewItems.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد بيانات مطابقة للبحث أو التاريخ المحدد',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: dividerColor,
                      ),
                      child: DataTable(
                        headingRowHeight: 54,
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 68,
                        horizontalMargin: 20,
                        columnSpacing: 28,
                        headingRowColor: WidgetStatePropertyAll(
                          isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              'الطالب',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'الحلقة',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'المحفظ المشرف',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'حضور اليوم',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'آخر تسميع قرآن',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'آخر حديث نبوي',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'المتقن من 30',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'مجموع النقاط',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                        ],
                        rows: overviewItems.map((item) {
                          final student = item['student'] as Student;
                          final halaqa = item['halaqa'] as Halaqa;
                          final sheikh = item['sheikh'] as Sheikh;
                          final att = item['attendance'] as AttendanceRecord;
                          final lastQuran = item['lastQuran'] as MemorizationRecord?;
                          final lastHadith = item['lastHadith'] as PointsLog?;
                          final completedAjza = item['completedAjza'] as int;
                          final totalPoints = item['totalPoints'] as int;

                          String attText = 'لم يرصد';
                          if (att.status == 'present') {
                            attText = 'حاضر';
                          } else if (att.status == 'late') {
                            attText = 'متأخر';
                          } else if (att.status == 'absent') {
                            attText = 'غائب';
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProfileImagePicker(
                                      radius: 16,
                                      isEditable: false,
                                      initialImageUrl: student.profileImageUrl,
                                      fallbackName: student.fullName,
                                      onImageChanged: (_) {},
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      student.fullName,
                                      style: AppTypography.titleBold(context, fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  halaqa.name,
                                  style: AppTypography.bodyRegular(context, fontSize: 13),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProfileImagePicker(
                                      radius: 16,
                                      isEditable: false,
                                      initialImageUrl: sheikh.profileImageUrl,
                                      fallbackName: sheikh.fullName,
                                      onImageChanged: (_) {},
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      sheikh.fullName,
                                      style: AppTypography.titleBold(context, fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                UnifiedBadge.fromStatus(attText),
                              ),
                              DataCell(
                                Text(
                                  lastQuran != null
                                      ? 'سورة ${lastQuran.surahName} (${lastQuran.fromAyah}-${lastQuran.toAyah})'
                                      : 'لا يوجد',
                                  style: AppTypography.bodyRegular(context, fontSize: 12.5),
                                ),
                              ),
                              DataCell(
                                Text(
                                  lastHadith != null
                                      ? lastHadith.reason.replaceAll('تسميع حديث نبوي شريف: ', '')
                                      : 'لا يوجد',
                                  style: AppTypography.bodyRegular(context, fontSize: 12.5),
                                ),
                              ),
                              DataCell(
                                UnifiedBadge(
                                  label: '$completedAjza / 30 جزء',
                                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                                  textColor: AppColors.goldDark,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '$totalPoints نقطة',
                                  style: AppTypography.titleBold(
                                    context,
                                    color: AppColors.terracottaPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

  void _showDonationSettingsDialog(BuildContext context, DataService data, Mosque mosque) {
    bool isEnabled = mosque.isDonationEnabled;
    final nameCtrl = TextEditingController(text: mosque.donationAccountName ?? mosque.name);
    final numCtrl = TextEditingController(text: mosque.donationAccountNumber ?? '');
    final descCtrl = TextEditingController(text: mosque.donationDescription ?? 'صدقة جارية وبناء لبيوت الله ودعم حلقات القرآن');
    String? imageUrl = mosque.donationImageUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.volunteer_activism_rounded, color: AppColors.emeraldPrimary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'إعدادات التبرع الإلكتروني (شام كاش)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // تفعيل / تعطيل
                    SwitchListTile(
                      title: const Text('تفعيل استقبال التبرعات للعموم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('إظهار باركود التبرع للمصلين في شاشة استكشف والمجتمع', style: TextStyle(fontSize: 11.5)),
                      value: isEnabled,
                      activeThumbColor: AppColors.emeraldPrimary,
                      onChanged: (v) => setDialogState(() => isEnabled = v),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // اسم الحساب
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'اسم الحساب / الجهة المستفيدة',
                        hintText: 'مثال: صندوق مسجد الإيمان - شام كاش',
                        prefixIcon: const Icon(Icons.account_balance_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // رقم الحساب / شام كاش
                    TextField(
                      controller: numCtrl,
                      decoration: InputDecoration(
                        labelText: 'رقم حساب شام كاش أو الآيبان',
                        hintText: 'مثال: 987654321 أو SY00...',
                        prefixIcon: const Icon(Icons.numbers_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // وصف وملاحظات التبرع
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'وصف أو مصرف التبرعات للمصلين',
                        hintText: 'مثال: تبرعات صيانة المسجد، كفالة حلقات التحفيظ...',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // صورة باركود شام كاش المرفوعة
                    Text('صورة باركود شام كاش (QR Code):', style: AppTypography.titleBold(ctx, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: (imageUrl != null && imageUrl!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: imageUrl!.startsWith('data:image')
                                      ? Image.memory(
                                          base64Decode(imageUrl!.split(',').last),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.broken_image_rounded, size: 30, color: Colors.grey),
                                          ),
                                        )
                                      : (imageUrl!.startsWith('http')
                                          ? Image.network(imageUrl!, fit: BoxFit.cover)
                                          : Image.file(File(imageUrl!), fit: BoxFit.cover)),
                                )
                              : const Center(
                                  child: Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.grey),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emeraldPrimary,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: const Text('اختيار صورة الباركود', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                    imageQuality: 85,
                                  );
                                  if (picked != null) {
                                    final bytes = await picked.readAsBytes();
                                    final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
                                    setDialogState(() => imageUrl = base64Image);
                                  }
                                },
                              ),
                              if (imageUrl != null && imageUrl!.isNotEmpty)
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  label: const Text('إزالة الصورة', style: TextStyle(fontSize: 12)),
                                  onPressed: () => setDialogState(() => imageUrl = null),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  data.updateMosqueDonationSettings(
                    mosqueId: mosque.id,
                    isEnabled: isEnabled,
                    accountName: nameCtrl.text.trim(),
                    accountNumber: numCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    imageUrl: imageUrl,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('تم تحديث إعدادات التبرع الإلكتروني بنجاح ✨'),
                      backgroundColor: AppColors.emeraldPrimary,
                    ),
                  );
                },
                child: const Text('حفظ الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}