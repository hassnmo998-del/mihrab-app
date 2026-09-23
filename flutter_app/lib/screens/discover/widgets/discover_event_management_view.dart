import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';
import '../dialogs/discover_event_dialog.dart';

class DiscoverEventManagementView extends StatelessWidget {
  final ActiveSession session;
  final bool isDark;

  const DiscoverEventManagementView({
    super.key,
    required this.session,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final allEvents = data.getCommunityEvents();

    List<CommunityEvent> filteredEvents;
    if (session.role == 'mosque_admin') {
      // Admin sees all events for their mosque (excluding archived snapshots)
      filteredEvents = allEvents.where((e) => e.mosqueId == session.mosqueId && e.eventStatus != 'archived').toList();
    } else if (session.role == 'sheikh') {
      // Sheikh sees events they give, alone or in a group lesson (excluding archived snapshots)
      filteredEvents = allEvents
          .where((e) => e.involvesSheikh(sheikhId: session.sheikhId, name: session.name) && e.eventStatus != 'archived')
          .toList();
    } else {
      filteredEvents = [];
    }

    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: filteredEvents.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد دروس عامة لإدارتها حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredEvents.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
                final ev = filteredEvents[idx];
                final serialNumber = (idx + 1).toString().padLeft(2, '0');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(serialNumber, style: AppTypography.verveNumber(context)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ev.title, style: AppTypography.verveTitle(context)),
                            const SizedBox(height: 4),
                            Text(
                              '${ev.timingDescription}${session.role == "mosque_admin" ? " • المحاضر: ${ev.organizerName}" : ""}',
                              style: AppTypography.bodyRegular(context),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                UnifiedBadge(
                                  label: ev.displayCategory,
                                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                                  textColor: AppColors.goldDark,
                                ),
                                UnifiedBadge(
                                  label: ev.isActive ? 'منشور للجمهور' : 'ملغى / موقوف',
                                  backgroundColor: ev.isActive
                                      ? AppColors.emeraldPrimary.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  textColor: ev.isActive ? AppColors.emeraldPrimary : Colors.redAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            children: [
                              Switch(
                                value: ev.isActive,
                                activeThumbColor: AppColors.emeraldPrimary,
                                onChanged: (_) => data.toggleEventStatus(ev.id),
                              ),
                              Text(
                                ev.isActive ? 'إيقاف' : 'تفعيل',
                                style: AppTypography.font(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'تعديل',
                            icon: Icon(Icons.edit_outlined, color: AppTheme.gold),
                            onPressed: () => DiscoverEventDialog.showEditPublicEventModal(
                              context,
                              data,
                              ev,
                              isFromAdmin: session.role == 'mosque_admin',
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              // التحقق من الصلاحية: الشيخ لا يحذف إلا دروسه هو
                              final isOwnEvent = session.role == 'sheikh'
                                  ? ev.involvesSheikh(sheikhId: session.sheikhId, name: session.name)
                                  : true; // mosque_admin يمكنه حذف أي حدث في مسجده
                              if (!isOwnEvent) return;

                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Text(
                                    'هل أنت متأكد من حذف درس "${ev.title}"؟\nلا يمكن التراجع عن هذا الإجراء.',
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('إلغاء'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        data.deleteCommunityEvent(ev.id);
                                      },
                                      child: const Text('حذف نهائياً', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
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