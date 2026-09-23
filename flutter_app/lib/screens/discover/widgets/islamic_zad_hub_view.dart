import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import 'daily_athkar_view.dart';
import 'hadith_encyclopedia_view.dart';
import 'allah_names_view.dart';
import 'spiritual_gems_view.dart';

/// Unified Islamic Spiritual Hub (Zad Al-Muslim & Sunnah 🌿).
/// Combines Daily Athkar, Hadith Encyclopedia (15,200+), 99 Names of Allah,
/// Ruqyah & Duas, Great Rewards, and Prophetic Pearls in one cohesive space.
class IslamicZadHubView extends StatefulWidget {
  final bool isDark;
  final int initialTab;

  const IslamicZadHubView({
    super.key,
    required this.isDark,
    this.initialTab = 0,
  });

  @override
  State<IslamicZadHubView> createState() => _IslamicZadHubViewState();
}

class _IslamicZadHubViewState extends State<IslamicZadHubView> {
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Spiritual Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F2E28), const Color(0xFF1B4332)]
                  : [const Color(0xFF1B4332), const Color(0xFF2D6A4F)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_stories_rounded, color: AppColors.goldBright, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'زاد المسلم والسنة النبوية المشرفة 🌿',
                      style: GoogleFonts.notoNaskhArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الأذكار اليومية • موسوعة الحديث الشريف • أسماء الله الـ 99 • الرقية والدرر',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Main Spiritual Navigation Bar
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
                _buildTabButton(0, Icons.favorite_rounded, 'أذكار المسلم ☀️'),
                const SizedBox(width: 4),
                _buildTabButton(1, Icons.menu_book_rounded, 'موسوعة الحديث 📜'),
                const SizedBox(width: 4),
                _buildTabButton(2, Icons.auto_awesome_rounded, 'أسماء الله الحسنى ✨ (99)'),
                const SizedBox(width: 4),
                _buildTabButton(3, Icons.shield_rounded, 'الرقية والكنوز والدرر 🛡️'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected Sub-View
        _buildActiveView(isDark),
      ],
    );
  }

  Widget _buildTabButton(int index, IconData icon, String title) {
    final isSelected = _activeTab == index;
    final isDark = widget.isDark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveView(bool isDark) {
    switch (_activeTab) {
      case 0:
        return DailyAthkarView(isDark: isDark);
      case 1:
        return HadithEncyclopediaView(isDark: isDark);
      case 2:
        return AllahNamesView(isDark: isDark);
      case 3:
      default:
        return SpiritualGemsView(isDark: isDark);
    }
  }
}
