import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/models.dart';
import '../../../../widgets/app_user_avatar.dart';
import '../models/poster_design_config.dart';

class RankedStudentEntry {
  final int rank;
  final Student student;
  final String? halaqaName;
  final int score;

  const RankedStudentEntry({
    required this.rank,
    required this.student,
    this.halaqaName,
    required this.score,
  });
}

class HonorPosterRenderView extends StatelessWidget {
  final String mosqueName;
  final List<RankedStudentEntry> students;
  final PosterDesignConfig config;
  final String? competitionTitle;

  const HonorPosterRenderView({
    super.key,
    required this.mosqueName,
    required this.students,
    required this.config,
    this.competitionTitle,
  });

  Color _getPrimaryColor() {
    switch (config.themeVariant) {
      case PosterThemeVariant.ministerialGold:
        return AppColors.goldDark;
      case PosterThemeVariant.quranicEmerald:
        return AppColors.emeraldPrimary;
      case PosterThemeVariant.executiveDark:
        return const Color(0xFFC5A059);
    }
  }

  Color _getBgColor() {
    switch (config.themeVariant) {
      case PosterThemeVariant.ministerialGold:
        return const Color(0xFFFCFBF8);
      case PosterThemeVariant.quranicEmerald:
        return const Color(0xFF0F261F);
      case PosterThemeVariant.executiveDark:
        return const Color(0xFF140D13);
    }
  }

  bool _isDarkBg() {
    return config.themeVariant == PosterThemeVariant.executiveDark ||
        config.themeVariant == PosterThemeVariant.quranicEmerald;
  }

  @override
  Widget build(BuildContext context) {
    final isStory = config.aspectRatio == PosterAspectRatio.story9x16;
    // Dimensions tuned for optimal crispness in canvas capture
    final width = isStory ? 380.0 : 440.0;
    final height = isStory ? 675.0 : 440.0;

    final primary = _getPrimaryColor();
    final bgColor = _getBgColor();
    final isDark = _isDarkBg();
    final textColor = isDark ? Colors.white : AppColors.obsidianEspresso;
    final borderColor = AppColors.gold;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            // Inner decorative border frame
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Official Header
                  _buildHeader(primary, isDark),
                  const SizedBox(height: 10),

                  // Main Poster Body
                  Expanded(
                    child: _buildPosterContent(primary, textColor, isDark),
                  ),

                  // Footer Institutional Seal
                  _buildFooter(primary, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary, bool isDark) {
    return Column(
      children: [
        if (config.showMinistryHeader && config.ministryHeader.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_rounded, color: AppColors.goldLight, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  config.ministryHeader,
                  style: AppTypography.font(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.goldBright : AppColors.goldDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.stars_rounded, color: AppColors.goldLight, size: 16),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text(
          config.title,
          style: AppTypography.font(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.obsidianEspresso,
          ),
          textAlign: TextAlign.center,
        ),
        if (competitionTitle != null && competitionTitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'مسابقة: $competitionTitle',
              style: AppTypography.font(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.goldLight),
            ),
          ),
        ] else if (config.subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            config.subtitle,
            style: AppTypography.font(
              fontSize: 10.5,
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPosterContent(Color primary, Color textColor, bool isDark) {
    if (students.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات طلاب متطابقة مع الفلاتر المحددة',
          style: AppTypography.font(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
        ),
      );
    }

    if (config.layoutType == PosterLayoutType.singleSpotlight) {
      return _buildSingleSpotlight(students.first, primary, textColor, isDark);
    }

    if (config.layoutType == PosterLayoutType.podiumTop3) {
      return _buildPodiumView(primary, textColor, isDark);
    }

    return _buildRankedListView(primary, textColor, isDark);
  }

  Widget _buildSingleSpotlight(RankedStudentEntry entry, Color primary, Color textColor, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gold Wreath / Medal Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.goldBright, AppColors.goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),

            // Student Photo
            if (config.showStudentAvatar) ...[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldBright, width: 3),
                ),
                child: AppUserAvatar(
                  name: entry.student.fullName,
                  imageUrl: entry.student.profileImageUrl,
                  radius: 38,
                ),
              ),
              const SizedBox(height: 10),
            ],

            Text(
              entry.student.fullName,
              style: AppTypography.font(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            if (config.showHalaqaName && entry.halaqaName != null)
              Text(
                'حلقة: ${entry.halaqaName}',
                style: AppTypography.font(
                  fontSize: 12,
                  color: isDark ? AppColors.goldLight : primary,
                  fontWeight: FontWeight.w600,
                ),
              ),

            if (config.showPoints) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'المجموع: ${entry.score} نقطة تفوق 🌟',
                  style: AppTypography.font(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.goldBright : AppColors.goldDark,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '«مبارك هذا التميز ومزيداً من الارتقاء في مدارج القرآن الكريم»',
              style: AppTypography.font(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
              ).copyWith(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumView(Color primary, Color textColor, bool isDark) {
    final top3 = students.take(3).toList();
    RankedStudentEntry? first = top3.isNotEmpty ? top3[0] : null;
    RankedStudentEntry? second = top3.length > 1 ? top3[1] : null;
    RankedStudentEntry? third = top3.length > 2 ? top3[2] : null;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place (Silver)
          if (second != null)
            Expanded(child: _buildPodiumStep(second, 2, 110, const Color(0xFFB8B3AD), textColor, isDark)),

          // 1st Place (Gold - Tallest)
          if (first != null)
            Expanded(child: _buildPodiumStep(first, 1, 140, AppColors.goldBright, textColor, isDark)),

          // 3rd Place (Bronze)
          if (third != null)
            Expanded(child: _buildPodiumStep(third, 3, 90, const Color(0xFFBA6E46), textColor, isDark)),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(
    RankedStudentEntry entry,
    int rank,
    double pedestalHeight,
    Color medalColor,
    Color textColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Crown for 1st
          if (rank == 1)
            Icon(Icons.workspace_premium, color: AppColors.goldLight, size: 24),

          // Avatar
          if (config.showStudentAvatar)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medalColor, width: rank == 1 ? 2.5 : 1.8),
              ),
              child: AppUserAvatar(
                name: entry.student.fullName,
                imageUrl: entry.student.profileImageUrl,
                radius: rank == 1 ? 24 : 20,
              ),
            ),
          const SizedBox(height: 4),

          // Name
          Text(
            entry.student.fullName,
            style: AppTypography.font(
              fontSize: rank == 1 ? 12.5 : 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (config.showPoints)
            Text(
              '${entry.score} ن',
              style: AppTypography.font(
                fontSize: 10,
                color: medalColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 4),

          // Pedestal
          Container(
            height: pedestalHeight * 0.75,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  medalColor.withValues(alpha: isDark ? 0.3 : 0.8),
                  medalColor.withValues(alpha: isDark ? 0.15 : 0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: medalColor.withValues(alpha: 0.7)),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AppTypography.font(
                  fontSize: rank == 1 ? 26 : 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedListView(Color primary, Color textColor, bool isDark) {
    final limit = config.layoutType == PosterLayoutType.honorListTop5 ? 5 : 10;
    final displayList = students.take(limit).toList();

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = displayList[index];
        final rank = item.rank;
        Color rankColor = isDark ? Colors.white60 : Colors.black54;
        if (rank == 1) rankColor = AppColors.goldBright;
        if (rank == 2) rankColor = const Color(0xFFC0C0C0);
        if (rank == 3) rankColor = const Color(0xFFCD7F32);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: rank <= 3 ? 0.08 : 0.03)
                : (rank <= 3 ? AppColors.goldSoftBg : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: rank <= 3 ? rankColor.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Rank Medal / Number
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: AppTypography.font(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? rankColor : textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Avatar
              if (config.showStudentAvatar) ...[
                AppUserAvatar(
                  name: item.student.fullName,
                  imageUrl: item.student.profileImageUrl,
                  radius: 14,
                ),
                const SizedBox(width: 8),
              ],

              // Name & Halaqa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.student.fullName,
                      style: AppTypography.font(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (config.showHalaqaName && item.halaqaName != null)
                      Text(
                        item.halaqaName!,
                        style: AppTypography.font(
                          fontSize: 9.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),

              // Points
              if (config.showPoints)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.score} ن',
                    style: AppTypography.font(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.goldBright : AppColors.goldDark,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.mosque, size: 13, color: AppColors.goldLight),
              const SizedBox(width: 4),
              Text(
                mosqueName,
                style: AppTypography.font(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                ),
              ),
            ],
          ),
          if (config.showMosqueStamp && config.stampText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                config.stampText,
                style: AppTypography.font(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.goldLight : AppColors.goldDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
