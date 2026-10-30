import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/help_videos_data.dart';
import 'help_center_screen.dart';
import 'widgets/help_video_player.dart';

/// يفتح فيديو رتبة فوراً ويبدأ تشغيله (زر «شاهد فيديو الرتبة» في بطاقات البوابة).
Future<void> showHelpVideo(BuildContext context, String videoId) {
  final video = HelpVideos.byId(videoId);
  if (video == null) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      backgroundColor: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: LayoutBuilder(
        builder: (ctx, box) {
          // الفيديو عمودي: عرضه ما تتسع له الشاشة طولاً بعد العنوان والزر
          final chrome = 150.0;
          final width = (box.maxWidth - 28).clamp(0.0, 400.0).toDouble();
          final byHeight = (MediaQuery.sizeOf(ctx).height - 36 - chrome) * video.aspectRatio;
          final playerWidth = width < byHeight ? width : byHeight.clamp(160.0, 400.0).toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(video.title, style: AppTypography.font(fontSize: 16.5, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: SizedBox(width: playerWidth, child: HelpVideoPlayer(video: video, autoplay: true)),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
                  },
                  icon: const Icon(Icons.video_library_outlined, size: 18),
                  label: Text('كل الفيديوهات التعليمية', style: AppTypography.font(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
