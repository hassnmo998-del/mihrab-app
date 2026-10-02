import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/book_content.dart';
import '../../../models/library_book.dart';
import '../../../services/library_service.dart';
import '../book_reader_screen.dart';
import '../hadith_book_viewer_screen.dart';
import 'realistic_book_cover.dart';

/// Modal bottom sheet displaying detailed book overview,
/// table of contents (فهرس الفصول), download controls, and reading resume button.
class BookDetailSheet extends StatefulWidget {
  final LibraryBook book;
  final bool isDark;
  final void Function(String bookKey)? onOpenHadithSearch;

  const BookDetailSheet({
    super.key,
    required this.book,
    required this.isDark,
    this.onOpenHadithSearch,
  });

  static void show(
    BuildContext context, {
    required LibraryBook book,
    required bool isDark,
    void Function(String bookKey)? onOpenHadithSearch,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookDetailSheet(
        book: book,
        isDark: isDark,
        onOpenHadithSearch: onOpenHadithSearch,
      ),
    );
  }

  @override
  State<BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends State<BookDetailSheet> {
  /// أقصى ما يُعرض من العناوين هنا؛ الفهرس الكامل داخل القارئ.
  static const int _maxTocRows = 120;

  final LibraryService _library = LibraryService();

  /// فهرس العناوين الحقيقي، للكتب التي لا تحمل فصولاً مضمّنة في تعريفها.
  Future<BookIndex?>? _indexFuture;

  LibraryBook get _book => _library.bookById(widget.book.id) ?? widget.book;
  bool get isDark => widget.isDark;

  bool get _isHadithCore =>
      _book.isInteractiveHadith ||
      _book.hadithBookKey != null ||
      _book.id == 'sahih_bukhari' ||
      _book.id == 'sahih_muslim' ||
      _book.id == 'riyad_salihin' ||
      _book.id == 'arbaeen_nawawi' ||
      _book.id == 'qudsi_hadiths';

  @override
  void initState() {
    super.initState();
    if (widget.book.chapters.isEmpty) {
      _indexFuture = _library.loadIndex(widget.book);
    }
  }

  void _openReader(int page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: _book, initialPage: page)),
    );
  }

  void _openBook(int lastPage) {
    if (!_isHadithCore) return _openReader(lastPage);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HadithBookViewerScreen(book: _book)),
    );
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _book.shortTitle;
    try {
      await _library.downloadBook(_book.id);
      messenger.showSnackBar(SnackBar(
        content: Text('تم تنزيل «$title» للقراءة بلا إنترنت 📥'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text('انقطع تنزيل «$title». ما نزل محفوظ، أعد المحاولة لإكماله.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmRemoveDownload() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف النسخة المنزّلة؟'),
        content: Text('سيبقى «${_book.shortTitle}» في المكتبة ويُقرأ عند توفر الإنترنت.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (remove == true) await _library.removeDownload(_book.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _library,
      builder: (context, _) => _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final book = _book;
    final isFav = _library.isFavorite(book.id);
    final lastPage = _library.getLastReadPage(book.id);
    final progress = _library.getProgress(book.id, book.totalPages);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Book Cover & Key Meta
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'detail_cover_${book.id}',
                        child: RealisticBookCover(
                          book: book,
                          width: 110,
                          height: 160,
                          showRibbon: lastPage > 1,
                          isBookmarked: isFav,
                          elevation: 8.0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                book.categoryName,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              book.title,
                              style: AppTypography.font(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.author,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildBadge(Icons.auto_stories_rounded, '${book.totalPages} صفحة'),
                                _buildBadge(Icons.view_list_rounded, '${book.chaptersCount} ${book.isCloud ? 'عنواناً' : 'فصول'}'),
                                _buildBadge(Icons.folder_zip_rounded, book.fileSize),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons (Resume / Read / Favorite / Download)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            lastPage > 1 ? Icons.history_edu_rounded : Icons.auto_stories_rounded,
                            size: 18,
                          ),
                          label: Text(
                            lastPage > 1 ? 'متابعة القراءة من صـ $lastPage' : 'قراءة الكتاب الآن',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openBook(lastPage),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Favorite button
                      IconButton.filledTonal(
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFav ? AppColors.goldBright : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        tooltip: isFav ? 'في المفضلة' : 'إضافة للمفضلة',
                        onPressed: () => _library.toggleFavorite(book.id),
                      ),
                      if (book.isCloud && _library.canDownload) ...[
                        const SizedBox(width: 4),
                        _buildDownloadButton(book),
                      ],
                    ],
                  ),

                  // Specialized Hadith Search Engine Button (if available)
                  if (book.isInteractiveHadith && book.hadithBookKey != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: Text('فتح في محرك البحث والتدقيق الحديثي (${book.shortTitle}) 🔍'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldDark,
                        side: BorderSide(color: AppColors.goldDark.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenHadithSearch?.call(book.hadithBookKey!);
                      },
                    ),
                  ],

                  // Progress Bar if user read something
                  if (lastPage > 1) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'موضعك الحالي في القراءة:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.goldDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'صفحة $lastPage من ${book.totalPages} • يحفظ التطبيق موضعك تلقائياً',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Book Overview / Description
                  _sectionTitle('نبذة عن الكتاب والمؤلف'),
                  const SizedBox(height: 6),
                  Text(
                    book.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.justify,
                  ),

                  const SizedBox(height: 20),

                  if (book.chapters.isNotEmpty)
                    _buildToc(
                      primary,
                      total: book.chapters.length,
                      rows: [
                        for (final ch in book.chapters)
                          (number: '${ch.index}', title: ch.title, page: ch.startPage, label: 'صـ ${ch.startPage}'),
                      ],
                    )
                  else
                    FutureBuilder<BookIndex?>(
                      future: _indexFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                          );
                        }
                        final index = snapshot.data;
                        if (index == null) return _buildTocUnavailable();
                        return _buildIndexSections(index, primary);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(LibraryBook book) {
    final progress = _library.downloadProgress(book.id);
    if (progress != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(value: progress <= 0 ? null : progress, strokeWidth: 3),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    final isDown = _library.isDownloaded(book.id);
    return IconButton.filledTonal(
      icon: Icon(
        isDown ? Icons.check_circle_rounded : Icons.download_rounded,
        color: isDown ? AppColors.emeraldPrimary : (isDark ? Colors.white70 : Colors.black87),
      ),
      tooltip: isDown ? 'منزّل على الجهاز — اضغط للحذف' : 'تنزيل للقراءة بلا إنترنت (${book.fileSize})',
      onPressed: isDown ? _confirmRemoveDownload : _download,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppTypography.font(
        fontSize: 16.5,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }

  /// الأبواب الرئيسية من فهرس الكتاب، ثم بيانات الطبعة.
  Widget _buildIndexSections(BookIndex index, Color primary) {
    // كتاب عناوينه الرئيسية قليلة جداً (عنوان الكتاب وحده مثلاً): ننزل مستوى
    var depth = 1;
    while (depth < 3 && index.toc.where((e) => e.level <= depth).length < 6) {
      depth++;
    }
    final entries = index.toc.where((e) => e.level <= depth).toList();
    final shown = entries.take(_maxTocRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown.isNotEmpty)
          _buildToc(
            primary,
            total: index.toc.length,
            rows: [
              for (var i = 0; i < shown.length; i++)
                (
                  number: '${i + 1}',
                  title: shown[i].title,
                  page: shown[i].page,
                  label: index.printLabel(shown[i].page).isEmpty
                      ? 'صـ ${shown[i].page}'
                      : index.printLabel(shown[i].page),
                ),
            ],
          ),
        if (index.toc.length > shown.length) ...[
          const SizedBox(height: 8),
          Text(
            'الفهرس الكامل (${index.toc.length} عنواناً) مع البحث داخل القارئ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
        if (index.edition.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('بيانات الطبعة'),
          const SizedBox(height: 6),
          Text(
            index.edition,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTocUnavailable() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'يظهر فهرس الكتاب عند توفر الإنترنت أو بعد تنزيله.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }

  // Table of Contents (فهرس الأبواب والفصول)
  Widget _buildToc(
    Color primary, {
    required int total,
    required List<({String number, String title, int page, String label})> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            _sectionTitle('فهرس الأبواب والفصول ($total)'),
            Text(
              'اضغط للانتقال المباشر',
              style: TextStyle(fontSize: 11.5, color: primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openReader(row.page),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        row.number,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        row.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
