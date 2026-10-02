import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/book_content.dart';
import '../../models/library_book.dart';
import '../../services/library_service.dart';
import 'widgets/book_toc_sheet.dart';

/// قارئ الكتب: تمرير متصل عبر صفحات الكتاب كلها.
///
/// - الصفحات تُبنى عند ظهورها فقط، ونصوصها تُجلب جزءاً جزءاً، فكتاب من
///   آلاف الصفحات يفتح بسرعة كتاب من عشر.
/// - الصفحة القصيرة لا تترك شاشة فارغة: ما بعدها يتبعها مباشرة.
/// - موضع القراءة يُحفظ تلقائياً، والانتقال بالفهرس أو الشريط أو رقم الصفحة.
class BookReaderScreen extends StatefulWidget {
  final LibraryBook book;
  final int initialPage;

  const BookReaderScreen({
    super.key,
    required this.book,
    this.initialPage = 1,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  static const _fontPrefKey = 'lib2_reader_font_size';
  static const _notesPrefKey = 'lib2_reader_show_notes';
  static const double _minFont = 14, _maxFont = 32, _fontStep = 1.5;

  /// الشاشات الأعرض من هذا تُبقي الشريطين ظاهرين دائماً.
  static const double _alwaysShowBarsWidth = 720;

  /// ما انتهى فوق هذا الجزء من الشاشة لا يُعدّ "الصفحة الحالية".
  static const double _readingLine = 0.12;

  final LibraryService _library = LibraryService();
  final ItemScrollController _itemScroll = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  final ScrollOffsetController _offsetScroll = ScrollOffsetController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'book-reader');

  late final ValueNotifier<int> _page = ValueNotifier(widget.initialPage);

  BookContent? _content;
  String? _error;
  bool _isLoading = true;
  double _fontSize = 19.0;
  bool _showNotes = true;
  bool _barsVisible = true;
  double _viewportHeight = 600;

  final Set<int> _loadingChunks = {};
  final Set<int> _failedChunks = {};

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_onPositionsChanged);
    _restoreReaderPrefs();
    _open();
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onPositionsChanged);
    _library.flushProgress(notify: true);
    _page.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _restoreReaderPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _fontSize = (prefs.getDouble(_fontPrefKey) ?? _fontSize).clamp(_minFont, _maxFont);
        _showNotes = prefs.getBool(_notesPrefKey) ?? true;
      });
    } catch (_) {}
  }

  void _toggleNotes() {
    setState(() => _showNotes = !_showNotes);
    SharedPreferences.getInstance().then((p) => p.setBool(_notesPrefKey, _showNotes), onError: (_) {});
  }

  void _changeFontSize(double delta) {
    final next = (_fontSize + delta).clamp(_minFont, _maxFont);
    if (next == _fontSize) return;
    setState(() => _fontSize = next);
    SharedPreferences.getInstance().then((p) => p.setDouble(_fontPrefKey, next), onError: (_) {});
  }

  Future<void> _open() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final content = await _library.openContent(widget.book);
      if (!mounted) return;
      final start = widget.initialPage.clamp(1, content.index.pageCount);
      // الجزء الذي فيه موضع القراءة يصل قبل أول رسم، فلا يظهر هيكل فارغ
      try {
        await content.load(start);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _content = content;
        _page.value = start;
        _isLoading = false;
      });
      content.warm(start);
      _library.saveLastReadPage(widget.book.id, start, notify: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is BookUnavailableException
            ? e.message
            : 'تعذّر فتح الكتاب. أعد المحاولة بعد قليل.';
        _isLoading = false;
      });
    }
  }

  // ───────────────────────────── التنقل ─────────────────────────────

  void _onPositionsChanged() {
    final content = _content;
    final positions = _positions.itemPositions.value;
    if (content == null || positions.isEmpty) return;

    ItemPosition? top;
    for (final p in positions) {
      if (p.itemTrailingEdge <= _readingLine) continue;
      if (top == null || p.index < top.index) top = p;
    }
    top ??= positions.reduce((a, b) => a.index < b.index ? a : b);

    final page = top.index + 1;
    if (page == _page.value) return;
    _page.value = page;
    _library.saveLastReadPage(widget.book.id, page, notify: false);
    content.warm(page);
  }

  void _jumpToPage(int page) {
    final content = _content;
    if (content == null || !_itemScroll.isAttached) return;
    final target = page.clamp(1, content.index.pageCount);
    content.warm(target);
    _itemScroll.jumpTo(index: target - 1);
  }

  void _scrollBy(double fractionOfViewport) {
    _offsetScroll.animateScroll(
      offset: _viewportHeight * fractionOfViewport,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  bool _onUserScroll(UserScrollNotification n) {
    if (MediaQuery.sizeOf(context).width >= _alwaysShowBarsWidth) return false;
    if (n.direction == ScrollDirection.reverse && _barsVisible) {
      setState(() => _barsVisible = false);
    } else if (n.direction == ScrollDirection.forward && !_barsVisible) {
      setState(() => _barsVisible = true);
    }
    return false;
  }

  void _requestChunk(BookContent content, int page) {
    final chunk = content.index.chunkOf(page);
    if (_loadingChunks.contains(chunk) || _failedChunks.contains(chunk)) return;
    _loadingChunks.add(chunk);
    content.load(page).then((_) {
      _loadingChunks.remove(chunk);
      if (mounted) setState(() {});
    }, onError: (_) {
      _loadingChunks.remove(chunk);
      _failedChunks.add(chunk);
      if (mounted) setState(() {});
    });
  }

  void _retryChunk(BookContent content, int page) {
    setState(() => _failedChunks.remove(content.index.chunkOf(page)));
  }

  // ───────────────────────────── الإجراءات ─────────────────────────────

  String _pageAsText(BookContent content, int page) {
    final unit = content.peek(page);
    if (unit == null) return '';
    final label = content.index.printLabel(page);
    return 'من كتاب «${widget.book.title}»${label.isEmpty ? '' : ' ($label)'}:\n\n'
        '${unit.plainText}\n\n'
        '— عبر منصة محراب (المكتبة الشاملة)';
  }

  void _copyPage() {
    final content = _content;
    if (content == null) return;
    final text = _pageAsText(content, _page.value);
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ نص الصفحة'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sharePage() {
    final content = _content;
    if (content == null) return;
    final text = _pageAsText(content, _page.value);
    if (text.isNotEmpty) Share.share(text);
  }

  /// الكتاب السحابي قابل للتنزيل حيث يوجد نظام ملفات (لا في المتصفح).
  bool get _canDownload {
    final book = _library.bookById(widget.book.id) ?? widget.book;
    return book.isCloud && _library.canDownload;
  }

  Future<void> _downloadBook() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = widget.book.shortTitle;
    messenger.showSnackBar(SnackBar(
      content: Text('جارٍ تنزيل «$title»… يمكنك متابعة القراءة'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      await _library.downloadBook(widget.book.id);
      messenger.showSnackBar(SnackBar(
        content: Text('تم تنزيل «$title» للقراءة بلا إنترنت'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text('انقطع تنزيل «$title». ما نزل محفوظ، أعد المحاولة لإكماله.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openToc() async {
    final content = _content;
    if (content == null) return;
    final page = await BookTocSheet.show(
      context,
      index: content.index,
      currentPage: _page.value,
      bookTitle: widget.book.shortTitle,
    );
    if (page != null) _jumpToPage(page);
  }

  Future<void> _askForPage() async {
    final content = _content;
    if (content == null) return;
    final index = content.index;
    final total = index.pageCount;
    // الكتاب المرقّم على المطبوع يُنتقل فيه برقم الصفحة الورقية، وهو الظاهر في الفواصل
    final byPrint = index.hasPrintPages;
    final volume = index.volumeOf(_page.value)?.name ?? '';
    final controller = TextEditingController();
    final entered = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          final n = int.tryParse(_westernDigits(controller.text.trim()));
          Navigator.pop(dialogContext, n);
        }

        return AlertDialog(
          title: Text('الانتقال إلى صفحة', style: AppTypography.font(fontSize: 17, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: byPrint ? 'رقم الصفحة في المطبوع' : 'من 1 إلى $total',
              helperText: byPrint && index.volumes.length > 1
                  ? 'يبدأ البحث من ${int.tryParse(volume) == null ? volume : 'الجزء $volume'}'
                  : null,
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: submit, child: const Text('انتقال')),
          ],
        );
      },
    );
    if (entered == null || !mounted) return;
    final page = byPrint ? index.pageForPrint(entered, near: _page.value) : entered;
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد صفحة برقم $entered في هذا الكتاب'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _jumpToPage(page);
  }

  static String _westernDigits(String s) => s.replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString(),
      );

  // ───────────────────────────── الواجهة ─────────────────────────────

  Color _bg(bool isDark) => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color _surface(bool isDark) => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color _text(bool isDark) => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color _secondary(bool isDark) => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = _content;

    if (_isLoading) return _buildLoading(isDark);
    if (content == null) return _buildUnavailable(isDark);

    final wide = MediaQuery.sizeOf(context).width >= _alwaysShowBarsWidth;
    final showBars = wide || _barsVisible;

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.pageDown): () => _scrollBy(0.85),
            const SingleActivator(LogicalKeyboardKey.space): () => _scrollBy(0.85),
            const SingleActivator(LogicalKeyboardKey.pageUp): () => _scrollBy(-0.85),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _scrollBy(0.12),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _scrollBy(-0.12),
            const SingleActivator(LogicalKeyboardKey.home): () => _jumpToPage(1),
            const SingleActivator(LogicalKeyboardKey.end): () => _jumpToPage(content.index.pageCount),
          },
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: Column(
              children: [
                _collapsible(showBars, _buildTopBar(isDark, content)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewportHeight = constraints.maxHeight;
                      return NotificationListener<UserScrollNotification>(
                        onNotification: _onUserScroll,
                        child: SelectionArea(
                          child: ScrollablePositionedList.builder(
                            itemCount: content.index.pageCount,
                            initialScrollIndex: _page.value - 1,
                            itemScrollController: _itemScroll,
                            itemPositionsListener: _positions,
                            scrollOffsetController: _offsetScroll,
                            padding: const EdgeInsets.only(top: 10, bottom: 28),
                            itemBuilder: (context, i) => _buildPage(content, i + 1, isDark),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _collapsible(showBars, _buildBottomBar(isDark, content)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsible(bool visible, Widget child) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: visible ? child : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _buildPage(BookContent content, int page, bool isDark) {
    final unit = content.peek(page);
    final Widget child;
    if (unit != null) {
      child = _BookPageBlock(
        unit: unit,
        showNotes: _showNotes,
        printLabel: content.index.startsPrintPage(page) ? content.index.printLabel(page) : '',
        showSeparator: page > 1 && content.index.startsPrintPage(page),
        fontSize: _fontSize,
        textColor: _text(isDark),
        secondaryColor: _secondary(isDark),
        accentColor: isDark ? AppColors.goldBright : AppColors.goldDark,
        quranColor: isDark ? AppColors.goldBright : Theme.of(context).colorScheme.primary,
      );
    } else if (_failedChunks.contains(content.index.chunkOf(page))) {
      child = _PageLoadError(
        color: _secondary(isDark),
        onRetry: () => _retryChunk(content, page),
      );
    } else {
      _requestChunk(content, page);
      child = _PageSkeleton(color: _text(isDark));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, BookContent content) {
    final iconColor = _text(isDark);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: _surface(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: 'رجوع للمكتبة',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.book.shortTitle,
                  style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 15.5, color: iconColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _page,
                  builder: (context, page, _) => Text(
                    content.index.headingAt(page)?.title ?? widget.book.categoryName,
                    style: AppTypography.font(fontSize: 11.0, color: _secondary(isDark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (content.index.toc.isNotEmpty)
            IconButton(
              icon: Icon(Icons.format_list_bulleted_rounded, color: iconColor, size: 21),
              tooltip: 'فهرس الكتاب',
              onPressed: _openToc,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Text(
                    'A-',
                    style: AppTypography.font(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _fontSize > _minFont ? iconColor : iconColor.withValues(alpha: 0.3),
                    ),
                  ),
                  tooltip: 'تصغير الخط',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: _fontSize > _minFont ? () => _changeFontSize(-_fontStep) : null,
                ),
                Container(height: 14, width: 1, color: iconColor.withValues(alpha: 0.2)),
                IconButton(
                  icon: Text(
                    'A+',
                    style: AppTypography.font(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: _fontSize < _maxFont ? primary : iconColor.withValues(alpha: 0.3),
                    ),
                  ),
                  tooltip: 'تكبير الخط',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: _fontSize < _maxFont ? () => _changeFontSize(_fontStep) : null,
                ),
              ],
            ),
          ),
          PopupMenuButton<VoidCallback>(
            icon: Icon(Icons.more_vert_rounded, color: iconColor, size: 21),
            tooltip: 'المزيد',
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _askForPage, child: const _MenuRow(Icons.pin_outlined, 'الانتقال إلى صفحة')),
              PopupMenuItem(
                value: _toggleNotes,
                child: _MenuRow(
                  _showNotes ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  _showNotes ? 'إخفاء الحواشي' : 'إظهار الحواشي',
                ),
              ),
              PopupMenuItem(value: _copyPage, child: const _MenuRow(Icons.copy_rounded, 'نسخ نص الصفحة')),
              PopupMenuItem(value: _sharePage, child: const _MenuRow(Icons.share_rounded, 'مشاركة الصفحة')),
              if (_canDownload)
                _library.isDownloaded(widget.book.id)
                    ? const PopupMenuItem(
                        enabled: false,
                        child: _MenuRow(Icons.download_done_rounded, 'منزّل على الجهاز'),
                      )
                    : PopupMenuItem(
                        value: _downloadBook,
                        enabled: _library.downloadProgress(widget.book.id) == null,
                        child: const _MenuRow(Icons.download_rounded, 'تنزيل الكتاب'),
                      ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, BookContent content) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _surface(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _ReaderScrubber(
        page: _page,
        index: content.index,
        textColor: _text(isDark),
        secondaryColor: _secondary(isDark),
        onJump: _jumpToPage,
        onTapLabel: _askForPage,
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Scaffold(
      backgroundColor: _bg(isDark),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(
              'جاري فتح ${widget.book.shortTitle}...',
              style: AppTypography.font(fontSize: 16.5, fontWeight: FontWeight.bold, color: _text(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailable(bool isDark) {
    final textColor = _text(isDark);
    return Scaffold(
      backgroundColor: _bg(isDark),
      appBar: AppBar(
        backgroundColor: _surface(isDark),
        foregroundColor: textColor,
        title: Text(
          widget.book.shortTitle,
          style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.goldDark),
              ),
              const SizedBox(height: 20),
              Text(
                'الكتاب غير متاح الآن',
                style: AppTypography.font(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'تعذّر فتح الكتاب.',
                textAlign: TextAlign.center,
                style: AppTypography.font(fontSize: 13, height: 1.5, color: _secondary(isDark)),
              ),
              const SizedBox(height: 6),
              Text(
                'الكتب السحابية تحتاج اتصالاً عند أول فتح. نزّل الكتاب من بطاقته لتقرأه لاحقاً بلا إنترنت.',
                textAlign: TextAlign.center,
                style: AppTypography.font(fontSize: 12, height: 1.5, color: _secondary(isDark)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('إعادة المحاولة', style: AppTypography.buttonText()),
                    onPressed: _open,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('العودة للمكتبة', style: AppTypography.font(fontSize: 13, color: textColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: AppTypography.font(fontSize: 13.5))),
      ],
    );
  }
}

/// شريط التنقل السفلي: منزلق عبر الكتاب كله، وموضع القراءة.
class _ReaderScrubber extends StatefulWidget {
  final ValueNotifier<int> page;
  final BookIndex index;
  final Color textColor;
  final Color secondaryColor;
  final ValueChanged<int> onJump;
  final VoidCallback onTapLabel;

  const _ReaderScrubber({
    required this.page,
    required this.index,
    required this.textColor,
    required this.secondaryColor,
    required this.onJump,
    required this.onTapLabel,
  });

  @override
  State<_ReaderScrubber> createState() => _ReaderScrubberState();
}

class _ReaderScrubberState extends State<_ReaderScrubber> {
  /// موضع الإصبع أثناء السحب؛ الانتقال يحدث عند الإفلات فقط.
  int? _dragPage;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final total = widget.index.pageCount;

    return ValueListenableBuilder<int>(
      valueListenable: widget.page,
      builder: (context, current, _) {
        final shown = (_dragPage ?? current).clamp(1, total);
        final label = widget.index.printLabel(shown);
        final percent = total <= 1 ? 100 : ((shown - 1) / (total - 1) * 100).round();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded, color: widget.textColor),
                  onPressed: current > 1 ? () => widget.onJump(current - 1) : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  tooltip: 'الصفحة السابقة',
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: primary,
                      inactiveTrackColor: widget.textColor.withValues(alpha: 0.2),
                      thumbColor: primary,
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: shown.toDouble(),
                      min: 1,
                      max: total > 1 ? total.toDouble() : 2,
                      onChanged: total > 1 ? (v) => setState(() => _dragPage = v.round()) : null,
                      onChangeEnd: (v) {
                        setState(() => _dragPage = null);
                        widget.onJump(v.round());
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded, color: widget.textColor),
                  onPressed: current < total ? () => widget.onJump(current + 1) : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  tooltip: 'الصفحة التالية',
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Tooltip(
                    message: 'موضع القراءة يُحفظ تلقائياً',
                    child: Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.emeraldPrimary),
                  ),
                  // على الشاشة الضيقة تكفي العلامة؛ المكان لموضع القراءة
                  if (constraints.maxWidth >= 400) ...[
                    const SizedBox(width: 4),
                    Text(
                      'محفوظ تلقائياً',
                      style: AppTypography.font(fontSize: 11.0, color: widget.secondaryColor),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.onTapLabel,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Text(
                            '${label.isEmpty ? '' : '$label  •  '}$shown من $total  •  $percent%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.font(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: widget.textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// صفحة واحدة داخل التمرير المتصل: فاصل برقم المطبوع، ثم المتن، ثم الحواشي.
class _BookPageBlock extends StatelessWidget {
  final BookUnit unit;
  final bool showNotes;
  final String printLabel;
  final bool showSeparator;
  final double fontSize;
  final Color textColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color quranColor;

  const _BookPageBlock({
    required this.unit,
    required this.showNotes,
    required this.printLabel,
    required this.showSeparator,
    required this.fontSize,
    required this.textColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.quranColor,
  });

  static final RegExp _inlineToken = RegExp(r'﴿[^﴾\n]*﴾|\(\^[^)\n]{1,6}\)');

  /// بيت شعر: شطران قصيران بينهما "..." أو "…" أو "*".
  static final RegExp _verseLine = RegExp(r'^[^«»﴿﴾:]{6,70}\s(\.{3}|…|\*)\s[^«»﴿﴾:]{6,70}$');

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTypography.font(fontSize: fontSize, height: 1.9, color: textColor);
    final gap = fontSize * 0.5;
    final children = <Widget>[];

    if (showSeparator || printLabel.isNotEmpty) {
      children.add(_separator());
    }

    for (final line in unit.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      if (line.startsWith(BookUnit.headingMark)) {
        children.add(Padding(
          padding: EdgeInsets.only(top: gap * 1.4, bottom: gap),
          child: Text(
            line.substring(BookUnit.headingMark.length),
            textAlign: TextAlign.center,
            style: AppTypography.font(
              fontSize: fontSize + 2.5,
              height: 1.6,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ));
      } else if (line == BookUnit.ruleLine) {
        children.add(Padding(
          padding: EdgeInsets.symmetric(vertical: gap, horizontal: 80),
          child: Divider(color: accentColor.withValues(alpha: 0.4), thickness: 0.8),
        ));
      } else {
        final isVerse = _verseLine.hasMatch(line);
        children.add(Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Text.rich(
            TextSpan(children: _spans(line)),
            textAlign: isVerse ? TextAlign.center : TextAlign.justify,
            style: bodyStyle,
          ),
        ));
      }
    }

    final notes = unit.notes;
    if (showNotes && notes != null && notes.trim().isNotEmpty) {
      children.add(Container(
        margin: EdgeInsets.only(top: gap * 0.6, bottom: gap),
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.14))),
        ),
        child: Text(
          notes,
          textAlign: TextAlign.justify,
          style: AppTypography.font(
            fontSize: (fontSize * 0.76).clamp(12.0, 22.0),
            height: 1.75,
            color: secondaryColor,
          ),
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _separator() {
    final line = Expanded(child: Divider(color: textColor.withValues(alpha: 0.12), thickness: 0.8));
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Row(
        children: [
          line,
          if (printLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                printLabel,
                style: AppTypography.font(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.45),
                ),
              ),
            ),
          line,
        ],
      ),
    );
  }

  /// الآيات بلون مميز، وأرقام الحواشي صغيرة.
  List<InlineSpan> _spans(String line) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineToken.allMatches(line)) {
      if (m.start > last) spans.add(TextSpan(text: line.substring(last, m.start)));
      final token = m[0]!;
      if (token.startsWith('﴿')) {
        spans.add(TextSpan(
          text: token,
          style: TextStyle(color: quranColor, fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(
          text: '(${token.substring(2, token.length - 1)})',
          style: TextStyle(fontSize: fontSize * 0.64, color: accentColor, fontWeight: FontWeight.bold),
        ));
      }
      last = m.end;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last)));
    return spans;
  }
}

/// هيكل صفحة لم يصل نصها بعد.
class _PageSkeleton extends StatelessWidget {
  final Color color;

  const _PageSkeleton({required this.color});

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: widthFactor,
          child: Container(
            height: 12,
            margin: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in const [1.0, 0.96, 1.0, 0.9, 0.98, 1.0, 0.94, 0.6]) bar(w),
        ],
      ),
    );
  }
}

class _PageLoadError extends StatelessWidget {
  final Color color;
  final VoidCallback onRetry;

  const _PageLoadError({required this.color, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            'تعذّر تحميل هذه الصفحات',
            style: AppTypography.font(fontSize: 13, color: color),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
