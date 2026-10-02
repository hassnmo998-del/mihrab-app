import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/quran_service.dart';
import '../../../services/tafsir_service.dart';

/// Centered Modal Dialog displaying authentic Tafsir (Al-Muyassar, Ibn Kathir, Al-Saadi, etc.) for Quranic Ayahs.
/// Features:
/// - Selector in the header to switch between Tafsir commentators on the fly.
/// - Offline instant display for Al-Muyassar, and on-demand cached retrieval for Ibn Kathir and others.
/// - Centered on screen with smooth transition and backdrop dismissal.
/// - Horizontal swipe between Ayahs strictly within the same Surah (bounded).
/// - Long Ayah & lengthy Tafsir vertical smooth scrolling (zero overflow).
/// - Copy to clipboard & clean, uncluttered Islamic typography.
class QuranAyahTafsirSheet extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int initialAyahNumber;
  final int totalAyahs;
  final bool isDark;

  const QuranAyahTafsirSheet({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.initialAyahNumber,
    required this.totalAyahs,
    required this.isDark,
  });

  /// Static helper to show the dialog seamlessly in the center of the screen
  static Future<void> show({
    required BuildContext context,
    required int surahNumber,
    required String surahName,
    required int initialAyahNumber,
    required int totalAyahs,
    required bool isDark,
  }) {
    // Ensure Tafsir service is loaded
    TafsirService.ensureLoaded();

    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => QuranAyahTafsirSheet(
        surahNumber: surahNumber,
        surahName: surahName,
        initialAyahNumber: initialAyahNumber,
        totalAyahs: totalAyahs,
        isDark: isDark,
      ),
    );
  }

  @override
  State<QuranAyahTafsirSheet> createState() => _QuranAyahTafsirSheetState();
}

class _QuranAyahTafsirSheetState extends State<QuranAyahTafsirSheet> {
  late int _currentAyah;
  late PageController _pageController;
  late TafsirEdition _selectedEdition;

  @override
  void initState() {
    super.initState();
    _currentAyah = widget.initialAyahNumber.clamp(1, widget.totalAyahs);
    _pageController = PageController(initialPage: _currentAyah - 1);
    _selectedEdition = TafsirService.selectedEdition;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int pageIdx) {
    setState(() {
      _currentAyah = pageIdx + 1;
    });
  }

  void _copyAyahAndTafsir(String ayahText, String tafsirText) {
    final copyText =
        '﴿$ayahText﴾\n\n[${_selectedEdition.name}]:\n$tafsirText\n\n— سورة ${widget.surahName} (الآية $_currentAyah)';
    Clipboard.setData(ClipboardData(text: copyText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('تم نسخ الآية وتفسيرها بنجاح ✨'),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;
    final primaryColor = Theme.of(context).primaryColor;
    final mediaQuery = MediaQuery.of(context);
    final maxDialogHeight = mediaQuery.size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: const RoundedRectangleBorder(
        side: BorderSide.none,
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: maxDialogHeight,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header: Title, Ayah counter, Tafsir Selector and Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Surah and Ayah counter Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'سورة ${widget.surahName}',
                                  style: GoogleFonts.amiri(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: gold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'الآية $_currentAyah من ${widget.totalAyahs}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedEdition.author,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Tafsir Selector Dropdown Menu
                      _buildTafsirSelectorMenu(isDark: isDark, gold: gold),

                      const SizedBox(width: 4),

                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: isDark ? Colors.white70 : Colors.black54,
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.2)),

                // Horizontal PageView strictly bounded to 1..totalAyahs of this Surah
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.totalAyahs,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final ayahNum = index + 1;
                      final verses = QuranService.getUthmaniVerses(widget.surahNumber);
                      final ayahText =
                          (verses.isNotEmpty && index < verses.length) ? verses[index] : '';

                      return _buildAyahPage(
                        ayahNum: ayahNum,
                        ayahText: ayahText,
                        isDark: isDark,
                        gold: gold,
                        primaryColor: primaryColor,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact, stylish popup menu to select commentator on the fly
  Widget _buildTafsirSelectorMenu({
    required bool isDark,
    required Color gold,
  }) {
    return PopupMenuButton<TafsirEdition>(
      initialValue: _selectedEdition,
      tooltip: 'اختيار المفسر',
      onSelected: (edition) {
        if (edition == _selectedEdition) return;
        setState(() {
          _selectedEdition = edition;
        });
        TafsirService.setSelectedEdition(edition);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      color: isDark ? const Color(0xFF1E2620) : const Color(0xFFFDFCF9),
      elevation: 8,
      itemBuilder: (context) => TafsirEdition.values.map((edition) {
        final isSelected = edition == _selectedEdition;
        return PopupMenuItem<TafsirEdition>(
          value: edition,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: isSelected ? gold : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      edition.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? gold : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      edition.isOffline
                          ? 'متاح بدون إنترنت (أوفلاين)'
                          : 'تحميل مباشر وحفظ محلي تلقائي',
                      style: TextStyle(
                        fontSize: 10,
                        color: edition.isOffline
                            ? Colors.green
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 14, color: gold),
            const SizedBox(width: 5),
            Text(
              _selectedEdition.shortName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: gold,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: gold),
          ],
        ),
      ),
    );
  }

  /// Single Ayah card & Tafsir body with smooth vertical scroll to completely prevent overflow
  Widget _buildAyahPage({
    required int ayahNum,
    required String ayahText,
    required bool isDark,
    required Color gold,
    required Color primaryColor,
  }) {
    final cachedSync = TafsirService.getAyahTafsirSync(
      widget.surahNumber,
      ayahNum,
      _selectedEdition,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ayah Box (Top)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: isDark ? 0.18 : 0.08),
                  AppColors.gold.withValues(alpha: isDark ? 0.15 : 0.08),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ayah Text in Uthmani Amiri Font
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: ayahText.isNotEmpty ? ayahText : 'الآية $ayahNum',
                        style: GoogleFonts.amiri(
                          fontSize: 20,
                          height: 2.1,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' ﴿${QuranService.toArabicDigits(ayahNum)}﴾ ',
                        style: GoogleFonts.amiri(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tafsir Card (Bottom)
          if (cachedSync != null)
            _buildTafsirCard(
              ayahNum: ayahNum,
              ayahText: ayahText,
              tafsirText: cachedSync,
              isDark: isDark,
              gold: gold,
            )
          else
            FutureBuilder<String>(
              key: ValueKey('${_selectedEdition.id}_${widget.surahNumber}_$ayahNum'),
              future: TafsirService.getAyahTafsirAsync(
                widget.surahNumber,
                ayahNum,
                _selectedEdition,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: gold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'جاري تحميل ${_selectedEdition.name} للآية $ayahNum...',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final text = snapshot.data ?? 'لا يتوفر تفسير لهذه الآية حالياً.';
                return _buildTafsirCard(
                  ayahNum: ayahNum,
                  ayahText: ayahText,
                  tafsirText: text,
                  isDark: isDark,
                  gold: gold,
                );
              },
            ),

          const SizedBox(height: 14),

          // Bottom navigation hint (Swipe to next/prev ayah within surah)
          Center(
            child: Text(
              'اسحب يميناً أو يساراً للتنقل بين آيات السورة (${widget.totalAyahs} آية)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the loaded Tafsir card with clean typography and copy button
  Widget _buildTafsirCard({
    required int ayahNum,
    required String ayahText,
    required String tafsirText,
    required bool isDark,
    required Color gold,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tafsir header & Copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded, color: gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _selectedEdition.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _copyAyahAndTafsir(ayahText, tafsirText),
                icon: Icon(Icons.copy_rounded, size: 15, color: gold),
                label: Text(
                  'نسخ',
                  style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tafsir Text
          Text(
            tafsirText,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.85,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
