import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/quran_service.dart';
import '../../../services/tafsir_service.dart';

/// Centered Modal Dialog displaying authentic Tafsir Al-Muyassar for Quranic Ayahs.
/// Features:
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

  @override
  void initState() {
    super.initState();
    _currentAyah = widget.initialAyahNumber.clamp(1, widget.totalAyahs);
    _pageController = PageController(initialPage: _currentAyah - 1);
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
    final copyText = '﴿$ayahText﴾\n\n[التفسير الميسر]:\n$tafsirText\n\n— سورة ${widget.surahName} (الآية $_currentAyah)';
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 0,
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 620,
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
                // Top Header: Title, Ayah counter, and Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      // Surah and Ayah counter Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'سورة ${widget.surahName}',
                                  style: GoogleFonts.amiri(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: gold,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                              'التفسير الميسر • مجمع الملك فهد',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),

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
                      final ayahText = (verses.isNotEmpty && index < verses.length)
                          ? verses[index]
                          : '';
                      final tafsirText = TafsirService.getAyahTafsir(widget.surahNumber, ayahNum);

                      return _buildAyahPage(
                        ayahNum: ayahNum,
                        ayahText: ayahText,
                        tafsirText: tafsirText,
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

  /// Single Ayah card & Tafsir body with smooth vertical scroll to completely prevent overflow
  Widget _buildAyahPage({
    required int ayahNum,
    required String ayahText,
    required String tafsirText,
    required bool isDark,
    required Color gold,
    required Color primaryColor,
  }) {
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
          Container(
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
                          'التفسير وبيان المعنى',
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
}
