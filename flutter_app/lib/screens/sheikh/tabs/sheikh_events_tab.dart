import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../discover/dialogs/discover_event_dialog.dart';
import '../../discover/widgets/discover_event_management_view.dart';

class SheikhEventsTab extends StatelessWidget {
  final Sheikh sheikh;
  final bool isDark;

  const SheikhEventsTab({
    super.key,
    required this.sheikh,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final session = data.getSessionForRole('sheikh');
    final activeSheikh = data.getSheikhs().where((s) => s.id == sheikh.id || s.code == sheikh.code).firstOrNull;

    if (session == null || activeSheikh == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'تم إلغاء صلاحية الشيخ أو حذفه من المسجد',
                style: AppTypography.verveHeaderTitle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'لم تعد تمتلك صلاحية إدارة الدروس العامة أو إضافتها.',
                style: AppTypography.verveSubtitle(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // يشمل الدروس الجماعية التي يشارك فيها الشيخ لا التي أعلنها فقط
    final myEvents = data
        .getCommunityEvents()
        .where((e) => e.involvesSheikh(sheikhId: sheikh.id, name: sheikh.fullName) && e.eventStatus != 'archived')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إدارة دروسي العامة (${myEvents.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => DiscoverEventDialog.showSheikhAddPublicEventModal(context, data, session),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إعلان درس جديد', style: AppTypography.buttonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'هنا يمكنك التحكم في دروسك التي تظهر للعامة، تفعيلها أو إيقافها وتعديل محتواها.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: DiscoverEventManagementView(
            session: session,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}