import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../models/library_book.dart';
import '../../services/library_service.dart';
import 'library_navigation.dart';
import 'widgets/library_grid_card.dart';
import 'widgets/realistic_book_cover.dart';

/// شاشة المكتبة الشاملة.
///
/// - بلا تصفية: رفوف، رف لكل تصنيف يعرض كل كتبه صفاً تحت صف.
/// - مع بحث أو تصنيف مختار: شبكة بكل النتائج.
///
/// الرفوف والشبكة تُبنيان عند الظهور فقط، والتصنيفات تأتي من الفهرس نفسه،
/// فكتاب أو تصنيف جديد يُضاف في Supabase يظهر هنا بلا تعديل في التطبيق.
class LibraryScreen extends StatefulWidget {
  final bool isDark;

  const LibraryScreen({super.key, this.isDark = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const String _all = 'all';
  static const String _favorites = 'fav';
  static const String _onDevice = 'downloaded';

  /// أقصى عرض للمحتوى؛ ما زاد من الشاشة هوامش.
  static const double _maxContentWidth = 1240;

  final LibraryService _libraryService = LibraryService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selected = _all;
  String _searchQuery = '';

  /// نص البحث المطبَّع لكل كتاب، يُحسب عند أول بحث ويُعاد حسابه إن تغيّر الفهرس.
  List<LibraryBook>? _indexedBooks;
  final Map<String, String> _searchText = {};

  List<LibraryBook>? _groupedCatalog;
  Map<String, List<LibraryBook>> _grouped = {};

  @override
  void initState() {
    super.initState();
    _libraryService.init().then((_) => _libraryService.refreshIfStale());
    _searchCtrl.addListener(() {
      final query = _fold(_searchCtrl.text.trim());
      if (query != _searchQuery) setState(() => _searchQuery = query);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// يطابق بلا تشكيل وبتوحيد صور الألف والياء والتاء المربوطة.
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  bool _matchesSearch(LibraryBook book, List<LibraryBook> catalog) {
    if (!identical(_indexedBooks, catalog)) {
      _indexedBooks = catalog;
      _searchText.clear();
    }
    final text = _searchText[book.id] ??= _fold(
      '${book.title} ${book.shortTitle} ${book.author} ${book.categoryName} ${book.description}',
    );
    return text.contains(_searchQuery);
  }

  List<LibraryBook> _filter(List<LibraryBook> catalog) {
    return catalog.where((book) {
      if (_selected == _favorites) {
        if (!_libraryService.isFavorite(book.id)) return false;
      } else if (_selected == _onDevice) {
        if (!_libraryService.isDownloaded(book.id)) return false;
      } else if (_selected != _all && book.category != _selected) {
        return false;
      }
      return _searchQuery.isEmpty || _matchesSearch(book, catalog);
    }).toList();
  }

  LibraryBook? _mostRecentlyRead(List<LibraryBook> books) {
    LibraryBook? candidate;
    DateTime? candidateDate;
    for (final b in books) {
      final date = _libraryService.getLastReadDate(b.id);
      if (date == null || _libraryService.getLastReadPage(b.id) <= 1) continue;
      if (candidateDate == null || date.isAfter(candidateDate)) {
        candidate = b;
        candidateDate = date;
      }
    }
    return candidate;
  }

  void _select(String key) {
    if (_selected != key) setState(() => _selected = key);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _libraryService,
      builder: (context, _) {
        final catalog = _libraryService.books;
        final categories = _libraryService.categories;
        // تصنيف اختفى من الفهرس بعد مزامنة: نعود إلى الرفوف
        if (_selected != _all &&
            _selected != _favorites &&
            _selected != _onDevice &&
            !categories.any((c) => c.id == _selected)) {
          _selected = _all;
        }
        final showShelves = _selected == _all && _searchQuery.isEmpty;
        final results = showShelves ? const <LibraryBook>[] : _filter(catalog);
        final recent = _mostRecentlyRead(catalog);

        // فهرس كثيف: تكبير خط النظام يُحترم إلى حدّ لا يكسر الرفوف
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: LibraryShelfMetrics.maxTextScale,
          child: RefreshIndicator(
            onRefresh: _libraryService.syncWithSupabase,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = ((constraints.maxWidth - _maxContentWidth) / 2).clamp(12.0, double.infinity);
                final contentWidth = constraints.maxWidth - side * 2;
                final metrics = LibraryShelfMetrics.forWidth(contentWidth, MediaQuery.textScalerOf(context));
                final padding = EdgeInsets.symmetric(horizontal: side);

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: padding.copyWith(top: 14),
                      sliver: SliverList.list(
                        children: [
                          _LibraryBanner(
                            bookCount: catalog.length,
                            subjects: _LibraryBanner.subjectsOf(categories),
                            isSyncing: _libraryService.isLoadingRemote,
                          ),
                          const SizedBox(height: 14),
                          if (recent != null) ...[
                            _ResumeCard(book: recent, isDark: isDark),
                            const SizedBox(height: 14),
                          ],
                          _buildSearchField(isDark),
                          const SizedBox(height: 12),
                          _buildFilters(isDark, categories, wide: contentWidth >= 760),
                          const SizedBox(height: 8),
                          if (!showShelves) _buildResultsHeader(isDark, results.length),
                          if (!showShelves && results.isEmpty) _buildEmptyState(isDark),
                        ],
                      ),
                    ),
                    if (showShelves)
                      SliverPadding(
                        padding: padding,
                        sliver: _buildShelves(categories, catalog, metrics, isDark),
                      )
                    else
                      SliverPadding(
                        padding: padding,
                        sliver: _buildResultsGrid(results, metrics, isDark),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(bool isDark) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
    );
    return TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      style: AppTypography.font(
        fontSize: 13.5,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'ابحث عن كتاب أو مؤلف أو موضوع',
        hintStyle: AppTypography.font(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white54 : Colors.black45),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'مسح البحث',
                onPressed: _searchCtrl.clear,
              ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border,
        enabledBorder: border,
      ),
    );
  }

  /// على الهاتف شريط يُسحب أفقياً؛ على الشاشة العريضة تلتف الأزرار إلى أسطر
  /// لأن الفأرة لا تسحب الشريط.
  Widget _buildFilters(bool isDark, List<LibraryCategory> categories, {required bool wide}) {
    final chips = [
      _buildChip('الكل', _all, isDark),
      _buildChip('المفضلة', _favorites, isDark, icon: Icons.star_rounded),
      _buildChip('على جهازي', _onDevice, isDark, icon: Icons.download_done_rounded),
      for (final c in categories) _buildChip(c.name, c.id, isDark),
    ];
    if (wide) return Wrap(spacing: 8, runSpacing: 8, children: chips);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: chip),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String key, bool isDark, {IconData? icon}) {
    final selected = _selected == key;
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87);

    return Material(
      color: selected ? primary : (isDark ? AppColors.darkCard : Colors.white),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _select(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? Colors.white : AppColors.goldDark),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTypography.font(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsHeader(bool isDark, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        _searchQuery.isEmpty ? '$count كتاباً' : '$count نتيجة',
        style: AppTypography.font(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  /// كتب كل تصنيف بترتيب الفهرس، تُحسب مرة لكل فهرس.
  Map<String, List<LibraryBook>> _booksByCategory(List<LibraryBook> catalog) {
    if (!identical(_groupedCatalog, catalog)) {
      _groupedCatalog = catalog;
      _grouped = {};
      for (final b in catalog) {
        (_grouped[b.category] ??= []).add(b);
      }
    }
    return _grouped;
  }

  /// الرفوف كلها قائمة واحدة: لكل تصنيف عنوانه ثم صفوف كتبه كاملةً، صف تحت صف.
  /// كل عنوان وكل صف عنصر مستقل يُبنى عند ظهوره، فتصنيف من مئات الكتب لا يثقل.
  Widget _buildShelves(
    List<LibraryCategory> categories,
    List<LibraryBook> catalog,
    LibraryShelfMetrics metrics,
    bool isDark,
  ) {
    final grouped = _booksByCategory(catalog);
    // (التصنيف، رقم الصف) — الصف -1 هو العنوان
    final items = <(LibraryCategory, int)>[
      for (final category in categories) ...[
        (category, -1),
        for (var row = 0; row < (category.count / metrics.columns).ceil(); row++) (category, row),
      ],
    ];

    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (category, row) = items[i];
        if (row < 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 2),
            child: _ShelfHeader(title: category.name, count: category.count, isDark: isDark),
          );
        }
        final books = grouped[category.id] ?? const <LibraryBook>[];
        final first = row * metrics.columns;
        return Row(
          children: [
            for (var col = 0; col < metrics.columns; col++)
              Expanded(
                child: LibraryGridCard(
                  key: ValueKey(first + col < books.length ? books[first + col].id : 'empty-${category.id}-$col'),
                  book: first + col < books.length ? books[first + col] : null,
                  isDark: isDark,
                  metrics: metrics,
                  isRowStart: col == 0,
                  isRowEnd: col == metrics.columns - 1,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResultsGrid(List<LibraryBook> results, LibraryShelfMetrics metrics, bool isDark) {
    // خانات فارغة تكمل الصف الأخير ليمتد الرف إلى آخره
    final slots = (results.length / metrics.columns).ceil() * metrics.columns;
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.columns,
        mainAxisExtent: metrics.extent,
        mainAxisSpacing: 4,
      ),
      itemCount: slots,
      itemBuilder: (context, i) => LibraryGridCard(
        key: ValueKey(i < results.length ? results[i].id : 'empty-$i'),
        book: i < results.length ? results[i] : null,
        isDark: isDark,
        metrics: metrics,
        isRowStart: i % metrics.columns == 0,
        isRowEnd: i % metrics.columns == metrics.columns - 1,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final (icon, title, hint) = switch (_selected) {
      _favorites when _searchQuery.isEmpty => (
          Icons.star_border_rounded,
          'لا كتب في المفضلة بعد',
          'اضغط النجمة على غلاف أي كتاب ليظهر هنا',
        ),
      _ => (
          Icons.search_off_rounded,
          'لا توجد كتب مطابقة',
          'جرّب كلمة أخرى أو تصنيفاً آخر',
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 46, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.font(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: AppTypography.font(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }
}

/// لافتة المكتبة: العنوان وعدد الكتب وحالة المزامنة.
class _LibraryBanner extends StatelessWidget {
  final int bookCount;

  /// «في الحديث والتفسير والسيرة…» من التصنيفات الموجودة فعلاً في الفهرس.
  final String subjects;
  final bool isSyncing;

  const _LibraryBanner({required this.bookCount, required this.subjects, required this.isSyncing});

  static const Map<String, String> _subjectNames = {
    'hadith': 'الحديث',
    'tafsir': 'التفسير',
    'seerah': 'السيرة',
    'aqeedah': 'العقيدة',
    'fiqh': 'الفقه',
    'usul': 'الأصول',
    'tazkiyah': 'التزكية',
    'tarikh': 'التاريخ',
    'lugha': 'اللغة',
  };

  /// الكتب تُضاف وتُحذف بلا إصدار، فالنص يُبنى من الفهرس لا يُكتب ثابتاً.
  static String subjectsOf(List<LibraryCategory> categories) {
    final names = [
      for (final c in categories)
        if (_subjectNames[c.id] case final String name) name,
    ];
    return names.isEmpty ? '' : ' في ${names.join(' و')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.sunsetTwilightGradient,
        borderRadius: AppRadius.card,
      ),
      child: Stack(
        children: [
          // زخرفة خافتة في طرف اللافتة
          PositionedDirectional(
            end: -18,
            top: -22,
            bottom: -22,
            child: Icon(
              Icons.menu_book_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.goldBright.withValues(alpha: 0.55)),
                  ),
                  child: Icon(Icons.local_library_rounded, color: AppColors.goldBright, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المكتبة الشاملة',
                        style: AppTypography.font(
                          fontSize: 19,
                          height: 1.4,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSyncing
                            ? '$bookCount كتاباً • جارٍ البحث عن كتب جديدة…'
                            : '$bookCount كتاباً بنصوصها الكاملة$subjects',
                        style: AppTypography.font(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.88),
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
        ],
      ),
    );
  }
}

/// "تابع القراءة": آخر كتاب قُرئ، والبطاقة كلها زر.
class _ResumeCard extends StatelessWidget {
  final LibraryBook book;
  final bool isDark;

  const _ResumeCard({required this.book, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final library = LibraryService();
    final lastPage = library.getLastReadPage(book.id);
    final progress = library.getProgress(book.id, book.totalPages);
    final primary = Theme.of(context).colorScheme.primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: AppColors.goldDark.withValues(alpha: 0.4)),
    );

    return Material(
      color: isDark ? AppColors.darkCard : const Color(0xFFFBF8F1),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openLibraryBook(context, book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              RealisticBookCover(
                book: book,
                width: 50,
                height: 50 / RealisticBookCover.aspectRatio,
                showRibbon: false,
                elevation: 3,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تابع القراءة',
                      style: AppTypography.font(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.goldDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.shortTitle,
                      style: AppTypography.font(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'صفحة $lastPage من ${book.totalPages} • ${(progress * 100).round()}%',
                      style: AppTypography.font(
                        fontSize: 10.5,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// عنوان رف: اسم التصنيف وعدد كتبه.
class _ShelfHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;

  const _ShelfHeader({
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.goldDark,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        // العنوان يأخذ ما يحتاجه حتى حدود المتاح، والعدّاد ملاصق له
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.font(fontSize: 16, height: 1.4, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.font(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
