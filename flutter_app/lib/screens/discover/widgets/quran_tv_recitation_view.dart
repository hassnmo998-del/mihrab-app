import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/quran_reciter.dart';
import '../../../services/quran_audio_service.dart';
import '../../../services/quran_service.dart';

/// Representation of a visual broadcast TV theme for Quran Recitation.
class QuranTvTheme {
  final String id;
  final String name;
  final String description;
  final List<Color> backgroundGradient;
  final Color primaryTextColor;
  final Color accentGold;
  final Color cardBackgroundColor;
  final Color borderColor;
  final Color glowColor;
  final IconData icon;

  const QuranTvTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.backgroundGradient,
    required this.primaryTextColor,
    required this.accentGold,
    required this.cardBackgroundColor,
    required this.borderColor,
    required this.glowColor,
    required this.icon,
  });

  static const List<QuranTvTheme> allThemes = [
    QuranTvTheme(
      id: 'damascene',
      name: 'الدمشقي الملكي',
      description: 'أخضر زمردي داكن بنقوش دمشقية وذهب عتيق',
      backgroundGradient: [Color(0xFF041A13), Color(0xFF0A2E22), Color(0xFF02100B)],
      primaryTextColor: Color(0xFFFFFDF5),
      accentGold: Color(0xFFE5C158),
      cardBackgroundColor: Color(0xCC062319),
      borderColor: Color(0x66E5C158),
      glowColor: Color(0xFF0D5E43),
      icon: Icons.mosque_rounded,
    ),
    QuranTvTheme(
      id: 'kaaba',
      name: 'كسوة الكعبة المشرفة',
      description: 'أسود ملكي فاحم ببريق حزام الكعبة الذهبي',
      backgroundGradient: [Color(0xFF0A0A0C), Color(0xFF161619), Color(0xFF050507)],
      primaryTextColor: Color(0xFFFFFFFF),
      accentGold: Color(0xFFF7D976),
      cardBackgroundColor: Color(0xDD121215),
      borderColor: Color(0x66F7D976),
      glowColor: Color(0xFF33290E),
      icon: Icons.square_rounded,
    ),
    QuranTvTheme(
      id: 'rawdah',
      name: 'الروضة الشريفة',
      description: 'أخضر المسجد النبوي مع هدوء اللؤلؤ والسكينة',
      backgroundGradient: [Color(0xFF08261C), Color(0xFF124332), Color(0xFF061B14)],
      primaryTextColor: Color(0xFFF4FBF7),
      accentGold: Color(0xFFD6C078),
      cardBackgroundColor: Color(0xCC0D3327),
      borderColor: Color(0x66D6C078),
      glowColor: Color(0xFF1B6B4F),
      icon: Icons.spa_rounded,
    ),
    QuranTvTheme(
      id: 'andalusian',
      name: 'الأزرق الأندلسي',
      description: 'كحلي ليلي ملكي مع بريق النجوم والزليج الأندلسي',
      backgroundGradient: [Color(0xFF051224), Color(0xFF0D2545), Color(0xFF030B17)],
      primaryTextColor: Color(0xFFF0F6FF),
      accentGold: Color(0xFFE2C465),
      cardBackgroundColor: Color(0xCC091E38),
      borderColor: Color(0x66E2C465),
      glowColor: Color(0xFF143E75),
      icon: Icons.nightlight_round,
    ),
    QuranTvTheme(
      id: 'amber',
      name: 'العنبر والمسك',
      description: 'درجات الخشب الملكي والعنبر الداكن بوهج دافئ',
      backgroundGradient: [Color(0xFF200D06), Color(0xFF381A0D), Color(0xFF120703)],
      primaryTextColor: Color(0xFFFFF7ED),
      accentGold: Color(0xFFF5A31A),
      cardBackgroundColor: Color(0xCC2A130A),
      borderColor: Color(0x66F5A31A),
      glowColor: Color(0xFF78350F),
      icon: Icons.wb_sunny_rounded,
    ),
    QuranTvTheme(
      id: 'manuscript',
      name: 'المصحف الورقي العتيق',
      description: 'طراز المخطوطات القديمة وألوان الرق والجلد الأصيل',
      backgroundGradient: [Color(0xFF1A1510), Color(0xFF28211A), Color(0xFF100D0A)],
      primaryTextColor: Color(0xFFFBF4E8),
      accentGold: Color(0xFFD4AF37),
      cardBackgroundColor: Color(0xCC201A14),
      borderColor: Color(0x66D4AF37),
      glowColor: Color(0xFF5E4524),
      icon: Icons.menu_book_rounded,
    ),
    QuranTvTheme(
      id: 'fajr',
      name: 'سماء الفجر والسحر',
      description: 'تصميم حديث أنيق بلون الفحم مع هالة سماوية صافية',
      backgroundGradient: [Color(0xFF0B101B), Color(0xFF151F33), Color(0xFF070B12)],
      primaryTextColor: Color(0xFFF1F5F9),
      accentGold: Color(0xFF38BDF8),
      cardBackgroundColor: Color(0xCC111A2C),
      borderColor: Color(0x6638BDF8),
      glowColor: Color(0xFF0369A1),
      icon: Icons.auto_awesome_rounded,
    ),
  ];
}

/// Fullscreen Serene Quran TV Broadcast View.
class QuranTvRecitationView extends StatefulWidget {
  final int? initialPage;
  final int? initialSurah;
  final int? initialAyah;

  const QuranTvRecitationView({
    super.key,
    this.initialPage,
    this.initialSurah,
    this.initialAyah,
  });

  /// Opens the TV recitation view with a smooth fade transition.
  static Future<void> open(
    BuildContext context, {
    int? initialPage,
    int? initialSurah,
    int? initialAyah,
  }) {
    final audio = QuranAudioService.instance;
    // Auto-start playback if audio was not already playing or loaded!
    if (audio.activeTagNotifier.value == null) {
      final targetPage = initialPage ?? audio.activePageNotifier.value ?? 1;
      final ayahs = QuranService.getPage(targetPage)?.ayahs ?? const [];
      if (ayahs.isNotEmpty) {
        final targetAyah = (initialSurah != null && initialAyah != null)
            ? ayahs.firstWhere(
                (a) => a.surahNumber == initialSurah && a.ayahNumberInSurah == initialAyah,
                orElse: () => ayahs.first,
              )
            : ayahs.first;
        audio.playAyah(targetAyah.surahNumber, targetAyah.ayahNumberInSurah, pageNumber: targetPage);
      }
    }
    // IMPORTANT: If audio.activeTagNotifier.value != null, NEVER reset or restart from page start!
    // The user continues exactly where they were listening.

    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => QuranTvRecitationView(
          initialPage: initialPage,
          initialSurah: initialSurah,
          initialAyah: initialAyah,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  State<QuranTvRecitationView> createState() => _QuranTvRecitationViewState();
}

class _QuranTvRecitationViewState extends State<QuranTvRecitationView>
    with SingleTickerProviderStateMixin {
  final QuranAudioService _audio = QuranAudioService.instance;

  late QuranTvTheme _theme;
  late AnimationController _ambientController;
  Timer? _hideTimer;
  bool _controlsVisible = true;
  double _fontSize = 34.0;

  static const String _prefThemeKey = 'quran_tv_theme_id';
  static const String _prefFontSizeKey = 'quran_tv_font_size';

  static const Map<QuranRepeatScope, String> _scopeLabels = {
    QuranRepeatScope.ayah: 'هذه الآية',
    QuranRepeatScope.page: 'هذه الصفحة',
    QuranRepeatScope.juz: 'هذا الجزء',
    QuranRepeatScope.quran: 'القرآن كاملاً',
  };

  static const Map<QuranStopAfter, String> _stopAfterLabels = {
    QuranStopAfter.ayah: 'بعد الآية',
    QuranStopAfter.surah: 'بعد السورة',
    QuranStopAfter.juz: 'بعد الجزء',
    QuranStopAfter.never: 'لا تتوقف',
  };

  static String _countLabel(int n) => n == -1 ? 'بلا توقف' : (n == 1 ? 'مرة واحدة' : '$n مرات');
  static String _speedLabel(double s) => '${s == s.truncateToDouble() ? s.toInt() : s}×';

  @override
  void initState() {
    super.initState();
    _theme = QuranTvTheme.allThemes[0];
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _loadSavedPreferences();
    _startHideTimer();

    // Ensure playback has started if nothing was active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_audio.activeTagNotifier.value == null) {
        final targetPage = widget.initialPage ?? _audio.activePageNotifier.value ?? 1;
        final ayahs = QuranService.getPage(targetPage)?.ayahs ?? const [];
        if (ayahs.isNotEmpty) {
          final targetAyah = (widget.initialSurah != null && widget.initialAyah != null)
              ? ayahs.firstWhere(
                  (a) => a.surahNumber == widget.initialSurah && a.ayahNumberInSurah == widget.initialAyah,
                  orElse: () => ayahs.first,
                )
              : ayahs.first;
          _audio.playAyah(targetAyah.surahNumber, targetAyah.ayahNumberInSurah, pageNumber: targetPage);
        }
      }
    });
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_prefThemeKey);
      final savedSize = prefs.getDouble(_prefFontSizeKey);

      if (mounted) {
        setState(() {
          if (themeId != null) {
            _theme = QuranTvTheme.allThemes.firstWhere(
              (t) => t.id == themeId,
              orElse: () => QuranTvTheme.allThemes[0],
            );
          }
          if (savedSize != null) {
            _fontSize = savedSize.clamp(22.0, 54.0);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _setTheme(QuranTvTheme theme) async {
    setState(() => _theme = theme);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, theme.id);
    } catch (_) {}
  }

  Future<void> _saveFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefFontSizeKey, _fontSize);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _wakeControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startHideTimer();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wakeControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: _theme.backgroundGradient.first,
        body: MouseRegion(
          onHover: (_) => _wakeControls(),
          child: GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Theme Gradient Background
                _buildBackgroundGradient(),

                // 2. Distinct Architectural Framing & Ambient Animated Motion
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambientController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _TvThemeArtPainter(
                            theme: _theme,
                            progress: _ambientController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 3. Central Ambient Glow Aura
                Center(
                  child: IgnorePointer(
                    child: Container(
                      width: 540,
                      height: 540,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _theme.glowColor.withValues(alpha: 0.28),
                            _theme.glowColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Main Quranic Ayah Presentation (Silky smooth, stationary badges)
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 76),
                      child: _buildAyahDisplay(),
                    ),
                  ),
                ),

                // 5. Top Bar Overlay (Auto-hiding, sleek theme circles dropdown)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: _buildTopBar(),
                      ),
                    ),
                  ),
                ),

                // 6. Floating Transport & Direct Popups Bar (Auto-hiding)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: _buildBottomControls(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.35,
          colors: _theme.backgroundGradient,
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
    );
  }

  /// Displays the active Ayah with broadcast-style typography and rock-solid stationary badges.
  /// ONLY the ayah text transitions with a buttery-soft silk cross-fade!
  Widget _buildAyahDisplay() {
    return ValueListenableBuilder<QuranAyahAudioTag?>(
      valueListenable: _audio.activeTagNotifier,
      builder: (context, tag, _) {
        if (tag == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv_rounded, size: 54, color: _theme.accentGold.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text(
                'وضع التلاوة المتلفزة',
                style: GoogleFonts.amiri(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _theme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر سورة أو اضغط تشغيل لبدء التلاوة العطرة',
                style: TextStyle(
                  fontSize: 14,
                  color: _theme.primaryTextColor.withValues(alpha: 0.65),
                ),
              ),
            ],
          );
        }

        final ayahData = QuranService.getAyah(tag.surahNumber, tag.ayahNumber);
        final ayahText = ayahData?.uthmaniText ?? '';
        final isFirstAyah = tag.ayahNumber == 1;
        final showBasmalah = isFirstAyah && tag.surahNumber != 9 && tag.surahNumber != 1;

        return Column(
          children: [
            // 1. FIXED TOP TITLE (Stationary free title without capsule box - حر بلا غلاف)
            SizedBox(
              height: 34,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    key: ValueKey('tv_surah_title_${tag.surahName}'),
                    'سُورَةُ ${tag.surahName}',
                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _theme.accentGold,
                      shadows: [
                        Shadow(
                          color: _theme.glowColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. MAIN AYAH TEXT (Centered smoothly in the remaining area; only the text cross-fades)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Standalone Basmalah if first ayah of surah
                      if (showBasmalah) ...[
                        Text(
                          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: (_fontSize * 0.82).clamp(20.0, 36.0),
                            fontWeight: FontWeight.bold,
                            color: _theme.accentGold,
                            shadows: [
                              Shadow(
                                color: _theme.glowColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Silk-smooth pure cross-fade on ONLY the ayah text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeInOutCubic,
                        switchOutCurve: Curves.easeInOutCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: Text.rich(
                          key: ValueKey('tv_ayah_text_${tag.key}'),
                          TextSpan(
                            children: [
                              TextSpan(
                                text: ayahText,
                                style: GoogleFonts.amiri(
                                  fontSize: _fontSize,
                                  height: 2.1,
                                  fontWeight: FontWeight.normal,
                                  color: _theme.primaryTextColor,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                    Shadow(
                                      color: _theme.accentGold.withValues(alpha: 0.25),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: ' ${QuranService.formatAyahBracket(tag.ayahNumber)} ',
                                style: GoogleFonts.amiri(
                                  fontSize: _fontSize * 0.9,
                                  fontWeight: FontWeight.bold,
                                  color: _theme.accentGold,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. FIXED BOTTOM FOOTER (Stationary container - never jumps or shifts position)
            SizedBox(
              height: 24,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: ayahData == null
                      ? const SizedBox.shrink()
                      : Text(
                          key: ValueKey('tv_footer_${tag.key}'),
                          'الجزء ${QuranService.toArabicDigits(ayahData.juzNumber)} • الحزب ${QuranService.toArabicDigits(((ayahData.hizbQuarter - 1) ~/ 4) + 1)} • الصفحة ${QuranService.toArabicDigits(ayahData.pageNumber)}',
                          style: GoogleFonts.amiri(
                            fontSize: 13,
                            color: _theme.primaryTextColor.withValues(alpha: 0.6),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Top Bar with Exit, Surah Name, and Swift Theme Dropdown containing ONLY concise color circles!
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Close / Exit Fullscreen Button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 26),
            color: _theme.primaryTextColor,
            tooltip: 'الخروج من وضع ملء الشاشة (Esc)',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),

          // Center Surah Title
          ValueListenableBuilder<QuranAyahAudioTag?>(
            valueListenable: _audio.activeTagNotifier,
            builder: (context, tag, _) {
              final surah = tag?.surahName ?? 'القرآن الكريم';
              return Text(
                'سُورَةُ $surah',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _theme.accentGold,
                ),
              );
            },
          ),
          const Spacer(),

          // Fast Dropdown with Concise Circles (مابدي وصف لأسم الثيم بدي دوائر مختصرة بدون كلام مع منسدلة سريعة)
          _buildQuickThemeDropdown(),
        ],
      ),
    );
  }

  /// Fast dropdown menu opening immediately under the theme button with concise color circles
  Widget _buildQuickThemeDropdown() {
    return PopupMenuButton<QuranTvTheme>(
      tooltip: 'نمط وثيم العرض',
      position: PopupMenuPosition.under,
      color: _theme.cardBackgroundColor.withValues(alpha: 0.96),
      elevation: 12,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: _theme.borderColor, width: 1.2),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<QuranTvTheme>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in QuranTvTheme.allThemes)
                  Tooltip(
                    message: t.name,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _setTheme(t);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: t.backgroundGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: t.id == _theme.id ? _theme.accentGold : Colors.white30,
                            width: t.id == _theme.id ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            if (t.id == _theme.id)
                              BoxShadow(
                                color: _theme.accentGold.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: t.id == _theme.id
                            ? Icon(Icons.check_rounded, size: 16, color: _theme.accentGold)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _theme.cardBackgroundColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _theme.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: _theme.backgroundGradient),
                border: Border.all(color: _theme.accentGold, width: 1.2),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.palette_outlined, size: 16, color: _theme.accentGold),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _theme.accentGold),
          ],
        ),
      ),
    );
  }

  /// Floating Bottom Transport Controls + Direct Familiar Popups
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Primary Transport Buttons (Previous, Play/Pause, Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.skip_previous_rounded),
                color: _theme.primaryTextColor,
                tooltip: 'الآية السابقة',
                onPressed: () {
                  _wakeControls();
                  _audio.skipPrevious();
                },
              ),
              const SizedBox(width: 16),
              ValueListenableBuilder<bool>(
                valueListenable: _audio.isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _audio.isBufferingNotifier,
                    builder: (context, isBuffering, _) {
                      return Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        elevation: 6,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            _wakeControls();
                            if (_audio.activeTagNotifier.value == null) {
                              final targetPage = widget.initialPage ?? _audio.activePageNotifier.value ?? 1;
                              final ayahs = QuranService.getPage(targetPage)?.ayahs ?? const [];
                              if (ayahs.isNotEmpty) {
                                final targetAyah = (widget.initialSurah != null && widget.initialAyah != null)
                                    ? ayahs.firstWhere(
                                        (a) => a.surahNumber == widget.initialSurah && a.ayahNumberInSurah == widget.initialAyah,
                                        orElse: () => ayahs.first,
                                      )
                                    : ayahs.first;
                                _audio.playAyah(targetAyah.surahNumber, targetAyah.ayahNumberInSurah, pageNumber: targetPage);
                              }
                            } else {
                              _audio.togglePlayPause();
                            }
                          },
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  _theme.accentGold,
                                  _theme.accentGold.withValues(alpha: 0.85),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _theme.accentGold.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: isBuffering
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black87,
                                    ),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    size: 34,
                                    color: Colors.black87,
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.skip_next_rounded),
                color: _theme.primaryTextColor,
                tooltip: 'الآية التالية',
                onPressed: () {
                  _wakeControls();
                  _audio.skipNext();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Time & Ayah Progress Line
          _buildProgressIndicator(),
          const SizedBox(height: 10),

          // 3. Compact Familiar Options (Reciter, Scope, Repeat, Stop After, Speed, Font Size)
          // Opens identical lightweight popups like the regular Quran bar without heavy modals!
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _reciterPill(),
              _scopePill(),
              _countPill(),
              _stopAfterPill(),
              _speedPill(),
              _fontSizePill(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _audio.positionNotifier,
      builder: (context, pos, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: _audio.durationNotifier,
          builder: (context, dur, _) {
            final totalMs = dur.inMilliseconds;
            final currentMs = pos.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);
            final progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    _formatDuration(pos),
                    style: TextStyle(fontSize: 11, color: _theme.primaryTextColor.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: _theme.accentGold,
                        inactiveTrackColor: _theme.accentGold.withValues(alpha: 0.2),
                        thumbColor: _theme.accentGold,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (val) {
                          _wakeControls();
                          if (totalMs > 0) {
                            _audio.seek(Duration(milliseconds: (val * totalMs).round()));
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDuration(dur),
                    style: TextStyle(fontSize: 11, color: _theme.primaryTextColor.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // --- Familiar Popups for Bottom Options (نفس نوافذ القرآن العادي الخارجي) ---

  Widget _reciterPill() {
    return ValueListenableBuilder<QuranReciter>(
      valueListenable: _audio.reciterNotifier,
      builder: (context, reciter, _) {
        return _menu<QuranReciter>(
          title: 'اختيار القارئ',
          tooltip: 'القارئ الشيخ',
          values: QuranReciter.defaultReciters,
          selected: reciter,
          labelOf: (r) => r.nameArabic,
          onSelected: (r) {
            _wakeControls();
            _audio.setReciter(r);
          },
          child: _pillWidget(
            icon: Icons.person_rounded,
            label: reciter.nameArabic,
            showArrow: true,
          ),
        );
      },
    );
  }

  Widget _scopePill() {
    return ValueListenableBuilder<QuranRepeatScope>(
      valueListenable: _audio.scopeNotifier,
      builder: (context, scope, _) {
        return _menu<QuranRepeatScope>(
          title: 'نطاق التلاوة والتكرار',
          tooltip: 'اختر نطاق التلاوة',
          values: QuranRepeatScope.values,
          selected: scope,
          labelOf: (s) => _scopeLabels[s]!,
          onSelected: (s) {
            _wakeControls();
            _audio.setScope(s);
          },
          child: _pillWidget(
            icon: scope == QuranRepeatScope.ayah ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            label: _scopeLabels[scope]!,
            showArrow: true,
          ),
        );
      },
    );
  }

  Widget _countPill() {
    return ValueListenableBuilder<int>(
      valueListenable: _audio.repeatCountNotifier,
      builder: (context, count, _) {
        return _menu<int>(
          title: 'تكرار الآية الواحدة',
          tooltip: 'عدد مرات تكرار كل آية',
          values: QuranAudioService.repeatCounts,
          selected: count,
          labelOf: _countLabel,
          onSelected: (c) {
            _wakeControls();
            _audio.setRepeatCount(c);
          },
          child: _pillWidget(
            icon: Icons.repeat_one_rounded,
            label: _countLabel(count),
            showArrow: true,
          ),
        );
      },
    );
  }

  Widget _stopAfterPill() {
    return ValueListenableBuilder<QuranStopAfter>(
      valueListenable: _audio.stopAfterNotifier,
      builder: (context, stopAfter, _) {
        return _menu<QuranStopAfter>(
          title: 'إيقاف التلاوة تلقائياً',
          tooltip: 'متى تتوقف التلاوة تلقائياً',
          values: QuranStopAfter.values,
          selected: stopAfter,
          labelOf: (v) => _stopAfterLabels[v]!,
          onSelected: (v) {
            _wakeControls();
            _audio.setStopAfter(v);
          },
          child: _pillWidget(
            icon: Icons.timer_outlined,
            label: _stopAfterLabels[stopAfter]!,
            showArrow: true,
          ),
        );
      },
    );
  }

  Widget _speedPill() {
    return ValueListenableBuilder<double>(
      valueListenable: _audio.speedNotifier,
      builder: (context, speed, _) {
        return Tooltip(
          message: 'سرعة التلاوة (اضغط للتبديل)',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _wakeControls();
              _audio.cycleSpeed();
            },
            child: _pillWidget(
              icon: Icons.speed_rounded,
              label: _speedLabel(speed),
            ),
          ),
        );
      },
    );
  }

  Widget _fontSizePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _theme.cardBackgroundColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _theme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 14),
            color: _theme.accentGold,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: 'تصغير الخط',
            onPressed: () {
              _wakeControls();
              setState(() => _fontSize = (_fontSize - 3).clamp(22.0, 54.0));
              _saveFontSize();
            },
          ),
          Text(
            'A',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _theme.primaryTextColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 14),
            color: _theme.accentGold,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: 'تكبير الخط',
            onPressed: () {
              _wakeControls();
              setState(() => _fontSize = (_fontSize + 3).clamp(22.0, 54.0));
              _saveFontSize();
            },
          ),
        ],
      ),
    );
  }

  Widget _menu<T>({
    required String title,
    required String tooltip,
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
    required void Function(T) onSelected,
    required Widget child,
  }) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.over,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _theme.borderColor, width: 1.2),
      ),
      color: _theme.cardBackgroundColor.withValues(alpha: 0.96),
      elevation: 8,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<T>(
          enabled: false,
          height: 32,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _theme.accentGold,
            ),
          ),
        ),
        for (final v in values)
          PopupMenuItem<T>(
            value: v,
            height: 38,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: v == selected
                      ? Icon(Icons.check_rounded, size: 16, color: _theme.accentGold)
                      : null,
                ),
                Text(
                  labelOf(v),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: v == selected ? FontWeight.bold : FontWeight.normal,
                    color: v == selected ? _theme.accentGold : _theme.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: child,
    );
  }

  Widget _pillWidget({required IconData icon, required String label, bool showArrow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _theme.cardBackgroundColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _theme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _theme.accentGold),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _theme.primaryTextColor,
            ),
          ),
          if (showArrow) ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: _theme.accentGold),
          ],
        ],
      ),
    );
  }
}

/// Custom Canvas Painter rendering authentic, dignified Islamic architectural framing,
/// Quranic illumination borders, and subtle, serene breathing luminance tailored to each theme.
/// Completely free of distracting animations, floating dots, or rotating shapes.
class _TvThemeArtPainter extends CustomPainter {
  final QuranTvTheme theme;
  final double progress; // 0.0 to 1.0 (serene breathing cycle)

  _TvThemeArtPainter({required this.theme, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Gentle breathing luminescence between 0.15 and 0.28 (comfortable and restful for eyes)
    final breathAlpha = (0.16 + (math.sin(progress * math.pi) * 0.08)).clamp(0.12, 0.30);

    switch (theme.id) {
      case 'damascene':
        _paintDamascene(canvas, size, breathAlpha);
        break;
      case 'kaaba':
        _paintKaaba(canvas, size, breathAlpha);
        break;
      case 'rawdah':
        _paintRawdah(canvas, size, breathAlpha);
        break;
      case 'andalusian':
        _paintAndalusian(canvas, size, breathAlpha);
        break;
      case 'amber':
        _paintAmber(canvas, size, breathAlpha);
        break;
      case 'manuscript':
        _paintManuscript(canvas, size, breathAlpha);
        break;
      case 'fajr':
        _paintFajr(canvas, size, breathAlpha);
        break;
      default:
        _paintDamascene(canvas, size, breathAlpha);
    }
  }

  // =========================================================================
  // Authentic Geometric Islamic Art Helpers
  // =========================================================================

  /// Draws an authentic, stationary 8-pointed Islamic Star (خاتم سليمان / النجمة الثمانية الإسلامية)
  void _drawIslamic8Star(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    bool filled = false,
  }) {
    final path = Path();
    const points = 16;
    final innerRadius = radius * 0.5412; // Classical geometric proportion
    for (int i = 0; i < points; i++) {
      final r = (i % 2 == 0) ? radius : innerRadius;
      final angle = (i * math.pi / 8) - (math.pi / 2);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Draws double manuscript border framing with corner knot rosettes
  void _drawDoubleFrame(
    Canvas canvas,
    Size size,
    Paint paint, {
    double pad1 = 20.0,
    double pad2 = 28.0,
  }) {
    canvas.drawRect(Rect.fromLTWH(pad1, pad1, size.width - pad1 * 2, size.height - pad1 * 2), paint);
    canvas.drawRect(Rect.fromLTWH(pad2, pad2, size.width - pad2 * 2, size.height - pad2 * 2), paint);

    // Corner knot dots
    final dotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    for (final c in [
      Offset(pad2, pad2),
      Offset(size.width - pad2, pad2),
      Offset(pad2, size.height - pad2),
      Offset(size.width - pad2, size.height - pad2),
    ]) {
      canvas.drawCircle(c, 3.0, dotPaint);
      canvas.drawCircle(c, 6.0, paint);
    }
  }

  /// Draws traditional Islamic manuscript corner palmettes / brackets (توريقات وترويسات الأركان التذهيبية)
  void _drawCornerOrnament(
    Canvas canvas,
    Offset corner,
    double length,
    Paint paint, {
    required bool isLeft,
    required bool isTop,
  }) {
    final dx = isLeft ? 1.0 : -1.0;
    final dy = isTop ? 1.0 : -1.0;

    final path = Path()
      ..moveTo(corner.dx, corner.dy + dy * length)
      ..quadraticBezierTo(corner.dx, corner.dy, corner.dx + dx * length, corner.dy);
    canvas.drawPath(path, paint);

    // Inner curved petal
    final petal = Path()
      ..moveTo(corner.dx + dx * 6, corner.dy + dy * (length * 0.7))
      ..quadraticBezierTo(
        corner.dx + dx * (length * 0.4),
        corner.dy + dy * (length * 0.4),
        corner.dx + dx * (length * 0.7),
        corner.dy + dy * 6,
      );
    canvas.drawPath(petal, paint);

    // Corner finial diamond
    final diamond = Path()
      ..moveTo(corner.dx + dx * (length + 4), corner.dy)
      ..lineTo(corner.dx + dx * (length + 8), corner.dy + dy * 4)
      ..lineTo(corner.dx + dx * (length + 12), corner.dy)
      ..lineTo(corner.dx + dx * (length + 8), corner.dy - dy * 4)
      ..close();
    canvas.drawPath(diamond, paint);
  }

  // =========================================================================
  // 1. الدمشقي الملكي: محراب الجامع الأموي الكبير مع تيجان ونقوش دمشقية أصيلة
  // =========================================================================
  void _paintDamascene(Canvas canvas, Size size, double alpha) {
    final goldPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Classic double Islamic border
    _drawDoubleFrame(canvas, size, goldPaint, pad1: 22, pad2: 30);

    // Four Damascus arabesque corner brackets
    _drawCornerOrnament(canvas, const Offset(30, 30), 40, goldPaint, isLeft: true, isTop: true);
    _drawCornerOrnament(canvas, Offset(size.width - 30, 30), 40, goldPaint, isLeft: false, isTop: true);
    _drawCornerOrnament(canvas, Offset(30, size.height - 30), 40, goldPaint, isLeft: true, isTop: false);
    _drawCornerOrnament(canvas, Offset(size.width - 30, size.height - 30), 40, goldPaint, isLeft: false, isTop: false);

    // Grand Umayyad Trefoil Arch at Top Center (قوس المحراب الأموي ثلاثي الفصوص)
    final cx = size.width / 2;
    final topArch = Path()
      ..moveTo(cx - 160, 30)
      ..cubicTo(cx - 130, 80, cx - 70, 75, cx - 50, 55)
      ..cubicTo(cx - 30, 85, cx + 30, 85, cx + 50, 55)
      ..cubicTo(cx + 70, 75, cx + 130, 80, cx + 160, 30);
    canvas.drawPath(topArch, goldPaint);

    // Damascus 8-pointed star medallion nestled in the apex of the arch
    _drawIslamic8Star(canvas, Offset(cx, 74), 11, goldPaint);
    canvas.drawCircle(Offset(cx, 74), 16, goldPaint);

    // Matching subtle bottom inverted cresting
    final bottomArch = Path()
      ..moveTo(cx - 120, size.height - 30)
      ..quadraticBezierTo(cx, size.height - 65, cx + 120, size.height - 30);
    canvas.drawPath(bottomArch, goldPaint);
  }

  // =========================================================================
  // 2. كسوة الكعبة: إطار حزام الكعبة الشريفة مع التقاطيع الهندسية ونجمات التذهيب
  // =========================================================================
  void _paintKaaba(Canvas canvas, Size size, double alpha) {
    final goldPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha * 1.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final fillPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha * 0.4)
      ..style = PaintingStyle.fill;

    const pad = 24.0;
    final outerRect = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);
    canvas.drawRect(outerRect, goldPaint);

    // Top & Bottom Kiswah embroidered bands (شريط حزام الكعبة المذهب)
    const bandHeight = 16.0;
    final topBand = Rect.fromLTWH(pad, pad + 8, size.width - pad * 2, bandHeight);
    final bottomBand = Rect.fromLTWH(pad, size.height - pad - 8 - bandHeight, size.width - pad * 2, bandHeight);
    canvas.drawRect(topBand, goldPaint);
    canvas.drawRect(bottomBand, goldPaint);

    // Geometric chevron braids inside the bands
    const step = 22.0;
    for (double x = pad + 10; x < size.width - pad - 20; x += step) {
      canvas.drawLine(Offset(x, pad + 8), Offset(x + step / 2, pad + 8 + bandHeight), goldPaint);
      canvas.drawLine(Offset(x + step / 2, pad + 8 + bandHeight), Offset(x + step, pad + 8), goldPaint);

      final by = size.height - pad - 8 - bandHeight;
      canvas.drawLine(Offset(x, by), Offset(x + step / 2, by + bandHeight), goldPaint);
      canvas.drawLine(Offset(x + step / 2, by + bandHeight), Offset(x + step, by), goldPaint);
    }

    // Four Kiswah corner medallions with 8-pointed gold stars
    for (final c in [
      const Offset(pad + 16, pad + 16),
      Offset(size.width - pad - 16, pad + 16),
      Offset(pad + 16, size.height - pad - 16),
      Offset(size.width - pad - 16, size.height - pad - 16),
    ]) {
      canvas.drawRect(Rect.fromCenter(center: c, width: 20, height: 20), goldPaint);
      _drawIslamic8Star(canvas, c, 7, fillPaint, filled: true);
    }

    // Top Center: Sacred oval medallion outline ("يا حي يا قيوم")
    final cx = size.width / 2;
    final ovalRect = Rect.fromCenter(center: Offset(cx, pad + 40), width: 72, height: 28);
    canvas.drawOval(ovalRect, goldPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, pad + 40), width: 62, height: 20), goldPaint);
  }

  // =========================================================================
  // 3. الروضة الشريفة: قناطر الحرم النبوي مع النجمة النبوية والهالة اللؤلؤية الساكنة
  // =========================================================================
  void _paintRawdah(Canvas canvas, Size size, double alpha) {
    final goldPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawDoubleFrame(canvas, size, goldPaint, pad1: 22, pad2: 30);

    final cx = size.width / 2;

    // Harmonious pointed arcade arches inspired by the Prophet's Mosque
    for (int i = 0; i < 2; i++) {
      final yOffset = 30.0 + (i * 18);
      final span = 170.0 + (i * 24);
      final arch = Path()
        ..moveTo(cx - span, 30)
        ..quadraticBezierTo(cx - (span * 0.45), yOffset + 38, cx, yOffset + 46)
        ..quadraticBezierTo(cx + (span * 0.45), yOffset + 38, cx + span, 30);
      canvas.drawPath(arch, goldPaint);
    }

    // Center Top: Sublime illuminated Shamsah (شمسة نبوية شريفة)
    final shamsahCenter = Offset(cx, 88);
    _drawIslamic8Star(canvas, shamsahCenter, 13, goldPaint);
    canvas.drawCircle(shamsahCenter, 18, goldPaint);
    canvas.drawCircle(shamsahCenter, 22, goldPaint);

    // Slender side arcade columns along left and right
    const colPad = 48.0;
    canvas.drawLine(Offset(colPad, 90), Offset(colPad, size.height - 90), goldPaint);
    canvas.drawLine(Offset(size.width - colPad, 90), Offset(size.width - colPad, size.height - 90), goldPaint);

    // Column capitals
    canvas.drawRect(Rect.fromCenter(center: Offset(colPad, 90), width: 14, height: 8), goldPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width - colPad, 90), width: 14, height: 8), goldPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(colPad, size.height - 90), width: 14, height: 8), goldPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(size.width - colPad, size.height - 90), width: 14, height: 8), goldPaint);
  }

  // =========================================================================
  // 4. الأزرق الأندلسي: القوس النعلي الموريسكي مع شبكة الزليج الأندلسي الساكنة
  // =========================================================================
  void _paintAndalusian(Canvas canvas, Size size, double alpha) {
    final goldPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawDoubleFrame(canvas, size, goldPaint, pad1: 22, pad2: 30);

    final cx = size.width / 2;

    // Authentic Moorish Horseshoe Arch (القوس النعلي الموريسكي الأندلسي)
    final horseshoe = Path()
      ..moveTo(cx - 130, 30)
      ..cubicTo(cx - 150, 75, cx - 110, 105, cx, 105)
      ..cubicTo(cx + 110, 105, cx + 150, 75, cx + 130, 30);
    canvas.drawPath(horseshoe, goldPaint);

    // Inner concentric horseshoe arch
    final innerHorseshoe = Path()
      ..moveTo(cx - 110, 30)
      ..cubicTo(cx - 128, 68, cx - 90, 92, cx, 92)
      ..cubicTo(cx + 90, 92, cx + 128, 68, cx + 110, 30);
    canvas.drawPath(innerHorseshoe, goldPaint);

    // Four stationary 8-pointed Zellige stars in corner medallions (ساكنة تماماً ومريحة للعين)
    for (final c in [
      const Offset(60, 60),
      Offset(size.width - 60, 60),
      Offset(60, size.height - 60),
      Offset(size.width - 60, size.height - 60),
    ]) {
      _drawIslamic8Star(canvas, c, 14, goldPaint);
      canvas.drawCircle(c, 19, goldPaint);
      // Diamond enclosure
      final diamond = Path()
        ..moveTo(c.dx, c.dy - 24)
        ..lineTo(c.dx + 24, c.dy)
        ..lineTo(c.dx, c.dy + 24)
        ..lineTo(c.dx - 24, c.dy)
        ..close();
      canvas.drawPath(diamond, goldPaint);
    }
  }

  // =========================================================================
  // 5. العنبر والمسك: نقوش المشربية الخشبية التراثية مع قنديل المسجد الهادئ
  // =========================================================================
  void _paintAmber(Canvas canvas, Size size, double alpha) {
    final amberPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    _drawDoubleFrame(canvas, size, amberPaint, pad1: 22, pad2: 30);

    // Four Corner Muqarnas Brackets (مقرنصات إسلامية متدرجة ثلاثية في الزوايا)
    for (final isLeft in [true, false]) {
      for (final isTop in [true, false]) {
        final ox = isLeft ? 30.0 : size.width - 30.0;
        final oy = isTop ? 30.0 : size.height - 30.0;
        final dx = isLeft ? 1.0 : -1.0;
        final dy = isTop ? 1.0 : -1.0;

        for (int step = 1; step <= 3; step++) {
          final s = step * 14.0;
          final p = Path()
            ..moveTo(ox + dx * s, oy)
            ..lineTo(ox + dx * s, oy + dy * (42.0 - s))
            ..lineTo(ox, oy + dy * (42.0 - s));
          canvas.drawPath(p, amberPaint);
        }
      }
    }

    // Top Center: Traditional Hanging Mosque Lantern (قنديل مسجد إسلامي مسرج بسلسلة مذهبة)
    final cx = size.width / 2;
    // Lantern chain
    canvas.drawLine(Offset(cx, 30), Offset(cx, 62), amberPaint);
    // Lantern cap
    final cap = Path()
      ..moveTo(cx - 12, 62)
      ..lineTo(cx + 12, 62)
      ..lineTo(cx + 8, 68)
      ..lineTo(cx - 8, 68)
      ..close();
    canvas.drawPath(cap, amberPaint);
    // Lantern glass body
    final lantern = Path()
      ..moveTo(cx - 8, 68)
      ..cubicTo(cx - 18, 78, cx - 14, 94, cx, 100)
      ..cubicTo(cx + 14, 94, cx + 18, 78, cx + 8, 68)
      ..close();
    canvas.drawPath(lantern, amberPaint);
    // Lantern base ring & pendant drop
    canvas.drawCircle(Offset(cx, 103), 3, amberPaint);
    canvas.drawCircle(Offset(cx, 84), 5, amberPaint);
  }

  // =========================================================================
  // 6. المصحف الورقي العتيق: جدول التذهيب المصحفي السلطاني وعناقيد التوريق
  // =========================================================================
  void _paintManuscript(Canvas canvas, Size size, double alpha) {
    final goldPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha * 1.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const pad1 = 20.0;
    const pad2 = 27.0;
    const pad3 = 34.0;

    // Triple manuscript ruling borders (جداول التذهيب المصحفي الثلاثية)
    canvas.drawRect(Rect.fromLTWH(pad1, pad1, size.width - pad1 * 2, size.height - pad1 * 2), goldPaint);
    canvas.drawRect(Rect.fromLTWH(pad2, pad2, size.width - pad2 * 2, size.height - pad2 * 2), goldPaint);
    canvas.drawRect(Rect.fromLTWH(pad3, pad3, size.width - pad3 * 2, size.height - pad3 * 2), goldPaint);

    // Elaborate corner palmettes (عناقيد وترويسات التذهيب المتقنة في أركان المصاحف)
    for (final isLeft in [true, false]) {
      for (final isTop in [true, false]) {
        final corner = Offset(
          isLeft ? pad3 : size.width - pad3,
          isTop ? pad3 : size.height - pad3,
        );
        _drawCornerOrnament(canvas, corner, 36, goldPaint, isLeft: isLeft, isTop: isTop);
      }
    }

    // Left and Right Margin Quranic Medallions (شمسات الأجزاء والأحزاب في حاشية المصحف)
    final my = size.height / 2;
    for (final mx in [pad2, size.width - pad2]) {
      canvas.drawCircle(Offset(mx, my), 9, goldPaint);
      canvas.drawCircle(Offset(mx, my), 14, goldPaint);
      _drawIslamic8Star(canvas, Offset(mx, my), 6, goldPaint);
    }
  }

  // =========================================================================
  // 7. سماء الفجر والسحر: قبة المسجد مع الهلال الإسلامي والنجمة الثمانية
  // =========================================================================
  void _paintFajr(Canvas canvas, Size size, double alpha) {
    final cyanGoldPaint = Paint()
      ..color = theme.accentGold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Delicate celestial outer frame
    _drawDoubleFrame(canvas, size, cyanGoldPaint, pad1: 22, pad2: 30);

    final cx = size.width / 2;

    // Mosque Celestial Dome Arch (قوس قبة المسجد الرشيق المنحني)
    final domeArch = Path()
      ..moveTo(cx - 150, 30)
      ..quadraticBezierTo(cx, 75, cx + 150, 30);
    canvas.drawPath(domeArch, cyanGoldPaint);

    // Top Center: Classical Islamic Crescent embracing an 8-pointed star (الهلال والنجمة القرآنية)
    final crescentCenter = Offset(cx, 68);
    final crescentPath = Path()
      ..addArc(Rect.fromCircle(center: crescentCenter, radius: 12), -math.pi / 2, math.pi * 1.3)
      ..quadraticBezierTo(crescentCenter.dx + 4, crescentCenter.dy, crescentCenter.dx, crescentCenter.dy - 12);
    canvas.drawPath(crescentPath, cyanGoldPaint);

    // Delicate 8-pointed star resting beside the crescent
    _drawIslamic8Star(canvas, Offset(cx + 14, 68), 5, cyanGoldPaint);

    // Matching bottom serene horizon
    final bottomCurve = Path()
      ..moveTo(cx - 130, size.height - 30)
      ..quadraticBezierTo(cx, size.height - 52, cx + 130, size.height - 30);
    canvas.drawPath(bottomCurve, cyanGoldPaint);
  }

  @override
  bool shouldRepaint(covariant _TvThemeArtPainter oldDelegate) {
    return oldDelegate.theme.id != theme.id || oldDelegate.progress != progress;
  }
}
