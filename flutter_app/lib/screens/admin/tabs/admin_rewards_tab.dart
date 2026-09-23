import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../widgets/qr_dialogs.dart';

class AdminRewardsTab extends StatefulWidget {
  final Mosque mosque;
  final bool isDark;

  const AdminRewardsTab({
    super.key,
    required this.mosque,
    this.isDark = false,
  });

  @override
  State<AdminRewardsTab> createState() => _AdminRewardsTabState();
}

class _AdminRewardsTabState extends State<AdminRewardsTab> {
  void _showAddRewardModal(BuildContext context, DataService data) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          title: Text('إضافة جائزة جديدة لبنك المسجد', style: AppTypography.dialogTitle(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الجائزة أو المكافأة *',
                    hintText: 'مثال: مصحف المدينة المنورة الفاخر',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر الجائزة بالنقاط *',
                    hintText: 'مثال: 100',
                    prefixIcon: Icon(Icons.star, color: AppTheme.gold),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'وصف أو تفاصيل الجائزة'),
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
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final cost = int.tryParse(costCtrl.text.trim()) ?? 100;
                final newReward = data.addReward(
                  mosqueId: widget.mosque.id,
                  title: title,
                  description: descCtrl.text.trim(),
                  pointsCost: cost,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت إضافة جائزة (${newReward.title}) بسعر ${newReward.pointsCost} نقطة إلى بنك المسجد',
                      style: AppTypography.buttonText(),
                    ),
                    backgroundColor: AppColors.emeraldSuccess,
                  ),
                );
              },
              child: Text('إضافة الجائزة', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRewardModal(BuildContext context, DataService data, Reward reward) {
    final titleCtrl = TextEditingController(text: reward.title);
    final descCtrl = TextEditingController(text: reward.description ?? '');
    final costCtrl = TextEditingController(text: reward.pointsCost.toString());
    bool isActive = reward.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          title: Text('تعديل بيانات الجائزة', style: AppTypography.dialogTitle(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم الجائزة *')),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر الجائزة بالنقاط *',
                    prefixIcon: Icon(Icons.star, color: AppTheme.gold),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('متاحة للطلب الآن', style: AppTypography.bodyRegular(context)),
                  value: isActive,
                  activeThumbColor: AppTheme.emeraldPrimary,
                  onChanged: (val) => setMState(() => isActive = val),
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
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final cost = int.tryParse(costCtrl.text.trim()) ?? reward.pointsCost;
                final updated = Reward(
                  id: reward.id,
                  mosqueId: reward.mosqueId,
                  title: title,
                  description: descCtrl.text.trim(),
                  pointsCost: cost,
                  isActive: isActive,
                  createdAt: reward.createdAt,
                );
                data.updateReward(updated);
                Navigator.pop(ctx);
              },
              child: Text('حفظ التعديلات', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteReward(BuildContext context, DataService data, Reward reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد حذف الجائزة', style: AppTypography.dialogTitle(context)),
        content: Text(
          'هل تريد حذف جائزة "${reward.title}" من بنك جوائز المسجد؟',
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
              data.deleteReward(reward.id);
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
    // Admin sees everything for management
    final allRewards = data.getRewards(mosqueId: widget.mosque.id);
    final activeRewardsCount = allRewards.where((r) => r.isActive).length;
    
    final redemptions = data.getRedemptions(mosqueId: widget.mosque.id);
    final dispensedCount = redemptions.where((r) => r.isDispensed).length;
    final pendingCount = redemptions.where((r) => r.isPending).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

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
                'بنك الجوائز والمكافآت ($activeRewardsCount نشطة / ${allRewards.length} إجمالي)',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddRewardModal(context, data),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة جائزة جديدة 🎁', style: AppTypography.buttonText()),
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
        const SizedBox(height: 6),

        // Verve Open Stats Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.emeraldPrimary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'تم صرفها: $dispensedCount جائزة',
                    style: AppTypography.titleBold(context, color: AppColors.emeraldPrimary, fontSize: 13.5),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_outlined, color: AppColors.goldDark, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'قيد الانتظار بالصراف: $pendingCount جائزة',
                    style: AppTypography.titleBold(context, color: AppColors.goldDark, fontSize: 13.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // --- نظام اعتماد صراف الجوائز ---
        LayoutBuilder(
          builder: (context, cashierConstraints) {
            final isNarrow = cashierConstraints.maxWidth < 450;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.3)),
              ),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.point_of_sale_rounded, color: AppColors.emeraldPrimary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'كود اعتماد صراف المسجد',
                                    style: AppTypography.titleBold(context, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'استخدم هذا الكود لفتح بوابة الصراف المعتمدة لمسجدك.',
                                    style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.mosque.effectiveCashierCode,
                                    style: AppTypography.verveNumber(context).copyWith(
                                      fontSize: 16,
                                      color: AppColors.emeraldPrimary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => SectionQrCodeDialog(
                                  title: 'كود اعتماد صراف الجوائز',
                                  subtitle: 'امسح هذا الكود لفتح بوابة الصراف في مسجد ${widget.mosque.name}',
                                  code: widget.mosque.effectiveCashierCode,
                                  icon: Icons.point_of_sale_rounded,
                                  primaryColor: AppColors.emeraldPrimary,
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_2, size: 18),
                            label: const Text('عرض الباركود'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldPrimary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.point_of_sale_rounded, color: AppColors.emeraldPrimary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كود اعتماد صراف المسجد',
                                style: AppTypography.titleBold(context, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'استخدم هذا الكود لفتح بوابة الصراف المعتمدة لمسجدك.',
                                style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.mosque.effectiveCashierCode,
                                style: AppTypography.verveNumber(context).copyWith(
                                  fontSize: 16,
                                  color: AppColors.emeraldPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => SectionQrCodeDialog(
                                title: 'كود اعتماد صراف الجوائز',
                                subtitle: 'امسح هذا الكود لفتح بوابة الصراف في مسجد ${widget.mosque.name}',
                                code: widget.mosque.effectiveCashierCode,
                                icon: Icons.point_of_sale_rounded,
                                primaryColor: AppColors.emeraldPrimary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('عرض الباركود'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldPrimary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: allRewards.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد جوائز معروضة في بنك المسجد بعد',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: allRewards.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final r = allRewards[idx];
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return Opacity(
                opacity: r.isActive ? 1.0 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      final actionsRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: r.isActive,
                            activeThumbColor: AppColors.emeraldPrimary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              data.updateReward(Reward(
                                id: r.id,
                                mosqueId: r.mosqueId,
                                title: r.title,
                                description: r.description,
                                pointsCost: r.pointsCost,
                                isActive: val,
                                createdAt: r.createdAt,
                              ));
                            },
                          ),
                          IconButton(
                            tooltip: 'تعديل الجائزة',
                            icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
                            onPressed: () => _showEditRewardModal(context, data, r),
                          ),
                          IconButton(
                            tooltip: 'حذف الجائزة',
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDeleteReward(context, data, r),
                          ),
                        ],
                      );

                      final badgesWrap = Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          UnifiedBadge(
                            label: '${r.pointsCost} نقطة 🪙',
                            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                            textColor: AppColors.goldDark,
                          ),
                          UnifiedBadge(
                            label: r.isActive ? 'متاحة للطلب' : 'معطّلة مؤقتاً',
                            backgroundColor: r.isActive
                                ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.15),
                            textColor: r.isActive ? AppColors.terracottaPrimary : Colors.grey,
                          ),
                        ],
                      );

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    serialNumber,
                                    style: AppTypography.verveNumber(context),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.title,
                                        style: AppTypography.verveTitle(context),
                                      ),
                                      if (r.description != null && r.description!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          r.description!,
                                          style: AppTypography.verveSubtitle(context),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                actionsRow,
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(right: 38),
                              child: badgesWrap,
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 01, 02 Serial Number
                          SizedBox(
                            width: 48,
                            child: Text(
                              serialNumber,
                              style: AppTypography.verveNumber(context),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Reward Title & Description
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: AppTypography.verveTitle(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.description != null && r.description!.isNotEmpty
                                      ? r.description!
                                      : (r.isActive ? 'متاحة للطلب الفوري' : 'معطّلة مؤقتاً (مخفية عن الطلاب)'),
                                  style: AppTypography.verveSubtitle(context),
                                ),
                              ],
                            ),
                          ),

                          // Badges (Cost & Status)
                          Expanded(
                            flex: 4,
                            child: badgesWrap,
                          ),

                          // Quick Toggle & Actions
                          actionsRow,
                        ],
                      );
                    },
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
}