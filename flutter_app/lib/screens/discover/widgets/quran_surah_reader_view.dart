import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/quran_audio_service.dart';
import '../../../services/quran_service.dart';
import 'quran_audio_bar.dart';
import 'quran_data_constants.dart';

/// Classic Full-Surah Continuous Scroll Reader with Tajweed & Bookmark integration.
class QuranSurahReaderView extends StatefulWidget {
  final Map<String, dynamic> surah;
  final bool isDark;
  final VoidCallback onClose;
  final void Function(int surahNum, String surahName, int ayah) onSaveBookmark;
  final int? bookmarkedSurahNumber;
  final void Function(Map<String, dynamic> nextSurah) onOpenSurah;

  const QuranSurahReaderView({
    super.key,
    required this.surah,
    required this.isDark,
    required this.onClose,
    required this.onSaveBookmark,
    this.bookmarkedSurahNumber,
    required this.onOpenSurah,
  });

  @override
  State<QuranSurahReaderView> createState() => _QuranSurahReaderViewState();
}

class _QuranSurahReaderViewState extends State<QuranSurahReaderView> {
  bool _isTajweedMode = false;
  double _fontSize = 22.0;
  final List<GestureRecognizer> _recognizers = [];
  String? _activeAyahKey;

  @override
  void initState() {
    super.initState();
    QuranAudioService.instance.activeAyahNotifier.addListener(_onActiveAyahChanged);
    // Sync initial highlight if audio is already playing
    _activeAyahKey = QuranAudioService.instance.activeAyahNotifier.value;
  }

  @override
  void dispose() {
    QuranAudioService.instance.activeAyahNotifier.removeListener(_onActiveAyahChanged);
    _clearRecognizers();
    super.dispose();
  }

  void _onActiveAyahChanged() {
    final key = QuranAudioService.instance.activeAyahNotifier.value;
    if (mounted && _activeAyahKey != key) {
      setState(() => _activeAyahKey = key);
    }
  }

  /// Instantly highlights the tapped ayah then fires playback async
  void _tapAyah(int surahNum, int ayahNum) {
    setState(() => _activeAyahKey = '$surahNum:$ayahNum');
    QuranAudioService.instance.playAyah(surahNum, ayahNum);
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Builds the full Surah as one inline Text.rich — authentic Quranic flow.
  /// The active Ayah gets a gold background that spans all its lines naturally.
  /// Tap on any word or ayah ornament ﴿n﴾ to play immediately.
  /// Long-press on the ayah ornament to save a bookmark.
  Widget _buildSurahInlineText({
    required BuildContext context,
    required int surahNum,
    required String surahName,
    required List<String> verses,
    required bool isDark,
  }) {
    final spans = <InlineSpan>[];

    for (int i = 0; i < verses.length; i++) {
      final ayahNum = i + 1;
      final ayahKey = '$surahNum:$ayahNum';
      final isActive = _activeAyahKey == ayahKey;
      final activeBg = isActive
          ? AppColors.gold.withValues(alpha: isDark ? 0.22 : 0.15)
          : null;

      if (_isTajweedMode) {
        final tapRec = TapGestureRecognizer()
          ..onTap = () => _tapAyah(surahNum, ayahNum);
        _recognizers.add(tapRec);

        final tajweedChildren = QuranService.buildTajweedSpans(
          verses[i],
          fontSize: _fontSize,
          isDark: isDark,
        );
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
        final tapRec = TapGestureRecognizer()
          ..onTap = () => _tapAyah(surahNum, ayahNum);
        _recognizers.add(tapRec);

        spans.add(TextSpan(
          text: verses[i],
          style: GoogleFonts.amiri(
            fontSize: _fontSize,
            height: 2.15,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.normal,
            backgroundColor: activeBg,
          ),
          recognizer: tapRec,
        ));
      }

      // Ayah ornament ﴿n﴾ — instant tap
      final ornamentTap = TapGestureRecognizer()
        ..onTap = () => _tapAyah(surahNum, ayahNum);
      _recognizers.add(ornamentTap);

      spans.add(TextSpan(
        text: ' ${QuranService.formatAyahBracket(ayahNum)} ',
        style: GoogleFonts.amiri(
          fontSize: _fontSize * 0.88,
          fontWeight: FontWeight.bold,
          color: isActive ? AppColors.goldDark : (isDark ? AppColors.goldLight : AppColors.goldDark),
          backgroundColor: activeBg,
        ),
        recognizer: ornamentTap,
      ));
    }

    // GestureDetector wraps the whole surah text for long-press bookmark
    return GestureDetector(
      onLongPress: () {
        // Long press anywhere → save bookmark at ayah 1
        widget.onSaveBookmark(surahNum, surahName, 1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم حفظ علامة القراءة: سورة $surahName - الآية ١'),
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
    final isDark = widget.isDark;
    final primaryColor = Theme.of(context).primaryColor;
    final surahNum = widget.surah['number'] as int;
    final surahName = widget.surah['name'] as String;
    final isMeccan = widget.surah['type'] == 'meccan';
    final hasBasmalah = surahNum != 9 && surahNum != 1;

    final verses = _isTajweedMode
        ? QuranService.getTajweedVerses(surahNum)
        : QuranService.getUthmaniVerses(surahNum);
    final versesCount = verses.isNotEmpty ? verses.length : (widget.surah['verses'] as int);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation & Control Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'العودة للفهرس',
                onPressed: widget.onClose,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سورة $surahName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${isMeccan ? "مكية 🕋" : "مدنية 🕌"} • $versesCount آية • الجزء ${widget.surah['juz']}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.text_decrease_rounded, size: 18),
                tooltip: 'تصغير الخط',
                onPressed: () {
                  if (_fontSize > 16) setState(() => _fontSize -= 2);
                },
              ),
              IconButton(
                icon: const Icon(Icons.text_increase_rounded, size: 18),
                tooltip: 'تكبير الخط',
                onPressed: () {
                  if (_fontSize < 36) setState(() => _fontSize += 2);
                },
              ),
              IconButton(
                icon: Icon(
                  widget.bookmarkedSurahNumber == surahNum ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: AppColors.gold,
                ),
                tooltip: 'حفظ علامة القراءة',
                onPressed: () => widget.onSaveBookmark(surahNum, surahName, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Fixed audio bar with inline listening options
        QuranAudioBar(
          isDark: isDark,
          idleTitle: 'سورة $surahName',
          onStart: () => QuranAudioService.instance.playAyah(surahNum, 1),
        ),
        const SizedBox(height: 10),

        // Tajweed Toggle Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isTajweedMode
                ? primaryColor.withValues(alpha: 0.1)
                : (isDark ? AppColors.darkSurface : AppColors.lightInputFill),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _isTajweedMode ? primaryColor : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(Icons.color_lens_rounded, color: _isTajweedMode ? primaryColor : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('وضع أحكام التجويد الملونة (مدود، قلقلة، غنن، إخفاء)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Switch(
                value: _isTajweedMode,
                activeThumbColor: primaryColor,
                onChanged: (val) => setState(() => _isTajweedMode = val),
              ),
            ],
          ),
        ),
        if (_isTajweedMode) ...[
          const SizedBox(height: 6),
          _buildTajweedLegend(isDark),
        ],
        const SizedBox(height: 12),

        // Verses Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFFFFDF8),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldDark.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Surah Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withValues(alpha: 0.15), AppColors.gold.withValues(alpha: 0.15)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      'سورة $surahName',
                      style: GoogleFonts.amiri(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.goldLight : AppColors.goldDark,
                      ),
                    ),
                    Text('آياتها $versesCount • الجزء ${widget.surah['juz']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              if (hasBasmalah) ...[
                const SizedBox(height: 16),
                Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Authentic inline Quranic flow — one Text.rich for the whole Surah
              _buildSurahInlineText(
                context: context,
                surahNum: surahNum,
                surahName: surahName,
                verses: verses,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bottom Surah Switchers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (surahNum > 1)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text('سورة ${kQuranSurahs[surahNum - 2]['name']}'),
                onPressed: () => widget.onOpenSurah(kQuranSurahs[surahNum - 2]),
              )
            else
              const SizedBox(),
            if (surahNum < 114)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('سورة ${kQuranSurahs[surahNum]['name']}'),
                onPressed: () => widget.onOpenSurah(kQuranSurahs[surahNum]),
              )
            else
              const SizedBox(),
          ],
        ),
      ],
    );
  }

  Widget _buildTajweedLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: AppColors.goldDark),
              const SizedBox(width: 6),
              Text(
                'دليل ألوان أحكام التجويد:',
                style: GoogleFonts.amiri(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldLight : AppColors.goldDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendItem(const Color(0xFFDC2626), 'المدود (لازم 6، متصل 4-5 حركات)', isDark),
              _legendItem(const Color(0xFFEA580C), 'مد عارض / جائز (2-6 حركات)', isDark),
              _legendItem(const Color(0xFF059669), 'الغنة والإخفاء والإدغام بغنة', isDark),
              _legendItem(const Color(0xFF0284C7), 'القلقلة (ق، ط، ب، ج، د)', isDark),
              _legendItem(const Color(0xFFD97706), 'الإقلاب (مـ)', isDark),
              _legendItem(isDark ? Colors.white38 : Colors.black38, 'حروف لا تُلفظ (رمادي)', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
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
