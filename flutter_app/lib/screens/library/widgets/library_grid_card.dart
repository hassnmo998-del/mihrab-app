import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/library_book.dart';
import '../../../services/library_service.dart';
import '../library_navigation.dart';
import 'book_detail_sheet.dart';
import 'realistic_book_cover.dart';

/// مقاسات خانة الكتاب على الرف، محسوبة مرة واحدة من عرض الشاشة.
///
/// كل ارتفاع نصي محجوز سلفاً بعدد أسطره (وبتكبير خط النظام حتى [maxTextScale])،
/// فالعنوان الطويل يُختصر بـ "…" داخل مكانه ولا يدفع ما تحته ولا يخرج من الخانة.
class LibraryShelfMetrics {
  static const double maxTextScale = 1.3;
  static const double shelfHeight = 9;
  static const double _topPadding = 12;
  static const double _bottomPadding = 8;
  static const double _coverToText = 9;

  final int columns;
  final double tileWidth;
  final double coverWidth;
  final double coverHeight;
  final double titleSize;
  final double titleBox;
  final double authorBox;
  final double metaBox;

  /// ارتفاع الخانة كاملة.
  final double extent;

  const LibraryShelfMetrics._({
    required this.columns,
    required this.tileWidth,
    required this.coverWidth,
    required this.coverHeight,
    required this.titleSize,
    required this.titleBox,
    required this.authorBox,
    required this.metaBox,
    required this.extent,
  });

  static const double authorSize = 10.5;
  static const double metaSize = 10;

  factory LibraryShelfMetrics.forWidth(double available, TextScaler scaler) {
    // الهاتف ثلاثة كتب في الصف (واثنان في الشاشات الضيقة جداً)، واللابتوب ستة إلى ثمانية
    final target = available < 600 ? 108.0 : (available < 1000 ? 150.0 : 172.0);
    final columns = math.max(2, (available / target).floor());
    final tileWidth = available / columns;

    final coverWidth = math.min(tileWidth * 0.76, 132.0);
    final coverHeight = coverWidth / RealisticBookCover.aspectRatio;
    final titleSize = tileWidth < 135 ? 12.0 : 13.5;

    final clamped = scaler.clamp(maxScaleFactor: maxTextScale);
    double lines(double fontSize, double height, int count) =>
        (clamped.scale(fontSize) * height * count).ceilToDouble() + 1;

    final titleBox = lines(titleSize, 1.4, 2);
    final authorBox = lines(authorSize, 1.5, 1);
    final metaBox = lines(metaSize, 1.5, 1);

    return LibraryShelfMetrics._(
      columns: columns,
      tileWidth: tileWidth,
      coverWidth: coverWidth,
      coverHeight: coverHeight,
      titleSize: titleSize,
      titleBox: titleBox,
      authorBox: authorBox,
      metaBox: metaBox,
      extent: _topPadding +
          coverHeight +
          shelfHeight +
          _coverToText +
          titleBox +
          authorBox +
          2 +
          metaBox +
          _bottomPadding,
    );
  }
}

/// كتاب واقف على الرف: الغلاف، وتحته العنوان والمؤلف وعدد الصفحات أو نسبة القراءة.
/// الضغط يفتح الكتاب، والضغط المطوّل (أو الزر الأيمن) يفتح بطاقته.
///
/// [book] الفارغ خانة بلا كتاب تكمل الرف إلى آخر الصف.
class LibraryGridCard extends StatelessWidget {
  final LibraryBook? book;
  final bool isDark;
  final LibraryShelfMetrics metrics;

  /// أول الصف وآخره: يُدوَّر عندهما طرف الرف.
  final bool isRowStart;
  final bool isRowEnd;

  const LibraryGridCard({
    super.key,
    required this.book,
    required this.isDark,
    required this.metrics,
    this.isRowStart = false,
    this.isRowEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final book = this.book;
    final shelf = Positioned(
      left: 0,
      right: 0,
      top: LibraryShelfMetrics._topPadding + metrics.coverHeight,
      height: LibraryShelfMetrics.shelfHeight,
      child: _ShelfBoard(isDark: isDark, roundStart: isRowStart, roundEnd: isRowEnd),
    );

    if (book == null) {
      return SizedBox(height: metrics.extent, child: Stack(children: [shelf]));
    }

    final library = LibraryService();
    final isFav = library.isFavorite(book.id);
    final lastPage = library.getLastReadPage(book.id);
    final started = lastPage > 1;
    final progress = library.getProgress(book.id, book.totalPages);
    final onDevice = book.isCloud && library.isDownloaded(book.id);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    void showDetails() => BookDetailSheet.show(context, book: book, isDark: isDark);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: LibraryShelfMetrics.maxTextScale,
      child: SizedBox(
        height: metrics.extent,
        child: Stack(
          children: [
            shelf,
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => openLibraryBook(context, book),
                  onLongPress: showDetails,
                  onSecondaryTap: showDetails,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      6,
                      LibraryShelfMetrics._topPadding,
                      6,
                      LibraryShelfMetrics._bottomPadding,
                    ),
                    child: Column(
                      children: [
                        _buildCover(book, isFav, started, onDevice, library),
                        const SizedBox(
                          height: LibraryShelfMetrics.shelfHeight + LibraryShelfMetrics._coverToText,
                        ),
                        // المكان محجوز لسطرَي عنوان ثم المؤلف ثم السطر الأخير؛
                        // العنوان القصير يترك فراغه في آخر الخانة لا بين الأسطر
                        SizedBox(
                          height: metrics.titleBox + metrics.authorBox + 2 + metrics.metaBox,
                          child: Column(
                            children: [
                              Text(
                                book.shortTitle,
                                style: AppTypography.font(
                                  fontSize: metrics.titleSize,
                                  fontWeight: FontWeight.bold,
                                  height: 1.4,
                                  color: textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                book.author.split('(').first.trim(),
                                style: AppTypography.font(
                                  fontSize: LibraryShelfMetrics.authorSize,
                                  height: 1.5,
                                  color: secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: metrics.metaBox,
                                child: started
                                    ? _buildProgress(progress, secondary)
                                    : Text(
                                        '${book.totalPages} صفحة',
                                        style: AppTypography.font(
                                          fontSize: LibraryShelfMetrics.metaSize,
                                          height: 1.5,
                                          color: secondary.withValues(alpha: 0.8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(LibraryBook book, bool isFav, bool started, bool onDevice, LibraryService library) {
    return SizedBox(
      width: metrics.coverWidth,
      height: metrics.coverHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RealisticBookCover(
            book: book,
            width: metrics.coverWidth,
            height: metrics.coverHeight,
            showRibbon: started,
            isBookmarked: isFav,
            elevation: 5,
          ),
          PositionedDirectional(
            top: -7,
            end: -7,
            child: _CoverBadge(
              icon: isFav ? Icons.star_rounded : Icons.star_border_rounded,
              background: isFav ? AppColors.goldBright : Colors.black.withValues(alpha: 0.55),
              foreground: isFav ? const Color(0xFF3A2A00) : Colors.white70,
              tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
              onTap: () => library.toggleFavorite(book.id),
            ),
          ),
          if (onDevice)
            PositionedDirectional(
              top: -7,
              start: -7,
              child: _CoverBadge(
                icon: Icons.download_done_rounded,
                background: AppColors.emeraldSuccess,
                foreground: Colors.white,
                tooltip: 'منزّل على الجهاز',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(double progress, Color secondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldDark),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(progress * 100).round()}%',
          style: AppTypography.font(
            fontSize: LibraryShelfMetrics.metaSize,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: AppColors.goldDark,
          ),
        ),
      ],
    );
  }
}

class _CoverBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback? onTap;

  const _CoverBadge({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
      ),
      child: Icon(icon, size: 15, color: foreground),
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? badge
          : InkResponse(onTap: onTap, radius: 18, child: badge),
    );
  }
}

/// لوح الرف الذي تقف عليه الكتب؛ كل خانة ترسم قطعتها فيتصل اللوح على طول الصف.
class _ShelfBoard extends StatelessWidget {
  final bool isDark;
  final bool roundStart;
  final bool roundEnd;

  const _ShelfBoard({required this.isDark, required this.roundStart, required this.roundEnd});

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(4);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.horizontal(
          start: roundStart ? radius : Radius.zero,
          end: roundEnd ? radius : Radius.zero,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF5A4532), Color(0xFF3A2B1F), Color(0xFF241A12)]
              : const [Color(0xFFE2CBA5), Color(0xFFC9AC80), Color(0xFFA98C62)],
          stops: const [0.0, 0.25, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
