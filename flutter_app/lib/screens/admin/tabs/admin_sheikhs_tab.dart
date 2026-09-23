import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';
import '../../../widgets/printable_badge_dialog.dart';

class AdminSheikhsTab extends StatefulWidget {
  final Mosque mosque;
  final List<Sheikh> sheikhs;
  final bool isDark;

  const AdminSheikhsTab({
    super.key,
    required this.mosque,
    required this.sheikhs,
    this.isDark = false,
  });

  @override
  State<AdminSheikhsTab> createState() => _AdminSheikhsTabState();
}

class _AdminSheikhsTabState extends State<AdminSheikhsTab> {
  void _showAddSheikhModal(BuildContext context, DataService data) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    File? pickedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            widget.mosque.gender == 'female' ? 'إضافة معلمة حلقة جديدة' : 'إضافة شيخ حلقة جديد',
            style: AppTypography.dialogTitle(context),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                ProfileImagePicker(
                  selectedImageFile: pickedImage,
                  fallbackName: nameCtrl.text,
                  radius: 44,
                  onImageChanged: (file) => setMState(() => pickedImage = file),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                  onChanged: (_) => setMState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف *'),
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
                    const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف')),
                  );
                  return;
                }
                final newSheikh = data.addSheikh(
                  widget.mosque.id,
                  name,
                  phone,
                  profileImageUrl: pickedImage?.path,
                );
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => PrintableBadgeDialog(
                    title: 'بطاقة المحفظ المعتمد والباركود',
                    name: newSheikh.fullName,
                    roleLabel: 'محفظ معتمد',
                    mosqueName: widget.mosque.name,
                    code: newSheikh.code,
                    profileImageUrl: newSheikh.profileImageUrl,
                  ),
                );
              },
              child: Text('إضافة وتوليد الكود', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheikhModal(BuildContext context, DataService data, Sheikh sheikh) {
    final nameCtrl = TextEditingController(text: sheikh.fullName);
    final phoneCtrl = TextEditingController(text: sheikh.phone ?? '');
    File? pickedImage;
    String? currentImageUrl = sheikh.profileImageUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تعديل بيانات المحفظ', style: AppTypography.dialogTitle(context)),
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
                  decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                  onChanged: (_) => setMState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف *'),
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
                    const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف')),
                  );
                  return;
                }
                final finalPath = pickedImage != null ? pickedImage!.path : currentImageUrl;
                data.updateSheikh(
                  sheikhId: sheikh.id,
                  fullName: name,
                  phone: phone,
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

  void _confirmDeleteSheikh(BuildContext context, DataService data, Sheikh sheikh) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تأكيد الحذف', style: AppTypography.dialogTitle(context)),
        content: Text(
          'هل تريد حذف "${sheikh.fullName}"؟ سيتم فك ارتباطه بالحلقات التابعة له.',
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
              data.deleteSheikh(sheikh.id);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verve Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'المشايخ والمعلمات المعتمدون (${widget.sheikhs.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddSheikhModal(context, data),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(
                  widget.mosque.gender == 'female' ? 'إضافة معلمة حلقة' : 'إضافة شيخ جديد',
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
        const SizedBox(height: 8),

        // Verve List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: widget.sheikhs.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا يوجد مشايخ أو معلمات مضافين بالمسجد',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: widget.sheikhs.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final sheikh = widget.sheikhs[idx];
              final stCount = data.getStudents(sheikhId: sheikh.id).length;
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
                    initialImageUrl: sheikh.profileImageUrl,
                    fallbackName: sheikh.fullName,
                    onImageChanged: (_) {},
                  );

                  final nameWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sheikh.fullName,
                        style: AppTypography.verveTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.mosque.gender == "female" ? "معلمة معتمدة" : "محفظ معتمد"} • $stCount طلاب مسجلين بالحلقات${sheikh.phone != null && sheikh.phone!.isNotEmpty ? " • هاتف: ${sheikh.phone}" : ""}',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  );

                  final badgesWidget = Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      UnifiedBadge(
                        label: 'كود: ${sheikh.code}',
                        backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                        textColor: AppColors.terracottaPrimary,
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
                        tooltip: 'تعديل بيانات المحفظ',
                        icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 19),
                        onPressed: () => _showEditSheikhModal(context, data, sheikh),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'بطاقة الاعتماد والـ QR',
                        icon: Icon(Icons.qr_code, color: AppColors.terracottaPrimary, size: 19),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PrintableBadgeDialog(
                              title: 'بطاقة اعتماد المحفظ الرسمية',
                              name: sheikh.fullName,
                              roleLabel: widget.mosque.gender == 'female' ? 'معلمة حلقة معتمدة' : 'شيخ حلقة معتمد',
                              mosqueName: widget.mosque.name,
                              code: sheikh.code,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
                        onPressed: () => _confirmDeleteSheikh(context, data, sheikh),
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
                        Expanded(flex: 4, child: nameWidget),
                        Expanded(flex: 2, child: badgesWidget),
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