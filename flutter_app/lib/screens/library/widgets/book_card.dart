import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/library_book.dart';
import '../../../services/library_service.dart';
import '../book_reader_screen.dart';
import 'realistic_book_cover.dart';

/// Card widget presenting a book on the shelf or in the library list.
/// Features 3D cover, progress bar, instant resume button, and quick actions.
class BookCard extends StatelessWidget {
  final LibraryBook book;
  final bool isDark;
  final VoidCallback onOpenDetails;

  const BookCard({
    super.key,
    required this.book,
    required this.isDark,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final libraryService = LibraryService();
    final isFav = libraryService.isFavorite(book.id);
    final isDown = libraryService.isDownloaded(book.id);
    final lastPage = libraryService.getLastReadPage(book.id);
    final hasStartedReading = lastPage > 1;
    final progress = libraryService.getProgress(book.id, book.totalPages);
    final primary = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openReader(context, lastPage),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Realistic 3D Physical Book Cover
                Hero(
                  tag: 'book_cover_${book.id}',
                  child: RealisticBookCover(
                    book: book,
                    width: 95,
                    height: 140,
                    showRibbon: hasStartedReading,
                    isBookmarked: isFav,
                    elevation: 5.0,
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Book Info and Reading Controls
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Category Badge & Quick Actions
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              book.categoryName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Favorite Star Button
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFav ? AppColors.goldBright : (isDark ? Colors.white38 : Colors.black38),
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                            onPressed: () => libraryService.toggleFavorite(book.id),
                          ),
                          const SizedBox(width: 8),

                          // Download / Offline Status Button
                          IconButton(
                            icon: Icon(
                              isDown ? Icons.check_circle_rounded : Icons.download_rounded,
                              color: isDown ? AppColors.emeraldPrimary : (isDark ? Colors.white38 : Colors.black38),
                              size: 20,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: isDown ? 'محفوظ للمطالعة بدون إنترنت' : 'تحميل للجهاز',
                            onPressed: () async {
                              if (!isDown) {
                                await libraryService.downloadBook(book.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم حفظ كتاب "${book.shortTitle}" للمطالعة بلا إنترنت 📥'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 4),

                          // Details Menu Button
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded, size: 20),
                            color: isDark ? Colors.white54 : Colors.black45,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'تفاصيل وفهرس الكتاب',
                            onPressed: onOpenDetails,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        book.title,
                        style: GoogleFonts.amiri(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Author
                      Text(
                        book.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Reading Progress Bar or Status
                      if (hasStartedReading) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 5,
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldDark),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'وصلت إلى صفحة $lastPage من ${book.totalPages}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Row(
                          children: [
                            Icon(Icons.menu_book_rounded, size: 13, color: isDark ? Colors.white38 : Colors.black38),
                            const SizedBox(width: 4),
                            Text(
                              '${book.totalPages} صفحة • ${book.chaptersCount} فصول',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            if (isDown)
                              Row(
                                children: [
                                  Icon(Icons.offline_pin_rounded, size: 13, color: AppColors.emeraldPrimary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'جاهز بلا إنترنت',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Action Button (Continue Reading or Start Reading)
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            hasStartedReading ? Icons.history_edu_rounded : Icons.auto_stories_rounded,
                            size: 16,
                          ),
                          label: Text(
                            hasStartedReading ? 'متابعة من صـ $lastPage ↩' : 'بدء القراءة والمطالعة',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasStartedReading ? primary : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
                            foregroundColor: hasStartedReading ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            elevation: hasStartedReading ? 1.5 : 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openReader(context, lastPage),
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
    );
  }

  void _openReader(BuildContext context, int initialPage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookReaderScreen(
          book: book,
          initialPage: initialPage,
        ),
      ),
    );
  }
}
