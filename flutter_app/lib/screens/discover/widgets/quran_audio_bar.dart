import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/quran_reciter.dart';
import '../../../services/quran_audio_service.dart';

/// Fixed Quran audio bar: transport controls plus all listening options inline
/// (repeat scope, repeat count, speed, reciter) — no separate settings sheet.
class QuranAudioBar extends StatelessWidget {
  final bool isDark;

  /// Title shown while nothing is loaded (e.g. the surah of the visible page).
  final String? idleTitle;

  /// Starts playback from the visible position. When null the bar hides while idle.
  final VoidCallback? onStart;

  /// Outer spacing, applied only while the bar is visible.
  final EdgeInsetsGeometry margin;

  const QuranAudioBar({
    super.key,
    required this.isDark,
    this.idleTitle,
    this.onStart,
    this.margin = EdgeInsets.zero,
  });

  static const Map<QuranRepeatScope, String> _scopeLabels = {
    QuranRepeatScope.ayah: 'هذه الآية',
    QuranRepeatScope.page: 'هذه الصفحة',
    QuranRepeatScope.juz: 'هذا الجزء',
    QuranRepeatScope.quran: 'القرآن كاملاً',
  };

  static const Map<QuranStopAfter, String> _stopAfterLabels = {
    QuranStopAfter.ayah: 'هذه الآية',
    QuranStopAfter.surah: 'هذه السورة',
    QuranStopAfter.juz: 'هذا الجزء',
    QuranStopAfter.never: 'لا تتوقف',
  };

  /// Short pill text; the stop icon next to it reads as "يتوقف بعد…".
  static const Map<QuranStopAfter, String> _stopAfterPillLabels = {
    QuranStopAfter.ayah: 'بعد الآية',
    QuranStopAfter.surah: 'بعد السورة',
    QuranStopAfter.juz: 'بعد الجزء',
    QuranStopAfter.never: 'لا يتوقف',
  };

  static String _countLabel(int n) => n == -1 ? 'بلا توقف' : (n == 1 ? '1 مرة' : '$n مرات');

  /// Bars at least this wide keep transport and options on one line.
  static const double _singleLineMinWidth = 900;

  static String _speedLabel(double s) => '${s == s.truncateToDouble() ? s.toInt() : s}×';

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioService.instance;

    return ValueListenableBuilder<QuranAyahAudioTag?>(
      valueListenable: audio.activeTagNotifier,
      builder: (context, tag, _) {
        if (tag == null && onStart == null) return const SizedBox.shrink();

        return Container(
          margin: margin,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final singleLine = constraints.maxWidth >= _singleLineMinWidth;
                      final transport = [
                        _playButton(context, tag),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _title(tag)),
                        _iconButton(Icons.skip_previous_rounded, 'الآية السابقة', audio.skipPrevious),
                        _iconButton(Icons.skip_next_rounded, 'الآية التالية', audio.skipNext),
                        const SizedBox(width: 4),
                        _speedPill(),
                      ];
                      // Options wrap onto another line instead of overflowing, at any width
                      // or system text size; no pill may be wider than the bar itself.
                      final options = Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: singleLine ? WrapAlignment.end : WrapAlignment.start,
                        children: [
                          for (final pill in [_scopePill(), _countPill(), _stopAfterPill(), _reciterPill()])
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth.clamp(0, 220)),
                              child: pill,
                            ),
                        ],
                      );

                      if (singleLine) {
                        return Row(
                          children: [
                            ...transport,
                            const SizedBox(width: 12),
                            Flexible(flex: 5, child: options),
                          ],
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: transport),
                          const SizedBox(height: 8),
                          options,
                        ],
                      );
                    },
                  ),
                ),
                if (tag != null) _progressLine(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _playButton(BuildContext context, QuranAyahAudioTag? tag) {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: audio.isBufferingNotifier,
      builder: (context, isBuffering, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: audio.isPlayingNotifier,
          builder: (context, isPlaying, _) {
            return Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, AppColors.goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    if (isPlaying) {
                      audio.pause();
                    } else if (tag != null) {
                      audio.resume();
                    } else {
                      onStart?.call();
                    }
                  },
                  child: Center(
                    child: isBuffering && isPlaying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _title(QuranAyahAudioTag? tag) {
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: tag != null ? 'سورة ${tag.surahName}' : (idleTitle ?? ''),
            style: GoogleFonts.amiri(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (tag != null)
            TextSpan(
              text: '  الآية ${tag.ayahNumber}',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: gold),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  Widget _progressLine() {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<Duration>(
      valueListenable: audio.positionNotifier,
      builder: (context, pos, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: audio.durationNotifier,
          builder: (context, dur, _) {
            final progress = dur.inMilliseconds > 0
                ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                : 0.0;
            return LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            );
          },
        );
      },
    );
  }

  Widget _scopePill() {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<QuranRepeatScope>(
      valueListenable: audio.scopeNotifier,
      builder: (context, scope, _) {
        return _menu<QuranRepeatScope>(
          title: 'التكرار',
          tooltip: 'نطاق التكرار',
          values: QuranRepeatScope.values,
          selected: scope,
          labelOf: (s) => _scopeLabels[s]!,
          onSelected: audio.setScope,
          child: _Pill(
            isDark: isDark,
            icon: scope == QuranRepeatScope.ayah ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            label: _scopeLabels[scope]!,
            showArrow: true,
          ),
        );
      },
    );
  }

  Widget _countPill() {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<int>(
      valueListenable: audio.repeatCountNotifier,
      builder: (context, count, _) {
        return _menu<int>(
          title: 'عدد المرات',
          tooltip: 'عدد مرات التكرار',
          values: QuranAudioService.repeatCounts,
          selected: count,
          labelOf: _countLabel,
          onSelected: audio.setRepeatCount,
          child: _Pill(isDark: isDark, label: _countLabel(count), showArrow: true),
        );
      },
    );
  }

  Widget _speedPill() {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<double>(
      valueListenable: audio.speedNotifier,
      builder: (context, speed, _) {
        return Tooltip(
          message: 'سرعة التلاوة',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: audio.cycleSpeed,
            child: _Pill(isDark: isDark, icon: Icons.speed_rounded, label: _speedLabel(speed)),
          ),
        );
      },
    );
  }

  Widget _stopAfterPill() {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<QuranStopAfter>(
      valueListenable: audio.stopAfterNotifier,
      builder: (context, stopAfter, _) {
        return _menu<QuranStopAfter>(
          title: 'يتوقف بعد',
          tooltip: 'يتوقف بعد',
          values: QuranStopAfter.values,
          selected: stopAfter,
          labelOf: (v) => _stopAfterLabels[v]!,
          onSelected: audio.setStopAfter,
          child: _Pill(
            isDark: isDark,
            icon: Icons.stop_circle_outlined,
            label: _stopAfterPillLabels[stopAfter]!,
            showArrow: true,
          ),
        );
      },
    );
  }

  Widget _reciterPill() {
    final audio = QuranAudioService.instance;
    return ValueListenableBuilder<QuranReciter>(
      valueListenable: audio.reciterNotifier,
      builder: (context, reciter, _) {
        return _menu<QuranReciter>(
          title: 'القارئ',
          tooltip: 'القارئ',
          values: QuranReciter.defaultReciters,
          selected: reciter,
          labelOf: (r) => r.nameArabic,
          onSelected: audio.setReciter,
          child: _Pill(
            isDark: isDark,
            icon: Icons.person_rounded,
            label: reciter.nameArabic,
            showArrow: true,
          ),
        );
      },
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
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<T>(
          enabled: false,
          height: 30,
          child: Text(
            title,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black45),
          ),
        ),
        for (final v in values)
          PopupMenuItem<T>(
            value: v,
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: v == selected ? Icon(Icons.check_rounded, size: 16, color: gold) : null,
                ),
                Text(
                  labelOf(v),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: v == selected ? FontWeight.bold : FontWeight.normal,
                    color: v == selected ? gold : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final bool isDark;
  final IconData? icon;
  final String label;
  final bool showArrow;

  const _Pill({
    required this.isDark,
    required this.label,
    this.icon,
    this.showArrow = false,
  });

  /// Below this width the pill shows only its icon, so a squeezed pill (the reciter
  /// on a narrow phone or with large system text) never overflows.
  static const double _iconOnlyBelow = 84;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? Colors.white54 : Colors.black45;
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = icon != null && constraints.maxWidth < _iconOnlyBelow;
        return Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 15, color: isDark ? AppColors.goldLight : AppColors.goldDark),
              if (!iconOnly) ...[
                if (icon != null) const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
                    ),
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more_rounded, size: 16, color: muted),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
