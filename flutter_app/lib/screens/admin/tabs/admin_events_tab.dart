import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../discover/dialogs/discover_event_dialog.dart';
import '../../discover/widgets/discover_event_management_view.dart';

class AdminEventsTab extends StatefulWidget {
  final Mosque mosque;
  final bool isDark;

  const AdminEventsTab({
    super.key,
    required this.mosque,
    this.isDark = false,
  });

  @override
  State<AdminEventsTab> createState() => _AdminEventsTabState();
}

class _AdminEventsTabState extends State<AdminEventsTab> {
  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Create a virtual session for management
    final session = ActiveSession(
      role: 'mosque_admin',
      code: widget.mosque.accessCode,
      name: 'إدارة ${widget.mosque.name}',
      mosqueId: widget.mosque.id,
      mosqueName: widget.mosque.name,
      gender: widget.mosque.gender,
    );

    final mosqueEvents = data.getCommunityEvents().where((e) => e.mosqueId == widget.mosque.id && e.eventStatus != 'archived').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الدروس والفعاليات العامة للمسجد (${mosqueEvents.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () => DiscoverEventDialog.showAdminAddPublicEventModal(
                  context,
                  data,
                  session,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text('إعلان عن درس / مجلس', style: AppTypography.buttonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
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
            'مواعيد مجالس العلم، دورات التجويد، والدروس الفقهية المرتبطة بمواقيت الصلاة والمتاحة للمصلين.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Unified Management View
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