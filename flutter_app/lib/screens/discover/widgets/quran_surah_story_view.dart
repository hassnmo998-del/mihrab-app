import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/quran_service.dart';
import '../../../services/surah_story_service.dart';

/// Screen presenting the rich narrative story and context of Quranic Surahs.
/// Features:
/// - Top bar displaying ONLY the Surah Name and a back button.
/// - Rich narrative text with smooth vertical scroll.
/// - Horizontal swipe (PageView) to smoothly navigate through all 114 Surahs.
/// - Automatically syncs the newly selected Surah to the Quran reader upon exiting.
class QuranSurahStoryView extends StatefulWidget {
  final int initialSurahNumber;
  final bool isDark;
  final void Function(int newSurahNumber)? onSurahChanged;

  const QuranSurahStoryView({
    super.key,
    required this.initialSurahNumber,
    required this.isDark,
    this.onSurahChanged,
  });

  /// Opens the story screen and returns the last viewed Surah number.
  static Future<int?> open({
    required BuildContext context,
    required int initialSurahNumber,
    required bool isDark,
    void Function(int newSurahNumber)? onSurahChanged,
  }) {
    // Ensure story service is loaded
    SurahStoryService.ensureLoaded();

    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (ctx) => QuranSurahStoryView(
          initialSurahNumber: initialSurahNumber,
          isDark: isDark,
          onSurahChanged: onSurahChanged,
        ),
      ),
    );
  }

  @override
  State<QuranSurahStoryView> createState() => _QuranSurahStoryViewState();
}

class _QuranSurahStoryViewState extends State<QuranSurahStoryView> {
  late int _currentSurahNumber;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentSurahNumber = widget.initialSurahNumber.clamp(1, 114);
    _pageController = PageController(initialPage: _currentSurahNumber - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int pageIdx) {
    setState(() {
      _currentSurahNumber = pageIdx + 1;
    });
    widget.onSurahChanged?.call(_currentSurahNumber);
  }

  void _handleExit() {
    Navigator.of(context).pop(_currentSurahNumber);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;
    final currentStory = SurahStoryService.getStory(_currentSurahNumber);
    final surahDisplayName = currentStory?.name.isNotEmpty == true
        ? 'سورة ${currentStory!.name}'
        : 'سورة ${QuranService.getSurahName(_currentSurahNumber)}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFFAF7F0),
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFFFFDF9),
          elevation: 1,
          shadowColor: AppColors.gold.withValues(alpha: 0.2),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'رجوع للمصحف',
            onPressed: _handleExit,
          ),
          // Top bar displaying ONLY the Surah Name as explicitly requested
          title: Text(
            surahDisplayName,
            style: GoogleFonts.amiri(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: gold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${QuranService.toArabicDigits(_currentSurahNumber)} / ١١٤',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.goldLight : AppColors.goldDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: 114,
          physics: const BouncingScrollPhysics(),
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final surahNum = index + 1;
            final storyModel = SurahStoryService.getStory(surahNum);
            final rawName = storyModel?.name ?? QuranService.getSurahName(surahNum);
            final storyText = storyModel?.story ?? 'جاري إعداد قصة السورة...';
            final period = storyModel?.period ?? 'مكية';

            return _buildStoryContent(
              surahNum: surahNum,
              surahName: rawName,
              period: period,
              storyText: storyText,
              isDark: isDark,
              gold: gold,
            );
          },
        ),
      ),
    );
  }

  /// Body for a single Surah with smooth vertical scrolling
  Widget _buildStoryContent({
    required int surahNum,
    required String surahName,
    required String period,
    required String storyText,
    required bool isDark,
    required Color gold,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Elegant decorative story card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldDark.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top subtitle: Revelation place & icon
                Row(
                  children: [
                    Icon(
                      period == 'مكية' ? Icons.nightlight_round : Icons.mosque_rounded,
                      color: gold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$period • ترتيب النزول والسرد التاريخي',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.2)),
                const SizedBox(height: 18),

                // Narrative Story Text
                SelectableText(
                  storyText,
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 2.1,
                    letterSpacing: 0.1,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF2C2416),
                  ),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Bottom navigation hint
          Center(
            child: Text(
              'اسحب يميناً أو يساراً للانتقال إلى السورة التالية أو السابقة',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
