import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/help_videos_data.dart';
import 'help_video_player.dart';

/// بطاقة فيديو تعليمي: العنوان، تحته الوصف، تحته الفيديو نفسه في البطاقة (يُشغَّل ويُكبَّر من مكانه).
class HelpVideoCard extends StatelessWidget {
  final HelpVideo video;

  const HelpVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: ValueKey('helpCard_${video.id}'),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  video.title,
                  style: AppTypography.font(fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: AppColors.terracottaPrimary),
                    const SizedBox(width: 4),
                    Text(
                      video.durationLabel,
                      style: AppTypography.font(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.terracottaPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            video.description,
            style: AppTypography.font(
              fontSize: 13,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: HelpVideoPlayer(video: video),
            ),
          ),
        ],
      ),
    );
  }
}
