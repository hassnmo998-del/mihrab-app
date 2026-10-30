import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/help_videos_data.dart';
import '../../services/help_state.dart';
import 'widgets/developer_chat_tab.dart';
import 'widgets/help_video_card.dart';

/// «تعلّم استخدام التطبيق»: قسمان من الفيديوهات (للجميع، ولدليل الإدارات والرتب) وتبويب للتواصل مع المطوّر.
/// يُفتح من زر «؟» في الأعلى ومن الإعدادات (الخيار الثاني يفتح تبويب التواصل مباشرة).
class HelpCenterScreen extends StatefulWidget {
  /// 0 = الفيديوهات، 1 = التواصل مع المطوّر.
  final int initialTab;

  const HelpCenterScreen({super.key, this.initialTab = 0});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

  @override
  void initState() {
    super.initState();
    // بعد أول إطار: الإشعار أثناء البناء كان يُنبّه زر «؟» وهو يُبنى
    WidgetsBinding.instance.addPostFrameCallback((_) => HelpState.instance.markOpened());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('تعلّم استخدام التطبيق', style: AppTypography.titleBold(context, fontSize: 17)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.terracottaPrimary,
          indicatorColor: AppColors.terracottaPrimary,
          labelStyle: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: AppTypography.font(fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline_rounded), text: 'الفيديوهات التعليمية'),
            Tab(icon: Icon(Icons.support_agent_rounded), text: 'تواصل مع المطوّر'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _VideosTab(isDark: isDark),
          const DeveloperChatTab(),
        ],
      ),
    );
  }
}

class _VideosTab extends StatelessWidget {
  final bool isDark;

  const _VideosTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('helpVideosList'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'فيديوهات قصيرة تشرح كل شيء خطوة بخطوة. تعمل بلا إنترنت وتفتح فوراً.',
                  style: AppTypography.font(fontSize: 13.5, height: 1.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 18),
                const _SectionHeader(icon: Icons.mosque_outlined, title: 'تعرّف على محراب', subtitle: 'للجميع: القرآن والأذان والمكتبة والأذكار والدروس'),
                for (final v in HelpVideos.general) HelpVideoCard(video: v),
                const SizedBox(height: 10),
                const _SectionHeader(icon: Icons.admin_panel_settings_outlined, title: 'دليل الإدارات والرتب', subtitle: 'لمديري المساجد والمشايخ وأولياء الأمور وأمناء الصناديق'),
                for (final v in HelpVideos.admin) HelpVideoCard(video: v),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.terracottaPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.terracottaPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.font(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(subtitle, style: AppTypography.font(fontSize: 12, height: 1.4, color: AppColors.terracottaPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
