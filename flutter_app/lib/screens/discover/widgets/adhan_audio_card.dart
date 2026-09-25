import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/adhan_sound.dart';
import '../../../services/adhan_service.dart';
import '../dialogs/adhan_permissions_dialog.dart';
import '../dialogs/adhan_sound_picker_dialog.dart';

/// Top Audio Card for Adhan sound selection, live preview, and notification controls.
/// Styled following the Quran audio bar aesthetic with Damascus gold accents.
class AdhanAudioCard extends StatelessWidget {
  final bool isDark;
  final EdgeInsetsGeometry margin;

  const AdhanAudioCard({
    super.key,
    required this.isDark,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final service = AdhanService.instance;

    return ValueListenableBuilder<AdhanSound>(
      valueListenable: service.selectedSoundNotifier,
      builder: (context, selectedSound, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: service.isEnabledNotifier,
          builder: (context, isEnabled, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: service.liveFiringPrayerNotifier,
              builder: (context, livePrayer, _) {
                final isLiveFiring = livePrayer != null;

                return Container(
                  margin: margin,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isLiveFiring
                          ? Colors.orange
                          : AppColors.gold.withValues(alpha: 0.35),
                      width: isLiveFiring ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isLiveFiring)
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLiveFiring)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            color: Colors.orange.withValues(alpha: 0.15),
                            child: Row(
                              children: [
                                const Icon(Icons.volume_up_rounded,
                                    size: 18, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'يصدح الآن أذان $livePrayer بصوت ${selectedSound.muezzinOrLocation} 🕌',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => service.stop(),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.stop_rounded, size: 16),
                                  label: const Text('إيقاف الأذان',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final singleLine = constraints.maxWidth >= 720;

                              final transport = [
                                _playButton(context, selectedSound),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _soundTitle(context, selectedSound),
                                ),
                              ];

                              final options = Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: singleLine
                                    ? WrapAlignment.end
                                    : WrapAlignment.start,
                                children: [
                                  // Sound picker pill (111 sounds)
                                  _pickerPill(context, selectedSound),

                                  // Master toggle pill with permission check
                                  _enableTogglePill(context, isEnabled),

                                  // Iqama times adjustment pill
                                  _iqamaSettingsPill(context),

                                  // Volume pill
                                  _volumePill(context),
                                ],
                              );

                              if (singleLine) {
                                return Row(
                                  children: [
                                    ...transport,
                                    const SizedBox(width: 12),
                                    Flexible(flex: 3, child: options),
                                  ],
                                );
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: transport),
                                  const SizedBox(height: 10),
                                  options,
                                ],
                              );
                            },
                          ),
                        ),

                        // Progress indicator line when previewing
                        _progressLine(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _playButton(BuildContext context, AdhanSound sound) {
    final service = AdhanService.instance;

    return ValueListenableBuilder<AdhanSound?>(
      valueListenable: service.currentPlayingSoundNotifier,
      builder: (context, playingSound, _) {
        final isThis = playingSound?.id == sound.id;

        return ValueListenableBuilder<bool>(
          valueListenable: service.isBufferingNotifier,
          builder: (context, isBuffering, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: service.isPlayingNotifier,
              builder: (context, isPlaying, _) {
                final activePlay = isThis && isPlaying;
                final activeBuffer = isThis && isBuffering;

                return Material(
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: activePlay
                            ? [Colors.orange, AppColors.goldDark]
                            : [
                                Theme.of(context).primaryColor,
                                AppColors.goldDark
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => service.playPreview(sound),
                      child: Center(
                        child: activeBuffer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                activePlay
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _soundTitle(BuildContext context, AdhanSound sound) {
    final gold = isDark ? AppColors.goldLight : AppColors.goldDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              sound.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.amiri(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sound.category,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          sound.muezzinOrLocation,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: gold,
          ),
        ),
      ],
    );
  }

  Widget _pickerPill(BuildContext context, AdhanSound sound) {
    return Tooltip(
      message: 'تغيير صوت الأذان (111 صوت متاح)',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => AdhanSoundPickerDialog.show(context, isDark: isDark),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 15,
                color: isDark ? AppColors.goldLight : AppColors.goldDark,
              ),
              const SizedBox(width: 5),
              const Text(
                'اختيار الصوت (111)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enableTogglePill(BuildContext context, bool isEnabled) {
    final service = AdhanService.instance;

    return Tooltip(
      message: isEnabled ? 'الأذان مفعّل 🔔 - اضغط للتعطيل' : 'الأذان صامت 🔕 - اضغط للتفعيل',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          if (!isEnabled) {
            // Check strict permissions on Android before turning on!
            final status = await service.checkPermissionsStatus();
            if (!status.isFullyGuaranteed) {
              if (context.mounted) {
                final approved = await AdhanPermissionsDialog.show(
                  context,
                  isDark: isDark,
                );
                if (approved) {
                  await service.setAdhanEnabled(true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تفعيل تنبيهات الأذان بنجاح 🔔'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
              return;
            }
            await service.setAdhanEnabled(true);
          } else {
            await service.setAdhanEnabled(false);
          }
        },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isEnabled
                ? (isDark
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.12))
                : (isDark ? AppColors.darkSurface : AppColors.lightInputFill),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled
                  ? Colors.green.withValues(alpha: 0.6)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                size: 15,
                color: isEnabled ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 5),
              Text(
                isEnabled ? 'الأذان: مفعّل 🔔' : 'الأذان: صامت 🔕',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isEnabled
                      ? Colors.green
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iqamaSettingsPill(BuildContext context) {
    final service = AdhanService.instance;

    return PopupMenuButton<String>(
      tooltip: 'تخصيص مدة الإقامة لكل صلاة',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      itemBuilder: (ctx) => [
        const PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            'مدة الإقامة بعد الأذان',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        for (final p in ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'])
          PopupMenuItem<String>(
            value: p,
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${service.getIqamaMinutes(p)} دقيقة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.goldDark,
                  ),
                ),
              ],
            ),
          ),
      ],
      onSelected: (prayer) => _showIqamaDurationPicker(context, prayer),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timelapse_rounded,
              size: 15,
              color: isDark ? AppColors.goldLight : AppColors.goldDark,
            ),
            const SizedBox(width: 5),
            const Text(
              'أوقات الإقامة',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showIqamaDurationPicker(BuildContext context, String prayer) {
    final service = AdhanService.instance;
    final currentMin = service.getIqamaMinutes(prayer);

    showDialog(
      context: context,
      builder: (ctx) {
        int selected = currentMin;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              title: Text('مدة إقامة صلاة $prayer',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('حدد الدقائق بين الأذان والإقامة:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 20, 25, 30].map((m) {
                      final isSel = selected == m;
                      return ChoiceChip(
                        label: Text('$m دقيقة'),
                        selected: isSel,
                        selectedColor: Theme.of(context).primaryColor,
                        onSelected: (_) => setDialogState(() => selected = m),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await service.setIqamaMinutes(prayer, selected);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _volumePill(BuildContext context) {
    final service = AdhanService.instance;

    return PopupMenuButton<double>(
      tooltip: 'مستوى صوت الأذان',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      itemBuilder: (ctx) => [
        const PopupMenuItem<double>(
          enabled: false,
          height: 30,
          child: Text('مستوى صوت الأذان',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        for (final v in [1.0, 0.8, 0.5, 0.3])
          PopupMenuItem<double>(
            value: v,
            height: 38,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: (service.volume - v).abs() < 0.05
                      ? Icon(Icons.check_rounded, size: 16, color: AppColors.goldDark)
                      : null,
                ),
                Text('${(v * 100).toInt()}%'),
              ],
            ),
          ),
      ],
      onSelected: (vol) => service.setVolume(vol),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_up_rounded,
              size: 15,
              color: isDark ? AppColors.goldLight : AppColors.goldDark,
            ),
            const SizedBox(width: 5),
            Text(
              '${(service.volume * 100).toInt()}%',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _progressLine() {
    final service = AdhanService.instance;

    return ValueListenableBuilder<AdhanSound?>(
      valueListenable: service.currentPlayingSoundNotifier,
      builder: (context, playing, _) {
        if (playing == null) return const SizedBox.shrink();

        return ValueListenableBuilder<Duration>(
          valueListenable: service.positionNotifier,
          builder: (context, pos, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: service.durationNotifier,
              builder: (context, dur, _) {
                final progress = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                );
              },
            );
          },
        );
      },
    );
  }
}
