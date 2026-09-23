import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/quran_audio_service.dart';
import '../../../services/quran_search_service.dart';
import '../../../services/quran_service.dart';
import 'quran_audio_bar.dart';

/// Authentic Page-by-Page Madinah Mushaf Viewer (604 Pages).
/// Features RTL swipe, Tajweed letter-joining, Surah headers, and page bookmarking.
class QuranPageMushafView extends StatefulWidget {
  final int initialPage;
  final int? initialAyah;
  final bool isDark;
  final VoidCallback onClose;
  final void Function(int page, int surahNum, String surahName, int ayah) onSaveBookmark;
  final int? bookmarkedPage;

  const QuranPageMushafView({
    super.key,
    required this.initialPage,
    this.initialAyah,
    required this.isDark,
    required this.onClose,
    required this.onSaveBookmark,
    this.bookmarkedPage,
  });

  @override
  State<QuranPageMushafView> createState() => _QuranPageMushafViewState();
}

class _QuranPageMushafViewState extends State<QuranPageMushafView> {
  late int _currentPage;
  late PageController _pageController;
  bool _isTajweedMode = false;
  double _fontSize = 21.0;

  static const double _minFontSize = 16;
  static const double _maxFontSize = 36;

  // Search
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<QuranSearchResult> _searchResults = const [];

  /// Ayah picked from search results, highlighted until audio moves on.
  String? _highlightKey;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);
    // Auto page-flip when audio advances to next page
    QuranAudioService.instance.activePageNotifier.addListener(_onActivePageChanged);
    QuranAudioService.instance.activeAyahNotifier.addListener(_onActiveAyahChanged);
  }

  @override
  void dispose() {
    QuranAudioService.instance.activePageNotifier.removeListener(_onActivePageChanged);
    QuranAudioService.instance.activeAyahNotifier.removeListener(_onActiveAyahChanged);
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onActiveAyahChanged() {
    if (_highlightKey != null && mounted) setState(() => _highlightKey = null);
  }

  void _onActivePageChanged() {
    final audioPage = QuranAudioService.instance.activePageNotifier.value;
    if (audioPage != null && audioPage != _currentPage && mounted) {
      _goToPage(audioPage);
    }
  }

  void _goToPage(int page) {
    final clamped = page.clamp(1, 604);
    setState(() => _currentPage = clamped);
    _pageController.jumpToPage(clamped - 1);
  }

  String _idleTitle() {
    final names = QuranService.getPage(_currentPage)?.surahNames ?? const [];
    return names.isNotEmpty ? 'سورة ${names.first}' : 'صفحة $_currentPage';
  }

  void _startFromCurrentPage() {
    final ayahs = QuranService.getPage(_currentPage)?.ayahs ?? const [];
    if (ayahs.isEmpty) return;
    final first = ayahs.first;
    QuranAudioService.instance.playAyah(first.surahNumber, first.ayahNumberInSurah, pageNumber: _currentPage);
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    // Build the search index now rather than on the first keystroke.
    WidgetsBinding.instance.addPostFrameCallback((_) => QuranSearchService.warmUp());
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchOpen = false;
      _searchCtrl.clear();
      _searchResults = const [];
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchResults = QuranSearchService.search(query));
  }

  void _openSearchResult(int page, {String? ayahKey}) {
    _closeSearch();
    setState(() => _highlightKey = ayahKey);
    _goToPage(page);
  }

  void _bookmarkPage(int page) {
    final pageData = QuranService.getPage(page);
    final firstAyah = pageData?.ayahs.isNotEmpty == true ? pageData!.ayahs.first : null;
    widget.onSaveBookmark(
      page,
      firstAyah?.surahNumber ?? 1,
      firstAyah?.surahName ?? 'الفاتحة',
      firstAyah?.ayahNumberInSurah ?? 1,
    );
  }

  void _zoom(double delta) {
    final next = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    if (next != _fontSize) setState(() => _fontSize = next);
  }

  /// Slim top row: back to the index, and search right beside it.
  Widget _buildTopRow(bool isDark) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'العودة للفهرس',
            onPressed: widget.onClose,
          ),
          if (!_searchOpen)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'بحث',
              onPressed: _openSearch,
            )
          else
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'كلمة من آية أو رقم صفحة',
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'إغلاق البحث',
                    onPressed: _closeSearch,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Search results laid over the page; a typed page number is offered first.
  Widget _buildSearchResults(bool isDark) {
    final query = _searchCtrl.text.trim();
    final page = QuranSearchService.pageNumberOf(query);
    final results = _searchResults;
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;
    final muted = isDark ? Colors.white54 : Colors.black54;
    final count = (page != null ? 1 : 0) + results.length;

    return Material(
      color: isDark ? AppColors.darkCard : const Color(0xFFFFFDF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: count == 0
          ? Center(child: Text('لا نتائج', style: TextStyle(color: muted)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: count,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.15)),
              itemBuilder: (context, i) {
                if (page != null && i == 0) {
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.menu_book_rounded, color: gold, size: 20),
                    title: Text('الصفحة $page', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _openSearchResult(page),
                  );
                }
                final r = results[i - (page != null ? 1 : 0)];
                return InkWell(
                  onTap: () => _openSearchResult(r.pageNumber, ayahKey: r.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'سورة ${r.surahName} · ${r.ayahNumber}',
                              style: GoogleFonts.amiri(fontSize: 13, fontWeight: FontWeight.bold, color: gold),
                            ),
                            const Spacer(),
                            Text('ص ${r.pageNumber}', style: TextStyle(fontSize: 11, color: muted)),
                          ],
                        ),
                        Text(
                          r.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(fontSize: 15, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final showResults = _searchOpen &&
        (QuranSearchService.pageNumberOf(_searchCtrl.text) != null ||
            QuranSearchService.skeleton(_searchCtrl.text).length >= 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopRow(isDark),
        const SizedBox(height: 6),

        // Fixed audio bar with inline listening options
        QuranAudioBar(
          isDark: isDark,
          idleTitle: _idleTitle(),
          onStart: _startFromCurrentPage,
        ),
        const SizedBox(height: 10),

        // 604-Page PageView — fills the remaining height of the Quran section
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 604,
                  reverse: false, // Reversing page flip direction
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx + 1);
                  },
                  itemBuilder: (context, idx) {
                    final pageNum = idx + 1;
                    final pageData = QuranService.getPage(pageNum);
                    if (pageData == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _MushafPageCard(
                      key: ValueKey('mushaf_page_$pageNum'),
                      page: pageData,
                      isDark: isDark,
                      fontSize: _fontSize,
                      isTajweedMode: _isTajweedMode,
                      onToggleTajweed: () => setState(() => _isTajweedMode = !_isTajweedMode),
                      onSaveBookmark: widget.onSaveBookmark,
                      onZoomIn: () => _zoom(2),
                      onZoomOut: () => _zoom(-2),
                      onBookmark: () => _bookmarkPage(pageNum),
                      isBookmarked: widget.bookmarkedPage == pageNum,
                      highlightKey: _highlightKey,
                    );
                  },
                ),
              ),
              if (showResults) Positioned.fill(child: _buildSearchResults(isDark)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bottom Page Slider & Navigator Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                tooltip: 'الصفحة السابقة',
                onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              ),
              Expanded(
                child: Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: 604,
                  divisions: 603,
                  label: 'صفحة $_currentPage',
                  activeColor: AppColors.goldDark,
                  onChanged: (v) => _goToPage(v.toInt()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                tooltip: 'الصفحة التالية',
                onPressed: _currentPage < 604 ? () => _goToPage(_currentPage + 1) : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.goldDark, width: 1),
                ),
                child: Text('$_currentPage / 604', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.goldDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageSurahSegment {
  final int surahNumber;
  final String surahName;
  final List<QuranAyah> ayahs;

  const _PageSurahSegment({
    required this.surahNumber,
    required this.surahName,
    required this.ayahs,
  });
}

class _MushafPageCard extends StatefulWidget {
  final QuranPage page;
  final bool isDark;
  final double fontSize;
  final bool isTajweedMode;
  final VoidCallback onToggleTajweed;
  final void Function(int page, int surahNum, String surahName, int ayah) onSaveBookmark;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onBookmark;
  final bool isBookmarked;

  /// Ayah picked from search results (`surah:ayah`), highlighted like the playing ayah.
  final String? highlightKey;

  const _MushafPageCard({
    super.key,
    required this.page,
    required this.isDark,
    required this.fontSize,
    required this.isTajweedMode,
    required this.onToggleTajweed,
    required this.onSaveBookmark,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onBookmark,
    required this.isBookmarked,
    this.highlightKey,
  });

  @override
  State<_MushafPageCard> createState() => _MushafPageCardState();
}

class _MushafPageCardState extends State<_MushafPageCard> {
  final List<GestureRecognizer> _recognizers = [];

  /// الآية الحالية المظلّلة — تُحدَّث فوراً عند النقر ثم تتابع الصوت
  String? _activeAyahKey;

  /// ScrollController لحفظ موضع التمرير عند إعادة البناء
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen to audio service to keep highlight in sync when audio advances automatically
    QuranAudioService.instance.activeAyahNotifier.addListener(_onAudioAyahChanged);
    // Sync initial state if audio is already playing
    _activeAyahKey = QuranAudioService.instance.activeAyahNotifier.value;
  }

  @override
  void dispose() {
    QuranAudioService.instance.activeAyahNotifier.removeListener(_onAudioAyahChanged);
    _scrollController.dispose();
    _clearRecognizers();
    super.dispose();
  }

  /// Called when audio service advances to next ayah — syncs highlight without scroll jump
  void _onAudioAyahChanged() {
    final key = QuranAudioService.instance.activeAyahNotifier.value;
    if (mounted && _activeAyahKey != key) {
      setState(() => _activeAyahKey = key);
    }
  }

  /// Instantly highlights an ayah and fires playback — zero perceived lag
  void _tapAyah(int surahNum, int ayahNum, {int? pageNumber}) {
    // 1. Immediate visual feedback — highlight before any network request
    setState(() => _activeAyahKey = '$surahNum:$ayahNum');
    // 2. Start audio async — UI doesn't wait for this
    QuranAudioService.instance.playAyah(surahNum, ayahNum, pageNumber: pageNumber);
  }



  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  List<_PageSurahSegment> _getSegments(List<QuranAyah> ayahs) {
    final segments = <_PageSurahSegment>[];
    if (ayahs.isEmpty) return segments;

    int? currentSurah;
    String currentSurahName = '';
    List<QuranAyah> currentAyahs = [];

    for (final a in ayahs) {
      if (currentSurah == null || a.surahNumber != currentSurah) {
        if (currentAyahs.isNotEmpty) {
          segments.add(_PageSurahSegment(
            surahNumber: currentSurah!,
            surahName: currentSurahName,
            ayahs: List.unmodifiable(currentAyahs),
          ));
          currentAyahs = [];
        }
        currentSurah = a.surahNumber;
        currentSurahName = a.surahName;
      }
      currentAyahs.add(a);
    }

    if (currentAyahs.isNotEmpty) {
      segments.add(_PageSurahSegment(
        surahNumber: currentSurah!,
        surahName: currentSurahName,
        ayahs: List.unmodifiable(currentAyahs),
      ));
    }

    return segments;
  }

  /// Builds a single inline Quranic text widget for one Surah segment on this page.
  /// Each Ayah is inline (like a real Mushaf) with:
  /// - Gold `backgroundColor` on the ENTIRE Ayah text when it is actively playing.
  /// - TapGestureRecognizer per Ayah for instant tap-to-play with zero perceived lag.
  Widget _buildSegmentText({
    required BuildContext context,
    required _PageSurahSegment segment,
    required QuranPage page,
    required bool isDark,
    required double fontSize,
    required bool isTajweedMode,
  }) {
    final spans = <InlineSpan>[];

    for (final a in segment.ayahs) {
      final ayahKey = '${a.surahNumber}:${a.ayahNumberInSurah}';
      final isActive = _activeAyahKey == ayahKey || widget.highlightKey == ayahKey;

      // Background color for the active Ayah — renders across all lines naturally
      final activeBg = isActive
          ? AppColors.gold.withValues(alpha: isDark ? 0.22 : 0.15)
          : null;

      if (isTajweedMode) {
        // Tajweed mode — wrap each span with backgroundColor + instant tap
        final tajweedChildren = QuranService.buildTajweedSpans(
          a.tajweedText,
          fontSize: fontSize,
          isDark: isDark,
        );
        final tapRec = TapGestureRecognizer()
          ..onTap = () => _tapAyah(a.surahNumber, a.ayahNumberInSurah, pageNumber: page.pageNumber);
        _recognizers.add(tapRec);

        spans.add(TextSpan(
          children: tajweedChildren.map((ts) {
            final span = ts as TextSpan; // ignore: unnecessary_cast
            return TextSpan(
              text: span.text,
              style: span.style?.copyWith(backgroundColor: activeBg) ??
                  TextStyle(backgroundColor: activeBg),
              recognizer: tapRec,
            );
          }).toList(),
        ));
      } else {
        // Normal Uthmani mode — instant highlight + async audio
        final tapRec = TapGestureRecognizer()
          ..onTap = () => _tapAyah(a.surahNumber, a.ayahNumberInSurah, pageNumber: page.pageNumber);
        _recognizers.add(tapRec);

        spans.add(TextSpan(
          text: a.uthmaniText,
          style: GoogleFonts.amiri(
            fontSize: fontSize,
            height: 2.15,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.normal,
            backgroundColor: activeBg,
          ),
          recognizer: tapRec,
        ));
      }

      // Ayah ornament ﴿١﴾ — same instant behaviour
      final ornamentTap = TapGestureRecognizer()
        ..onTap = () => _tapAyah(a.surahNumber, a.ayahNumberInSurah, pageNumber: page.pageNumber);
      _recognizers.add(ornamentTap);

      spans.add(TextSpan(
        text: ' ${QuranService.formatAyahBracket(a.ayahNumberInSurah)} ',
        style: GoogleFonts.amiri(
          fontSize: fontSize * 0.88,
          fontWeight: FontWeight.bold,
          color: isActive ? AppColors.goldDark : (isDark ? AppColors.goldLight : AppColors.goldDark),
          backgroundColor: activeBg,
        ),
        recognizer: ornamentTap,
      ));
    }

    // GestureDetector wraps the whole segment for long-press bookmark on last active ayah
    // (TextSpan.recognizer only supports one gesture per span)
    return GestureDetector(
      onLongPress: () {
        // Long press → bookmark the first ayah of this segment as default
        final firstAyah = segment.ayahs.first;
        widget.onSaveBookmark(
          page.pageNumber,
          firstAyah.surahNumber,
          firstAyah.surahName,
          firstAyah.ayahNumberInSurah,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'تم حفظ علامة القراءة: سورة ${firstAyah.surahName} - الآية ${QuranService.toArabicDigits(firstAyah.ayahNumberInSurah)}',
          ),
          duration: const Duration(seconds: 2),
        ));
      },
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final page = widget.page;
    final isDark = widget.isDark;
    final fontSize = widget.fontSize;
    final isTajweedMode = widget.isTajweedMode;

    // Header title for single or multiple Surahs
    final surahTitle = page.surahNames.isNotEmpty
        ? page.surahNames.map((s) => 'سورة $s').join(' • ')
        : '';

    final segments = _getSegments(page.ayahs);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldDark.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mushaf Page Top Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      surahTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.amiri(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppColors.goldLight : AppColors.goldDark,
                      ),
                    ),
                  ),
                ),
                _headerChip(Icons.text_decrease_rounded, 'تصغير الخط', widget.onZoomOut, isDark),
                const SizedBox(width: 6),
                _headerChip(Icons.text_increase_rounded, 'تكبير الخط', widget.onZoomIn, isDark),
                const SizedBox(width: 6),
                _headerChip(
                  widget.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  'حفظ علامة القراءة',
                  widget.onBookmark,
                  isDark,
                  active: widget.isBookmarked,
                ),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'الجزء ${page.juzNumber}',
                      style: GoogleFonts.amiri(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppColors.goldLight : AppColors.goldDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable page content — controller preserves position across setState rebuilds
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final seg in segments) ...[
                    // Surah Header Banner if Surah starts on this page (ayah 1)
                    if (seg.ayahs.first.ayahNumberInSurah == 1) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor.withValues(alpha: 0.15),
                              AppColors.gold.withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'سُورَةُ ${QuranService.getSurahName(seg.surahNumber)}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.goldLight : AppColors.goldDark,
                          ),
                        ),
                      ),
                      // Standalone Basmalah (all surahs except At-Tawbah 9 and Al-Fatiha 1)
                      if (seg.surahNumber != 9 && seg.surahNumber != 1) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiri(
                              fontSize: fontSize * 0.95,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],

                    // One inline Text.rich for the whole segment — authentic Quranic flow
                    _buildSegmentText(
                      context: context,
                      segment: seg,
                      page: page,
                      isDark: isDark,
                      fontSize: fontSize,
                      isTajweedMode: isTajweedMode,
                    ),
                    if (seg != segments.last) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // Mushaf Page Bottom Footer
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الحزب ${((page.hizbQuarter - 1) ~/ 4) + 1}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '— ${page.pageNumber} —',
                    style: GoogleFonts.amiri(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppColors.goldLight : AppColors.goldDark,
                    ),
                  ),
                ),
                Text(
                  'الربع ${((page.hizbQuarter - 1) % 4) + 1}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(child: _buildTajweedToggle(isDark, isTajweedMode)),
        ],
      ),
    );
  }

  /// Icon-only chip for the top of the page, styled like the page-number and tajweed chips.
  Widget _headerChip(IconData icon, String tooltip, VoidCallback onTap, bool isDark, {bool active = false}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: active ? 0.22 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: isDark ? AppColors.goldLight : AppColors.goldDark),
        ),
      ),
    );
  }

  /// Tajweed switch styled like the page-number chip; when on, the colour key replaces its label.
  Widget _buildTajweedToggle(bool isDark, bool isOn) {
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;
    return InkWell(
      onTap: widget.onToggleTajweed,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: isOn ? 0.16 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isOn
              ? Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Icon(Icons.palette_rounded, size: 13, color: gold),
                    _legendItem(const Color(0xFFDC2626), 'مد لازم ومتصل', isDark),
                    _legendItem(const Color(0xFFEA580C), 'مد جائز وعارض', isDark),
                    _legendItem(const Color(0xFF059669), 'غنة وإخفاء وإدغام', isDark),
                    _legendItem(const Color(0xFF0284C7), 'قلقلة', isDark),
                    _legendItem(const Color(0xFFD97706), 'إقلاب', isDark),
                    _legendItem(isDark ? Colors.white38 : Colors.black38, 'لا يُلفظ', isDark),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.palette_outlined, size: 13, color: gold),
                    const SizedBox(width: 5),
                    Text(
                      'أحكام التجويد',
                      style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 12, color: gold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.amiri(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
