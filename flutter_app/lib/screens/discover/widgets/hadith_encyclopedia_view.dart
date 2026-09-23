import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/hadith_service.dart';
import 'hadith_card.dart';

/// Comprehensive Islamic Hadith Encyclopedia View (15,200+ Hadiths).
/// Covers Sahih al-Bukhari (7,589), Sahih Muslim (7,563), Nawawi 40, Hadith Qudsi, and Riyad.
/// Optimized with on-demand lazy loading and smart pagination for desktop & mobile.
class HadithEncyclopediaView extends StatefulWidget {
  final bool isDark;

  const HadithEncyclopediaView({super.key, required this.isDark});

  @override
  State<HadithEncyclopediaView> createState() => _HadithEncyclopediaViewState();
}

class _HadithEncyclopediaViewState extends State<HadithEncyclopediaView> {
  String _selectedBook = 'bukhari'; // 'bukhari', 'muslim', 'qudsi', 'nawawi', 'riyad'
  String _selectedChapter = 'الكل';
  int _displayedCount = 35;
  double _hadithFontSize = 18.0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _displayedCount = 35;
      });
    });
  }

  Future<void> _initData() async {
    if (!HadithService.isBookLoaded(_selectedBook)) {
      setState(() => _isLoading = true);
      try {
        await HadithService.ensureBookLoaded(_selectedBook);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectBook(String bookKey) async {
    if (_selectedBook == bookKey) return;
    setState(() {
      _selectedBook = bookKey;
      _selectedChapter = 'الكل';
      _displayedCount = 35;
    });

    if (!HadithService.isBookLoaded(bookKey)) {
      setState(() => _isLoading = true);
      try {
        await HadithService.ensureBookLoaded(bookKey);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _copyHadith(NawawiHadith h) {
    HapticFeedback.lightImpact();
    final bookName = _getBookDisplayName(h.book);
    final text = 'من $bookName (${h.chapter}):\n'
        'الحديث رقم (${h.number}): ${h.title}\n'
        'عن ${h.narrator}:\n'
        '"${h.matn}"\n'
        '[${h.source}]\n'
        '— عبر منصة محراب وزاد المسلم';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الحديث الشريف إلى الحافظة بنجاح ✨'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareHadith(NawawiHadith h) {
    HapticFeedback.lightImpact();
    final bookName = _getBookDisplayName(h.book);
    final text = '''
✨ من $bookName (${h.chapter}) ✨
الحديث رقم (${h.number}): ${h.title}
عن ${h.narrator}:
"${h.matn}"
[${h.source}]
— عبر منصة محراب
'''.trim();
    Share.share(text);
  }

  String _getBookDisplayName(String book) {
    switch (book) {
      case 'bukhari':
        return 'صحيح الإمام البخاري (7,589 حديثاً)';
      case 'muslim':
        return 'صحيح الإمام مسلم (7,563 حديثاً)';
      case 'qudsi':
        return 'الأحاديث القدسية الشريفة (40 حديثاً)';
      case 'nawawi':
        return 'الأربعون النووية (42 حديثاً)';
      case 'riyad':
        return 'رياض الصالحين والمساجد';
      default:
        return 'السنة النبوية المشرفة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Book Selector Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildBookTab('bukhari', 'صحيح البخاري 📜', '7,589 حديثاً (98 كتاباً)'),
                const SizedBox(width: 4),
                _buildBookTab('muslim', 'صحيح مسلم 🕌', '7,563 حديثاً (56 كتاباً)'),
                const SizedBox(width: 4),
                _buildBookTab('qudsi', 'الأحاديث القدسية 🤍', '40 حديثاً قدسياً'),
                const SizedBox(width: 4),
                _buildBookTab('nawawi', 'الأربعون النووية 📖', '42 حديثاً في أصول الدين'),
                const SizedBox(width: 4),
                _buildBookTab('riyad', 'رياض الصالحين 🌿', 'مختارات المساجد والتربية'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Chapters Bar (Dropdown + Chips)
        _buildChaptersSection(isDark),

        // Search Bar & Font Scaler Controls
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الحديث أو الكلمات أو الرواة أو الأبواب...',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  isDense: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: dividerColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightInputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.text_decrease, size: 18),
                    tooltip: 'تصغير الخط',
                    onPressed: _hadithFontSize > 15
                        ? () => setState(() => _hadithFontSize -= 1.5)
                        : null,
                  ),
                  Text(
                    '${_hadithFontSize.toInt()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_increase, size: 18),
                    tooltip: 'تكبير الخط',
                    onPressed: _hadithFontSize < 26
                        ? () => setState(() => _hadithFontSize += 1.5)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Hadith Content with Pagination
        _buildHadithContent(isDark),
      ],
    );
  }

  Widget _buildBookTab(String bookKey, String title, String subtitle) {
    final isSelected = _selectedBook == bookKey;
    final isDark = widget.isDark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _selectBook(bookKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white.withValues(alpha: 0.85) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersSection(bool isDark) {
    final chapters = HadithService.getChaptersByBook(_selectedBook);
    if (chapters.isEmpty || (chapters.length == 1 && chapters.first == 'الأربعون النووية')) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChapterChip('الكل', isDark),
              ...chapters.map((ch) => _buildChapterChip(ch, isDark)),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildChapterChip(String chapter, bool isDark) {
    final isSelected = _selectedChapter == chapter;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(
          chapter,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.goldDark,
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        onSelected: (v) {
          if (v) {
            setState(() {
              _selectedChapter = chapter;
              _displayedCount = 35;
            });
          }
        },
      ),
    );
  }

  Widget _buildHadithContent(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Theme.of(context).primaryColor),
              const SizedBox(height: 14),
              Text(
                'جاري تحميل ${_getBookDisplayName(_selectedBook)}...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final rawList = HadithService.getHadithsByBook(_selectedBook);
    final filtered = rawList.where((h) {
      if (_selectedChapter != 'الكل' && h.chapter != _selectedChapter) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      return h.title.toLowerCase().contains(q) ||
          h.number.toString() == q ||
          h.matn.toLowerCase().contains(q) ||
          h.narrator.toLowerCase().contains(q) ||
          h.source.toLowerCase().contains(q) ||
          h.chapter.toLowerCase().contains(q) ||
          h.fawaid.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Text(
            'لم يتم العثور على أحاديث تطابق بحثك: "$_searchQuery"',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
      );
    }

    final totalCount = filtered.length;
    final displayedList = filtered.take(_displayedCount).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 720 ? 1 : (width < 1150 ? 2 : 3);

        Widget itemsWidget;
        if (crossAxisCount == 1) {
          itemsWidget = ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, idx) {
              final h = displayedList[idx];
              return HadithCard(
                hadith: h,
                isDark: isDark,
                fontSize: _hadithFontSize,
                onCopy: () => _copyHadith(h),
                onShare: () => _shareHadith(h),
              );
            },
          );
        } else {
          // Sequential Row-based Grid for Desktop & Tablet (Preserves chronological reading sequence)
          final rowCount = (displayedList.length / crossAxisCount).ceil();
          itemsWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int r = 0; r < rowCount; r++) ...[
                if (r > 0) const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int c = 0; c < crossAxisCount; c++) ...[
                      if (c > 0) const SizedBox(width: 14),
                      Expanded(
                        child: (r * crossAxisCount + c < displayedList.length)
                            ? HadithCard(
                                key: ValueKey(
                                  '${displayedList[r * crossAxisCount + c].book}_${displayedList[r * crossAxisCount + c].number}',
                                ),
                                hadith: displayedList[r * crossAxisCount + c],
                                isDark: isDark,
                                fontSize: _hadithFontSize,
                                onCopy: () => _copyHadith(displayedList[r * crossAxisCount + c]),
                                onShare: () => _shareHadith(displayedList[r * crossAxisCount + c]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status bar showing counts
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 16, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'عرض ${displayedList.length} من أصل $totalCount حديثاً في هذا القسم',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            itemsWidget,
            if (_displayedCount < totalCount) ...[
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _displayedCount += 35),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('عرض المزيد من الأحاديث (${displayedList.length}/$totalCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
