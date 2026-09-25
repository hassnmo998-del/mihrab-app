import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/widgets/unified_badge.dart';
import '../../../services/quran_audio_service.dart';
import '../../../services/quran_service.dart';
import 'quran_audio_bar.dart';
import 'quran_data_constants.dart';
import 'quran_page_mushaf_view.dart';
import 'quran_surah_reader_view.dart';

/// Islamic Quran Reader Coordinator.
/// Features:
/// - Page-by-Page Madinah Mushaf Reader (604 pages)
/// - Surah, Juz, and Page Indexing (114 Surahs, 30 Ajza, 604 Pages)
/// - Bookmark Persistence and Instant Resume
class QuranReaderView extends StatefulWidget {
  final bool isDark;

  /// Leaves the Quran section (back to Discover).
  final VoidCallback onExit;

  const QuranReaderView({super.key, this.isDark = false, required this.onExit});

  @override
  State<QuranReaderView> createState() => _QuranReaderViewState();
}

class _QuranReaderViewState extends State<QuranReaderView> {
  int _selectedTabIndex = 0; // 0: Surahs, 1: Juzes, 2: Pages, 3: Bookmarks
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Active view: 'index', 'mushaf_page', 'surah_scroll'
  String _viewMode = 'index';
  int _targetPage = 1;
  int? _targetAyah;
  Map<String, dynamic>? _targetSurah;

  bool _isLoadingQuran = !QuranService.isLoaded;

  // Persistent Bookmark
  int? _bookmarkedPage;
  int? _bookmarkedSurahNumber;
  String? _bookmarkedSurahName;
  int? _bookmarkedAyah;
  String? _bookmarkedDate;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
    _initQuranData();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
  }

  Future<void> _initQuranData() async {
    if (!QuranService.isLoaded) {
      setState(() => _isLoadingQuran = true);
      await QuranService.ensureLoaded();
      if (mounted) setState(() => _isLoadingQuran = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final page = prefs.getInt('quran_bookmark_page');
    final surahNum = prefs.getInt('quran_bookmark_surah_num');
    final surahName = prefs.getString('quran_bookmark_surah_name');
    final ayah = prefs.getInt('quran_bookmark_ayah') ?? 1;
    final date = prefs.getString('quran_bookmark_date');

    setState(() {
      _bookmarkedPage = page;
      _bookmarkedSurahNumber = surahNum;
      _bookmarkedSurahName = surahName;
      _bookmarkedAyah = ayah;
      _bookmarkedDate = date;

      // If user has a saved bookmark, jump directly to that page
      if (page != null && page >= 1 && page <= 604 && _viewMode == 'index') {
        _targetPage = page;
        _targetAyah = ayah;
        _viewMode = 'mushaf_page';
      }
    });
  }

  Future<void> _saveBookmark(int page, int surahNum, String surahName, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = '${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}';
    await prefs.setInt('quran_bookmark_page', page);
    await prefs.setInt('quran_bookmark_surah_num', surahNum);
    await prefs.setString('quran_bookmark_surah_name', surahName);
    await prefs.setInt('quran_bookmark_ayah', ayah);
    await prefs.setString('quran_bookmark_date', nowStr);

    setState(() {
      _bookmarkedPage = page;
      _bookmarkedSurahNumber = surahNum;
      _bookmarkedSurahName = surahName;
      _bookmarkedAyah = ayah;
      _bookmarkedDate = nowStr;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ علامة التلاوة: صفحة $page - سورة $surahName (الآية $ayah) ✨'),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openPage(int page, {int? jumpToAyah}) {
    setState(() {
      _targetPage = page.clamp(1, 604);
      _targetAyah = jumpToAyah;
      _viewMode = 'mushaf_page';
    });
  }

  void _openSurah(Map<String, dynamic> surah) {
    final surahNum = surah['number'] as int;
    final startPage = QuranService.getSurahStartPage(surahNum);
    _openPage(startPage);
  }

  void _openSurahContinuous(Map<String, dynamic> surah) {
    setState(() {
      _targetSurah = surah;
      _viewMode = 'surah_scroll';
    });
  }

  void _closeReading() {
    setState(() {
      _viewMode = 'index';
      _targetSurah = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final padding = (_viewMode == 'mushaf_page' && isMobile)
        ? const EdgeInsets.fromLTRB(6, 4, 6, 2)
        : const EdgeInsets.fromLTRB(12, 8, 12, 8);

    // System back: reading view → index → leave the section.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_viewMode == 'index') {
          widget.onExit();
        } else {
          _closeReading();
        }
      },
      child: Padding(
        padding: padding,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoadingQuran) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              const Text('جاري تحميل المصحف الشريف وأحكام التجويد...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (_viewMode == 'mushaf_page') {
      return QuranPageMushafView(
        initialPage: _targetPage,
        initialAyah: _targetAyah,
        isDark: widget.isDark,
        onClose: _closeReading,
        onSaveBookmark: _saveBookmark,
        bookmarkedPage: _bookmarkedPage,
      );
    }

    if (_viewMode == 'surah_scroll' && _targetSurah != null) {
      return SingleChildScrollView(
        child: QuranSurahReaderView(
          surah: _targetSurah!,
          isDark: widget.isDark,
          onClose: _closeReading,
          onSaveBookmark: (sNum, sName, aNum) => _saveBookmark(QuranService.getSurahStartPage(sNum), sNum, sName, aNum),
          bookmarkedSurahNumber: _bookmarkedSurahNumber,
          onOpenSurah: _openSurahContinuous,
        ),
      );
    }

    final isDark = widget.isDark;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    // Ensure audio engine is initialized when reaching index view
    QuranAudioService.instance.init();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header: back to Discover
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              tooltip: 'رجوع',
              onPressed: widget.onExit,
            ),
            const SizedBox(width: 4),
            Text(
              'القرآن الكريم',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.goldLight : AppColors.goldDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: SingleChildScrollView(child: _buildIndex(isDark, primaryColor, dividerColor))),
      ],
    );
  }

  Widget _buildIndex(bool isDark, Color primaryColor, Color dividerColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Persistent audio bar at top of index while a recitation is loaded
        QuranAudioBar(isDark: isDark, margin: const EdgeInsets.only(bottom: 16)),

        // Resume Reading Bookmark Hero Card
        if (_bookmarkedPage != null || (_bookmarkedSurahNumber != null && _bookmarkedSurahName != null))
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.82),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldDark.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.bookmark_added_rounded, color: AppColors.gold, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('علامة آخر تلاوة', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          if (_bookmarkedDate != null)
                            Text(_bookmarkedDate!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _bookmarkedPage != null
                            ? 'صفحة $_bookmarkedPage • سورة ${_bookmarkedSurahName ?? ""} (آية $_bookmarkedAyah)'
                            : 'سورة $_bookmarkedSurahName (آية $_bookmarkedAyah)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldDark,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => _openPage(_bookmarkedPage ?? QuranService.getSurahStartPage(_bookmarkedSurahNumber ?? 1)),
                  child: const Text('متابعة', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        // Search Bar
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم السورة، الجزء، أو رقم الصفحة...',
            prefixIcon: Icon(Icons.search, color: primaryColor),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                : null,
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          ),
        ),
        const SizedBox(height: 14),

        // Subtabs (Surahs, Juzes, Pages)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightInputFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildIndexTabButton(0, 'فهرس السور (114)', primaryColor, isDark),
              const SizedBox(width: 4),
              _buildIndexTabButton(1, 'الأجزاء (30)', primaryColor, isDark),
              const SizedBox(width: 4),
              _buildIndexTabButton(2, 'الصفحات (604) 📖', primaryColor, isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Index Tab Content
        if (_selectedTabIndex == 0) _buildSurahsList(isDark, dividerColor),
        if (_selectedTabIndex == 1) _buildJuzesList(isDark, dividerColor),
        if (_selectedTabIndex == 2) _buildPagesList(isDark, dividerColor),
      ],
    );
  }

  Widget _buildIndexTabButton(int index, String title, Color primaryColor, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurahsList(bool isDark, Color dividerColor) {
    final filtered = kQuranSurahs.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s['name'].toString().contains(_searchQuery) ||
          s['number'].toString().contains(_searchQuery) ||
          s['english'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.7, color: dividerColor),
      itemBuilder: (context, idx) {
        final s = filtered[idx];
        final surahNum = s['number'] as int;
        final isMeccan = s['type'] == 'meccan';
        final startPage = QuranService.getSurahStartPage(surahNum);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldDark, width: 1.5),
              color: AppColors.gold.withValues(alpha: 0.1),
            ),
            child: Text(
              surahNum.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.goldDark),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  'سورة ${s['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              UnifiedBadge(
                label: isMeccan ? 'مكية 🕋' : 'مدنية 🕌',
                backgroundColor: isMeccan ? AppColors.terracottaPrimary.withValues(alpha: 0.1) : AppColors.emeraldPrimary.withValues(alpha: 0.1),
                textColor: isMeccan ? AppColors.terracottaPrimary : AppColors.emeraldPrimary,
              ),
            ],
          ),
          subtitle: Text(
            '${s['verses']} آية • الجزء ${s['juz']} • ${s['english']}',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ص $startPage', style: TextStyle(fontSize: 12, color: AppColors.goldDark, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: AppColors.goldDark, size: 20),
            ],
          ),
          onTap: () => _openSurah(s),
        );
      },
    );
  }

  Widget _buildJuzesList(bool isDark, Color dividerColor) {
    final primaryColor = Theme.of(context).primaryColor;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kQuranJuzes.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.7, color: dividerColor),
      itemBuilder: (context, idx) {
        final juz = kQuranJuzes[idx];
        final juzNum = juz['number'] as int;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 1.5),
            ),
            child: Text(
              juzNum.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
            ),
          ),
          title: Text('الجزء $juzNum - ${juz['startText']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text('يبدأ من: سورة ${juz['surahName']} (آية ${juz['ayah']})', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
          trailing: Icon(Icons.chevron_left_rounded, color: primaryColor),
          onTap: () {
            final s = kQuranSurahs.firstWhere((su) => su['name'] == juz['surahName'], orElse: () => kQuranSurahs.first);
            final sNum = s['number'] as int;
            final startPage = QuranService.getSurahStartPage(sNum);
            _openPage(startPage, jumpToAyah: juz['ayah'] as int);
          },
        );
      },
    );
  }

  Widget _buildPagesList(bool isDark, Color dividerColor) {
    final pages = List.generate(604, (i) => i + 1).where((p) {
      if (_searchQuery.isEmpty) return true;
      if (p.toString() == _searchQuery) return true;
      final pageData = QuranService.getPage(p);
      if (pageData == null) return false;
      return pageData.surahNames.any((name) => name.contains(_searchQuery)) ||
          'جزء ${pageData.juzNumber}'.contains(_searchQuery);
    }).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pages.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.7, color: dividerColor),
      itemBuilder: (context, idx) {
        final pageNum = pages[idx];
        final pageData = QuranService.getPage(pageNum);
        final surahTitle = pageData?.surahNames.isNotEmpty == true ? pageData!.surahNames.join(' • ') : '';
        final juzNum = pageData?.juzNumber ?? 1;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.goldDark, width: 1.2),
              color: AppColors.gold.withValues(alpha: 0.1),
            ),
            child: Text(
              pageNum.toString(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.goldDark),
            ),
          ),
          title: Text('صفحة $pageNum • سورة $surahTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text('الجزء $juzNum • الحزب ${((pageData?.hizbQuarter ?? 1) - 1) ~/ 4 + 1}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
          trailing: Icon(Icons.menu_book_rounded, color: AppColors.goldDark, size: 20),
          onTap: () => _openPage(pageNum),
        );
      },
    );
  }
}
