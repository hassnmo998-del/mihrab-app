import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';

class AdminTracksTab extends StatefulWidget {
  final Mosque mosque;
  final bool isDark;

  const AdminTracksTab({
    super.key,
    required this.mosque,
    this.isDark = false,
  });

  @override
  State<AdminTracksTab> createState() => _AdminTracksTabState();
}

class _AdminTracksTabState extends State<AdminTracksTab> {
  void _showAddTrackModal(BuildContext context, DataService data) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'حديث');
    final totalCtrl = TextEditingController(text: '42');
    final pointsCtrl = TextEditingController(text: '3');
    String category = 'hadith';
    String targetScope = 'all';
    final halaqat = data.getHalaqat(mosqueId: widget.mosque.id);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          title: Text('إضافة منهج / متن جديد 📚', style: AppTypography.dialogTitle(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنهج أو المتن *',
                    hintText: 'مثال: الأربعون النووية، متن الجزرية',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetScope,
                  decoration: const InputDecoration(
                    labelText: 'تخصيص المنهج والحلقات المستهدفة *',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('جميع حلقات المسجد (عام للكل)', style: AppTypography.bodyRegular(context)),
                    ),
                    ...halaqat.map((h) => DropdownMenuItem(
                      value: h.id,
                      child: Text('خاص بحلقة: ${h.name}', style: AppTypography.bodyRegular(context)),
                    )),
                  ],
                  onChanged: (v) => setMState(() => targetScope = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: [
                    DropdownMenuItem(value: 'hadith', child: Text('حديث شريف', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'matn', child: Text('متن علمي / شعر', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'fiqh', child: Text('فقه وعقيدة', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'adhkar', child: Text('أذكار وآداب', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'custom', child: Text('أخرى', style: AppTypography.bodyRegular(context))),
                  ],
                  onChanged: (v) => setMState(() => category = v ?? 'hadith'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'مسمى الوحدة (حديث / بيت / صفحة / سؤال)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: totalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'إجمالي الوحدات'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pointsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'النقاط لكل وحدة'),
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
                if (name.isEmpty) return;
                data.addRecitationTrack(
                  mosqueId: widget.mosque.id,
                  name: name,
                  category: category,
                  unitLabel: unitCtrl.text.trim(),
                  totalUnits: int.tryParse(totalCtrl.text.trim()) ?? 40,
                  pointsPerUnit: int.tryParse(pointsCtrl.text.trim()) ?? 2,
                  targetHalaqaIds: targetScope == 'all' ? const [] : [targetScope],
                );
                Navigator.pop(ctx);
              },
              child: Text('إضافة المنهج', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTrackModal(BuildContext context, DataService data, RecitationTrack track) {
    final nameCtrl = TextEditingController(text: track.name);
    final unitCtrl = TextEditingController(text: track.unitLabel);
    final totalCtrl = TextEditingController(text: track.totalUnits.toString());
    final pointsCtrl = TextEditingController(text: track.pointsPerUnit.toString());
    String targetScope = track.targetHalaqaIds.isEmpty ? 'all' : track.targetHalaqaIds.first;
    final halaqat = data.getHalaqat(mosqueId: widget.mosque.id);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          title: Text('تعديل المنهج', style: AppTypography.dialogTitle(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنهج *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetScope,
                  decoration: const InputDecoration(labelText: 'تخصيص المنهج والحلقات'),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('جميع حلقات المسجد (عام للكل)', style: AppTypography.bodyRegular(context)),
                    ),
                    ...halaqat.map((h) => DropdownMenuItem(
                      value: h.id,
                      child: Text('خاص بحلقة: ${h.name}', style: AppTypography.bodyRegular(context)),
                    )),
                  ],
                  onChanged: (v) => setMState(() => targetScope = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'مسمى الوحدة')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: totalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'إجمالي الوحدات'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: pointsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'النقاط لكل وحدة'),
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
                if (name.isEmpty) return;
                track.name = name;
                track.unitLabel = unitCtrl.text.trim();
                track.totalUnits = int.tryParse(totalCtrl.text.trim()) ?? track.totalUnits;
                track.pointsPerUnit = int.tryParse(pointsCtrl.text.trim()) ?? track.pointsPerUnit;
                track.targetHalaqaIds = targetScope == 'all' ? const [] : [targetScope];
                data.updateRecitationTrack(track);
                Navigator.pop(ctx);
              },
              child: Text('حفظ', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTrack(BuildContext context, DataService data, RecitationTrack track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد حذف المنهج', style: AppTypography.dialogTitle(context)),
        content: Text(
          'هل أنت متأكد من حذف المنهج "${track.name}"؟',
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
              data.deleteRecitationTrack(track.id);
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
    final tracks = data.getRecitationTracks(mosqueId: widget.mosque.id, activeOnly: false);
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
                'المناهج والمتون المعتمدة (${tracks.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTrackModal(context, data),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة منهج / متن جديد 📚', style: AppTypography.buttonText()),
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

        // Verve Minimal Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'تتيح للمشايخ تسميع متون، أحاديث، وكتب مع احتساب نقاط ومتابعة تقدم مستقل لكل طالب.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: tracks.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد مناهج أو متون مسجلة',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final trk = tracks[idx];
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    final actionsWidget = trk.isDefaultQuran
                        ? const SizedBox(width: 48)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'تعديل',
                                icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
                                onPressed: () => _showEditTrackModal(context, data, trk),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _confirmDeleteTrack(context, data, trk),
                              ),
                            ],
                          );

                    final detailsColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإجمالي: ${trk.totalUnits} ${trk.unitLabel} • ${trk.pointsPerUnit} نقطة لكل ${trk.unitLabel}',
                          style: AppTypography.bodyRegular(context),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (trk.isDefaultQuran)
                              UnifiedBadge(
                                label: 'المنهج الأساسي للمسجد',
                                backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                                textColor: AppColors.terracottaPrimary,
                              )
                            else
                              UnifiedBadge(
                                label: trk.category == 'hadith' ? 'حديث شريف' : 'متن علمي',
                                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                                textColor: AppColors.goldDark,
                              ),
                          ],
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
                                      trk.name,
                                      style: AppTypography.verveTitle(context),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      trk.targetHalaqaIds.isEmpty
                                          ? 'عام لجميع حلقات المسجد'
                                          : 'مخصص لحلقات محددة',
                                      style: AppTypography.verveSubtitle(context),
                                    ),
                                  ],
                                ),
                              ),
                              actionsWidget,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 38),
                            child: detailsColumn,
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

                        // Track Title & Category
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trk.name,
                                style: AppTypography.verveTitle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trk.targetHalaqaIds.isEmpty
                                    ? 'عام لجميع حلقات المسجد'
                                    : 'مخصص لحلقات محددة',
                                style: AppTypography.verveSubtitle(context),
                              ),
                            ],
                          ),
                        ),

                        // Scope Badges & Units
                        Expanded(
                          flex: 4,
                          child: detailsColumn,
                        ),

                        // Actions
                        actionsWidget,
                      ],
                    );
                  },
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