import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/adhan_sound.dart';
import '../../../presentation/widgets/unified_badge.dart';
import '../../../services/adhan_data.dart';
import '../../../services/adhan_service.dart';

/// Modal dialog allowing the user to browse, search, preview, and select
/// from 110+ authentic Adhan sounds across the Islamic world.
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
  String _selectedCategory = 'الكل';
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
    return AdhanData.allSounds.where((sound) {
      if (_selectedCategory != 'الكل' && sound.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesTitle = sound.title.toLowerCase().contains(_searchQuery);
        final matchesMuezzin =
            sound.muezzinOrLocation.toLowerCase().contains(_searchQuery);
        final matchesCat = sound.category.toLowerCase().contains(_searchQuery);
        if (!matchesTitle && !matchesMuezzin && !matchesCat) {
          return false;
        }
      }
      return true;
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
    final currentSelected = service.selectedSoundNotifier.value;
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
                            'مكتبة أصوات الأذان',
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
                hintText: 'ابحث باسم المقرئ، المسجد، أو البلد...',
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

          // Categories Filter Row
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: AdhanData.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = AdhanData.categories[idx];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppColors.obsidianEspresso),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor,
                  backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              },
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final sound = filtered[idx];
                      final isSelected = sound.id == currentSelected.id;

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
                                      title: Text(
                                        sound.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected
                                              ? (isDark ? Colors.white : Theme.of(context).primaryColor)
                                              : (isDark ? Colors.white : AppColors.obsidianEspresso),
                                        ),
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
                                                fontSize: 11.5,
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
                                      trailing: isSelected
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: Theme.of(context).primaryColor,
                                              size: 24,
                                            )
                                          : const Icon(
                                              Icons.radio_button_unchecked_rounded,
                                              color: Colors.grey,
                                              size: 24,
                                            ),
                                      onTap: () {
                                        service.setSelectedSound(sound);
                                        Navigator.of(context).pop(sound);
                                      },
                                    ),
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
}
