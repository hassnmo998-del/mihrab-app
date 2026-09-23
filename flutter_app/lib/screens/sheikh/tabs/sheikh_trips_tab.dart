import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';
import '../dialogs/sheikh_trip_form_dialog.dart';

class SheikhTripsTab extends StatefulWidget {
  final Sheikh sheikh;
  final List<Student> students;
  final List<Halaqa> halaqat;
  final List<Sheikh> allSheikhs;
  final bool isDark;

  const SheikhTripsTab({
    super.key,
    required this.sheikh,
    required this.students,
    required this.halaqat,
    required this.allSheikhs,
    required this.isDark,
  });

  @override
  State<SheikhTripsTab> createState() => _SheikhTripsTabState();
}

class _SheikhTripsTabState extends State<SheikhTripsTab> {
  void _confirmDeleteTrip(BuildContext context, DataService data, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد حذف الرحلة', style: AppTypography.dialogTitle(context)),
        content: Text(
          'هل أنت متأكد من حذف رحلة "${trip.title}"؟',
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
              data.deleteTrip(trip.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الرحلة بنجاح')),
              );
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
    final trips = data.getTrips();
    final sheikhHalaqaIds = widget.halaqat.map((h) => h.id).toSet();
    final myTrips = trips
        .where((t) => t.halaqaIds.isEmpty || t.halaqaIds.any((hId) => sheikhHalaqaIds.contains(hId)))
        .toList();
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
                'رحلات وأنشطة الحلقة (${myTrips.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () => showSheikhTripFormDialog(
                  context,
                  data,
                  widget.sheikh,
                  widget.students,
                  widget.halaqat,
                  widget.allSheikhs,
                  onSaved: () => setState(() {}),
                ),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text('تنظيم رحلة جديدة 🚌', style: AppTypography.buttonText()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Verve Minimal Note
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'إدارة وتنظيم الخرجات والأنشطة الترفيهية والتثقيفية لطلاب الحلقة مع تحديد المواعيد والأغراض المطلوبة.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: myTrips.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد رحلات مجدولة لحلقتك حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: myTrips.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final trip = myTrips[idx];
              final targetedCount = trip.studentIds.isEmpty
                  ? widget.students.length
                  : widget.students.where((s) => trip.studentIds.contains(s.id)).length;
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    final actionsRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تعديل الرحلة',
                          icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
                          onPressed: () => showSheikhTripFormDialog(
                            context,
                            data,
                            widget.sheikh,
                            widget.students,
                            widget.halaqat,
                            widget.allSheikhs,
                            trip: trip,
                            onSaved: () => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف الرحلة',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDeleteTrip(context, data, trip),
                        ),
                      ],
                    );

                    final badgesColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التجمع: ${trip.meetingTime}',
                          style: AppTypography.bodyRegular(context),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            UnifiedBadge(
                              label: trip.isUpcoming ? 'رحلة قادمة 🚀' : 'مكتملة',
                              backgroundColor: trip.isUpcoming
                                  ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.15),
                              textColor: trip.isUpcoming ? AppColors.terracottaPrimary : Colors.grey,
                            ),
                            UnifiedBadge(
                              label: '$targetedCount طالب مستهدف',
                              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                              textColor: AppColors.goldDark,
                            ),
                            if (trip.requirements.isNotEmpty)
                              UnifiedBadge(
                                label: '🎒 ${trip.requirements}',
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                textColor: isDark ? Colors.white70 : AppColors.obsidianEspresso,
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
                                      trip.title,
                                      style: AppTypography.verveTitle(context),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'الوجهة: ${trip.destination} • الموعد: ${DateFormat('yyyy/MM/dd').format(trip.tripDate)}',
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
                            child: badgesColumn,
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

                        // Trip Title & Destination
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.title,
                                style: AppTypography.verveTitle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الوجهة: ${trip.destination} • الموعد: ${DateFormat('yyyy/MM/dd').format(trip.tripDate)}',
                                style: AppTypography.verveSubtitle(context),
                              ),
                            ],
                          ),
                        ),

                        // Badges & Logistics
                        Expanded(
                          flex: 4,
                          child: badgesColumn,
                        ),

                        // Clean Actions
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