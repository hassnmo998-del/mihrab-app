import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../sheikh/dialogs/sheikh_trip_form_dialog.dart';

class AdminTripsTab extends StatefulWidget {
  final Mosque mosque;
  final List<Halaqa> halaqat;
  final List<Student> students;
  final List<Sheikh> sheikhs;
  final bool isDark;

  const AdminTripsTab({
    super.key,
    required this.mosque,
    required this.halaqat,
    required this.students,
    required this.sheikhs,
    this.isDark = false,
  });

  @override
  State<AdminTripsTab> createState() => _AdminTripsTabState();
}

class _AdminTripsTabState extends State<AdminTripsTab> {
  void _openTripDialog(BuildContext context, DataService data, [Trip? trip]) {
    if (widget.sheikhs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة محفظ واحد على الأقل للمسجد لتتمكن من تنظيم رحلة')),
      );
      return;
    }

    final dummySheikh = widget.sheikhs.first;

    showSheikhTripFormDialog(
      context,
      data,
      dummySheikh,
      widget.students,
      widget.halaqat,
      widget.sheikhs,
      trip: trip,
      onSaved: () => setState(() {}),
    );
  }

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
    final trips = data.getTrips(mosqueId: widget.mosque.id);
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
                'رحلات وأنشطة المسجد (${trips.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => _openTripDialog(context, data),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة رحلة جديدة 🚌', style: AppTypography.buttonText()),
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
            'تنظيم خرجات تربوية وترفيهية، وتحديد المواعيد ومتطلبات الطالب وحقيبة الأنشطة لتظهر لأولياء الأمور مباشرة.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimal List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: trips.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد رحلات أو خرجات مجدولة حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final t = trips[idx];
              final tripDateStr = '${t.tripDate.year}/${t.tripDate.month}/${t.tripDate.day}';
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final serialWidget = SizedBox(
                    width: isNarrow ? 36 : 48,
                    child: Text(
                      serialNumber,
                      style: AppTypography.verveNumber(context),
                    ),
                  );

                  final titleWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: AppTypography.verveTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الوجهة: ${t.destination} • الموعد: $tripDateStr',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  );

                  final badgesWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التجمع: ${t.meetingTime}',
                        style: AppTypography.bodyRegular(context),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          UnifiedBadge(
                            label: t.isUpcoming ? 'رحلة قادمة 🚀' : 'مكتملة',
                            backgroundColor: t.isUpcoming
                                ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.15),
                            textColor: t.isUpcoming ? AppColors.terracottaPrimary : Colors.grey,
                          ),
                          if (t.requiredItems.isNotEmpty)
                            UnifiedBadge(
                              label: '🎒 ${t.requiredItems}',
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
                        tooltip: 'تعديل الرحلة',
                        icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
                        onPressed: () => _openTripDialog(context, data, t),
                      ),
                      IconButton(
                        tooltip: 'حذف الرحلة',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDeleteTrip(context, data, t),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              serialWidget,
                              const SizedBox(width: 8),
                              Expanded(child: titleWidget),
                              actionsWidget,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 44),
                            child: badgesWidget,
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        serialWidget,
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: titleWidget),
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
