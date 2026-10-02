import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/library_book.dart';
import '../../services/library_service.dart';
import '../discover/widgets/hadith_encyclopedia_view.dart';
import 'widgets/book_detail_sheet.dart';

/// Comprehensive Viewer Screen for the Core Hadith Books:
/// - Sahih al-Bukhari (7,589 Hadiths)
/// - Sahih Muslim (7,563 Hadiths)
/// - Riyadh as-Salihin (Enriched Chapters)
/// - Al-Arba'in an-Nawawiyyah (42 Hadiths)
/// - Al-Ahadith al-Qudsiyyah (40 Hadiths)
///
/// Features the authentic, highly appreciated Hadith Reader UI
/// with full search, chapter filters, font adjustment, narrator/sanad details,
/// and instant copy/share functionality.
class HadithBookViewerScreen extends StatelessWidget {
  final LibraryBook book;

  const HadithBookViewerScreen({super.key, required this.book});

  String _resolveHadithBookKey(LibraryBook b) {
    if (b.hadithBookKey != null && b.hadithBookKey!.isNotEmpty) {
      return b.hadithBookKey!;
    }
    switch (b.id) {
      case 'sahih_bukhari':
        return 'bukhari';
      case 'sahih_muslim':
        return 'muslim';
      case 'riyad_salihin':
        return 'riyad';
      case 'arbaeen_nawawi':
        return 'nawawi';
      case 'qudsi_hadiths':
        return 'qudsi';
      default:
        return 'bukhari';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bookKey = _resolveHadithBookKey(book);
    final libraryService = LibraryService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: AppTypography.font(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              book.author,
              style: AppTypography.font(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: libraryService,
            builder: (context, _) {
              final isFav = libraryService.isFavorite(book.id);
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? AppColors.goldBright : null,
                ),
                tooltip: isFav ? 'في المفضلة' : 'إضافة للمفضلة',
                onPressed: () => libraryService.toggleFavorite(book.id),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'معلومات عن الكتاب',
            onPressed: () => BookDetailSheet.show(context, book: book, isDark: isDark),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Book Banner with Author & Hadith Count
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_stories_rounded, color: primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.shortTitle,
                                style: AppTypography.font(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                book.description,
                                style: AppTypography.font(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // The Authentic Hadith Encyclopedia Engine pre-selected to this book
                  HadithEncyclopediaView(
                    isDark: isDark,
                    initialBook: bookKey,
                    showBookSelector: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
