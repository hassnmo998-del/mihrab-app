import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';

class SheikhTracksTab extends StatefulWidget {
  final Sheikh sheikh;
  final List<Halaqa> halaqat;
  final bool isDark;
  final ValueChanged<String>? onReciteTrack;

  const SheikhTracksTab({
    super.key,
    required this.sheikh,
    required this.halaqat,
    required this.isDark,
    this.onReciteTrack,
  });

  @override
  State<SheikhTracksTab> createState() => _SheikhTracksTabState();
}

class _SheikhTracksTabState extends State<SheikhTracksTab> {
  void _showAddSheikhTrackModal(BuildContext context, DataService data) {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'حديث');
    final totalCtrl = TextEditingController(text: '40');
    final pointsCtrl = TextEditingController(text: '2');
    String category = 'hadith';
    String targetHalaqaId = widget.halaqat.isNotEmpty ? widget.halaqat.first.id : 'all';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          title: Text('إضافة منهج / متن للحلقة 📚', style: AppTypography.dialogTitle(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنهج أو المتن *',
                    hintText: 'مثال: متن الجزرية، الأربعون النووية',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetHalaqaId,
                  decoration: const InputDecoration(
                    labelText: 'الحلقة الموجه لها المنهج *',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('جميع حلقاتي', style: AppTypography.bodyRegular(context)),
                    ),
                    ...widget.halaqat.map((h) => DropdownMenuItem(
                      value: h.id,
                      child: Text('حلقة: ${h.name}', style: AppTypography.bodyRegular(context)),
                    )),
                  ],
                  onChanged: (v) => setMState(() => targetHalaqaId = v ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: [
                    DropdownMenuItem(value: 'hadith', child: Text('حديث نبوي شريف', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'matn', child: Text('متن علمي / شعر تجويد', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'fiqh', child: Text('فقه وعقيدة', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'adhkar', child: Text('أذكار وآداب', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'pages', child: Text('قراءة وحفظ صفحات', style: AppTypography.bodyRegular(context))),
                    DropdownMenuItem(value: 'custom', child: Text('تخصيص حر', style: AppTypography.bodyRegular(context))),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setMState(() {
                        category = v;
                        if (v == 'hadith') {
                          unitCtrl.text = 'حديث';
                          totalCtrl.text = '42';
                        } else if (v == 'matn') {
                          unitCtrl.text = 'بيت';
                          totalCtrl.text = '61';
                        } else if (v == 'pages') {
                          unitCtrl.text = 'صفحة';
                          totalCtrl.text = '50';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'مسمى الوحدة (حديث / بيت / صفحة)'),
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
                final tIds = targetHalaqaId == 'all'
                    ? widget.halaqat.map((h) => h.id).toList()
                    : [targetHalaqaId];
                data.addRecitationTrack(
                  mosqueId: widget.sheikh.mosqueId,
                  name: name,
                  category: category,
                  unitLabel: unitCtrl.text.trim(),
                  totalUnits: int.tryParse(totalCtrl.text.trim()) ?? 40,
                  pointsPerUnit: int.tryParse(pointsCtrl.text.trim()) ?? 2,
                  targetHalaqaIds: tIds,
                  sheikhId: widget.sheikh.id,
                );
                Navigator.pop(ctx);
                setState(() {});
              },
              child: Text('إضافة المنهج', style: AppTypography.buttonText()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSheikhTrack(BuildContext context, DataService data, RecitationTrack track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف المنهج', style: AppTypography.dialogTitle(context)),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف المنهج "${track.name}"؟',
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
              setState(() {});
            },
            child: Text('تأكيد الحذف', style: AppTypography.buttonText()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final sheikhHalaqaIds = widget.halaqat.map((h) => h.id).toSet();
    final allTracks = data.getRecitationTracks(mosqueId: widget.sheikh.mosqueId, activeOnly: false);
    final myTracks = allTracks.where((t) => t.targetHalaqaIds.isEmpty || t.targetHalaqaIds.any((id) => sheikhHalaqaIds.contains(id))).toList();
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
                'المناهج والمتون المعتمدة (${myTracks.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddSheikhTrackModal(context, data),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة منهج للحلقة', style: AppTypography.buttonText()),
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

        // Verve Minimal Note
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'إدارة ومتابعة مناهج الأحاديث والمتون والمنظومات المتاحة لطلاب حلقاتك مع رصد فوري للإنجاز.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: myTracks.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد مناهج أو متون مسجلة لحلقاتك حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: myTracks.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final trk = myTracks[idx];
              final isCreatedByMe = trk.sheikhId == widget.sheikh.id;
              final isMosqueWide = trk.targetHalaqaIds.isEmpty;
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    final actionsRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.terracottaPrimary,
                            side: BorderSide(color: AppColors.terracottaPrimary),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            if (widget.onReciteTrack != null) {
                              widget.onReciteTrack!(trk.id);
                            }
                          },
                          icon: const Icon(Icons.record_voice_over, size: 16),
                          label: Text(
                            'رصد تسميع',
                            style: AppTypography.buttonText(color: AppColors.terracottaPrimary),
                          ),
                        ),
                        if (isCreatedByMe) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'حذف المنهج',
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDeleteSheikhTrack(context, data, trk),
                          ),
                        ],
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
                                label: 'المنهج الأساسي',
                                backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                                textColor: AppColors.terracottaPrimary,
                              )
                            else
                              UnifiedBadge(
                                label: trk.category == 'hadith' ? 'حديث نبوي' : 'متن علمي',
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
                                      isMosqueWide
                                          ? 'معتمد لعموم المسجد'
                                          : 'خاص بحلقة: ${trk.targetHalaqaIds.map((id) => data.getHalaqaById(id)?.name ?? id).join("، ")}',
                                      style: AppTypography.verveSubtitle(context),
                                    ),
                                  ],
                                ),
                              ),
                              actionsRow,
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

                        // Track Name & Scope
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
                                isMosqueWide
                                    ? 'معتمد لعموم المسجد'
                                    : 'خاص بحلقة: ${trk.targetHalaqaIds.map((id) => data.getHalaqaById(id)?.name ?? id).join("، ")}',
                                style: AppTypography.verveSubtitle(context),
                              ),
                            ],
                          ),
                        ),

                        // Units & Badges
                        Expanded(
                          flex: 4,
                          child: detailsColumn,
                        ),

                        // Actions
                        actionsRow,
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