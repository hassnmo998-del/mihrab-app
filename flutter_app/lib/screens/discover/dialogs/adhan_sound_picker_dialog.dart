import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/adhan_sound.dart';
import '../../../presentation/widgets/unified_badge.dart';
import '../../../services/adhan_audio_cache_manager.dart';
import '../../../services/adhan_data.dart';
import '../../../services/adhan_service.dart';

/// Modal dialog allowing the user to browse, search, preview, and select
/// from 20 authentic, crystal-clear Adhan sounds across the Islamic world.
class AdhanSoundPickerDialog extends StatefulWidget {
  final bool isDark;

  const AdhanSoundPickerDialog({super.key, required this.isDark});

  static Future<AdhanSound?> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet<AdhanSound>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdhanSoundPickerDialog(isDark: isDark),
    );
  }

  @override
  State<AdhanSoundPickerDialog> createState() => _AdhanSoundPickerDialogState();
}

class _AdhanSoundPickerDialogState extends State<AdhanSoundPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdhanSound> _getFilteredSounds() {
    if (_searchQuery.isEmpty) {
      return AdhanData.allSounds;
    }
    return AdhanData.allSounds.where((sound) {
      final matchesTitle = sound.title.toLowerCase().contains(_searchQuery);
      final matchesMuezzin =
          sound.muezzinOrLocation.toLowerCase().contains(_searchQuery);
      return matchesTitle || matchesMuezzin;
    }).toList();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final service = AdhanService.instance;
    final filtered = _getFilteredSounds();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.record_voice_over_rounded,
                    color: AppColors.goldDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'أصوات الأذان',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.obsidianEspresso,
                            ),
                          ),
                          const SizedBox(width: 8),
                          UnifiedBadge(
                            label: '${AdhanData.allSounds.length} صوت',
                            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                            textColor: isDark ? AppColors.goldLight : AppColors.goldDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'استمع للمعاينة واختر صوت الأذان المفضل لديك',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المؤذن أو المسجد...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),

          // Sounds List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          'لم يتم العثور على أذان مطابق',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ValueListenableBuilder<AdhanSound>(
                    valueListenable: service.selectedSoundNotifier,
                    builder: (context, currentSelected, _) {
                      final cacheManager = AdhanAudioCacheManager.instance;

                      return ValueListenableBuilder<Set<String>>(
                        valueListenable: cacheManager.downloadedSoundIdsNotifier,
                        builder: (context, downloadedIds, _) {
                          return ValueListenableBuilder<Set<String>>(
                            valueListenable: cacheManager.activeDownloadingIdsNotifier,
                            builder: (context, downloadingIds, _) {
                              return ValueListenableBuilder<Map<String, double>>(
                                valueListenable: cacheManager.downloadProgressNotifier,
                                builder: (context, progressMap, _) {
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, idx) {
                                      final sound = filtered[idx];
                                      final isSelected = sound.id == currentSelected.id;
                                      final isDownloaded = cacheManager.isSoundDownloaded(sound.id);
                                      final isDownloading = downloadingIds.contains(sound.id);
                                      final progress = progressMap[sound.id] ?? 0.0;

                                      return ValueListenableBuilder<AdhanSound?>(
                                        valueListenable: service.currentPlayingSoundNotifier,
                                        builder: (context, playingSound, _) {
                                          final isThisPlaying = playingSound?.id == sound.id;

                                          return ValueListenableBuilder<bool>(
                                            valueListenable: service.isPlayingNotifier,
                                            builder: (context, isPlaying, _) {
                                              return ValueListenableBuilder<bool>(
                                                valueListenable: service.isBufferingNotifier,
                                                builder: (context, isBuffering, _) {
                                                  final activePlay = isThisPlaying && isPlaying;
                                                  final activeBuffer = isThisPlaying && isBuffering;

                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                                                          : (isDark ? AppColors.darkSurface : AppColors.lightInputFill),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? Theme.of(context).primaryColor
                                                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                                        width: isSelected ? 1.8 : 1,
                                                      ),
                                                    ),
                                                    child: ListTile(
                                                      contentPadding: const EdgeInsets.symmetric(
                                                          horizontal: 12, vertical: 4),
                                                      leading: InkWell(
                                                        onTap: () => service.playPreview(sound),
                                                        borderRadius: BorderRadius.circular(30),
                                                        child: Container(
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
                                                            shape: BoxShape.circle,
                                                            boxShadow: [
                                                              if (activePlay)
                                                                BoxShadow(
                                                                  color: Colors.orange.withValues(alpha: 0.4),
                                                                  blurRadius: 8,
                                                                  spreadRadius: 1,
                                                                ),
                                                            ],
                                                          ),
                                                          child: Center(
                                                            child: activeBuffer
                                                                ? const SizedBox(
                                                                    width: 18,
                                                                    height: 18,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth: 2,
                                                                      color: Colors.white,
                                                                    ),
                                                                  )
                                                                : Icon(
                                                                    activePlay
                                                                        ? Icons.pause_rounded
                                                                        : Icons.play_arrow_rounded,
                                                                    color: Colors.white,
                                                                    size: 26,
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                      title: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              sound.title,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                                color: isSelected
                                                                    ? (isDark ? Colors.white : Theme.of(context).primaryColor)
                                                                    : (isDark ? Colors.white : AppColors.obsidianEspresso),
                                                              ),
                                                            ),
                                                          ),
                                                          if (isDownloaded)
                                                            Container(
                                                              margin: const EdgeInsets.only(right: 6),
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green.withValues(alpha: 0.15),
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.check_rounded, size: 12, color: Colors.green),
                                                                  SizedBox(width: 3),
                                                                  Text('محلي', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                                                ],
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      subtitle: Row(
                                                        children: [
                                                          Icon(Icons.location_on_outlined,
                                                              size: 13,
                                                              color: isDark ? Colors.white54 : Colors.black45),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              sound.muezzinOrLocation,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: isDark ? Colors.white60 : Colors.black54,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            _formatDuration(sound.durationSeconds),
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontFamily: 'monospace',
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      trailing: _buildTrailing(
                                                        sound: sound,
                                                        isSelected: isSelected,
                                                        isDownloaded: isDownloaded,
                                                        isDownloading: isDownloading,
                                                        progress: progress,
                                                        context: context,
                                                      ),
                                                      onTap: () => _handleSelectSound(context, sound),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailing({
    required AdhanSound sound,
    required bool isSelected,
    required bool isDownloaded,
    required bool isDownloading,
    required double progress,
    required BuildContext context,
  }) {
    if (isDownloading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2.2,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isDownloaded)
          Tooltip(
            message: 'تحميل وحفظ على الهاتف للعمل بدون إنترنت',
            child: IconButton(
              icon: const Icon(Icons.download_rounded, size: 20, color: Colors.grey),
              visualDensity: VisualDensity.compact,
              onPressed: () => _handleDownloadOnly(context, sound),
            ),
          ),
        const SizedBox(width: 2),
        isSelected
            ? Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).primaryColor,
                size: 24,
              )
            : const Icon(
                Icons.radio_button_unchecked_rounded,
                color: Colors.grey,
                size: 22,
              ),
      ],
    );
  }

  Future<void> _handleDownloadOnly(BuildContext context, AdhanSound sound) async {
    final cacheManager = AdhanAudioCacheManager.instance;
    if (cacheManager.isSoundDownloaded(sound.id)) return;

    final hasInternet = await cacheManager.checkInternetConnection(
      timeout: const Duration(seconds: 6),
    );

    if (!hasInternet) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ يلزم اتصال بالإنترنت لتحميل ملف صوت الأذان'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري تحميل أذان ${sound.title} وحفظه على هاتفك... ⏳'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await cacheManager.downloadSound(sound: sound);
  }

  Future<void> _handleSelectSound(BuildContext context, AdhanSound sound) async {
    final cacheManager = AdhanAudioCacheManager.instance;
    final service = AdhanService.instance;

    // Case 1: Already downloaded or bundled default sound
    if (cacheManager.isSoundDownloaded(sound.id)) {
      await service.setSelectedSound(sound);
      if (context.mounted) {
        Navigator.of(context).pop(sound);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تعيين أذان ${sound.title} بنجاح 🔔 (محفوظ أوفلاين)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Case 2: Not downloaded yet -> Check internet connection with patient timeout
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'جاري التحقق من توفر الإنترنت...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'لحفظ أذان ${sound.title} على هاتفك للعمل بدون إنترنت',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    final hasInternet = await cacheManager.checkInternetConnection(
      timeout: const Duration(seconds: 7),
    );

    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss checking dialog
    }

    if (!hasInternet) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 10),
                Text('لا يوجد اتصال بالإنترنت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'يلزم توفر اتصال بالإنترنت لتحميل وحفظ أذان "${sound.title}" في هاتفك لأول مرة.\n\nسيستمر التطبيق باستخدام الأذان الحالي بالموعد ريثما يتوفر الاتصال.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('حسناً فهمت', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Internet is available! Start download and set as pending target
    await cacheManager.queuePendingDownload(sound.id, isTargetSound: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بدأ تحميل أذان ${sound.title} بالخلفية وسيتم تفعيله فور اكتماله ⏳'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop(sound);
    }

    // Trigger background download
    cacheManager.downloadSound(sound: sound).then((success) {
      if (success) {
        service.setSelectedSound(sound);
      }
    });
  }
}
