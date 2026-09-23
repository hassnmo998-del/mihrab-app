import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'zad_card.dart';
import 'zad_data_constants.dart';
import 'zad_detail_dialog.dart';

/// Interactive View displaying Ruqyah & Duas, Great Reward Deeds, and Prophetic Seerah Pearls.
class SpiritualGemsView extends StatefulWidget {
  final bool isDark;

  const SpiritualGemsView({super.key, required this.isDark});

  @override
  State<SpiritualGemsView> createState() => _SpiritualGemsViewState();
}

class _SpiritualGemsViewState extends State<SpiritualGemsView> {
  int _selectedSubTab = 0; // 0: Ruqyah & Duas, 1: Great Rewards, 2: Seerah Pearls
  String _selectedDuaCategory = 'all';
  double _fontSize = 17.0;
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-Tabs Bar: الرقية والأدعية | أجور مضاعفة | قبسات السيرة
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightInputFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildSubTab(0, Icons.healing_rounded, 'الرقية والأدعية (${ZadDataConstants.ruqyahAndDuas.length})'),
                const SizedBox(width: 4),
                _buildSubTab(1, Icons.workspace_premium_rounded, 'أجور مضاعفة (${ZadDataConstants.greatRewardDeeds.length})'),
                const SizedBox(width: 4),
                _buildSubTab(2, Icons.menu_book_rounded, 'قبسات السيرة (${ZadDataConstants.propheticPearls.length})'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Controls Row: Search Input + Font Scaler Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث في النصوص والمعاني والمصادر...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Font scale controls
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    tooltip: 'تصغير الخط',
                    visualDensity: VisualDensity.compact,
                    onPressed: _fontSize > 14
                        ? () => setState(() => _fontSize = (_fontSize - 1).clamp(14, 26))
                        : null,
                  ),
                  Text(
                    '${_fontSize.toInt()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    tooltip: 'تكبير الخط',
                    visualDensity: VisualDensity.compact,
                    onPressed: _fontSize < 26
                        ? () => setState(() => _fontSize = (_fontSize + 1).clamp(14, 26))
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Dua Category Chips (only for SubTab 0: Ruqyah & Duas)
        if (_selectedSubTab == 0) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDuaCategoryChip('الكل 📿', 'all'),
                const SizedBox(width: 8),
                _buildDuaCategoryChip('الرقية الشرعية 🛡️', 'ruqyah'),
                const SizedBox(width: 8),
                _buildDuaCategoryChip('تفريج الكرب والهم 🤲', 'kurb'),
                const SizedBox(width: 8),
                _buildDuaCategoryChip('الرزق وقضاء الدَّين 💰', 'rizq'),
                const SizedBox(width: 8),
                _buildDuaCategoryChip('الشفاء وعيادة المريض 🩺', 'health'),
                const SizedBox(width: 8),
                _buildDuaCategoryChip('حفظ الأهل والأولاد 👨‍👩‍👧‍👦', 'family'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Responsive Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = _getFilteredCards(context, isDark);

            if (cards.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'لا توجد نصوص مطابقة لبحثك: "$_searchQuery"',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  ),
                ),
              );
            }

            final width = constraints.maxWidth;
            final crossAxisCount = width < 680 ? 1 : (width < 1100 ? 2 : 3);

            if (crossAxisCount == 1) {
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, idx) => cards[idx],
              );
            }

            // Multi-column sequential row-based layout
            final rowCount = (cards.length / crossAxisCount).ceil();
            return Column(
              children: List.generate(rowCount, (rowIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(crossAxisCount, (colIndex) {
                      final itemIndex = rowIndex * crossAxisCount + colIndex;
                      if (itemIndex < cards.length) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: colIndex == 0 ? 0 : 7,
                              left: colIndex == crossAxisCount - 1 ? 0 : 7,
                            ),
                            child: cards[itemIndex],
                          ),
                        );
                      }
                      return const Expanded(child: SizedBox.shrink());
                    }),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubTab(int index, IconData icon, String title) {
    final isSelected = _selectedSubTab == index;
    final isDark = widget.isDark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuaCategoryChip(String label, String value) {
    final isSelected = _selectedDuaCategory == value;
    final primaryColor = Theme.of(context).primaryColor;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: primaryColor,
      onSelected: (_) => setState(() => _selectedDuaCategory = value),
    );
  }

  List<ZadItemCard> _getFilteredCards(BuildContext context, bool isDark) {
    final query = _searchQuery;

    if (_selectedSubTab == 0) {
      return ZadDataConstants.ruqyahAndDuas
          .where((item) =>
              (_selectedDuaCategory == 'all' || item.category == _selectedDuaCategory) &&
              (query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  item.arabicText.toLowerCase().contains(query) ||
                  item.instruction.toLowerCase().contains(query) ||
                  item.source.toLowerCase().contains(query)))
          .map((item) {
        final card = ZadItemCard(
          title: item.title,
          categoryName: item.categoryName,
          content: item.arabicText,
          instructionOrDua: item.instruction,
          source: item.source,
          categoryIcon: Icons.favorite_rounded,
          accentColor: AppColors.emeraldPrimary,
          fontSize: _fontSize,
          isDark: isDark,
        );
        return ZadItemCard(
          title: card.title,
          categoryName: card.categoryName,
          content: card.content,
          instructionOrDua: card.instructionOrDua,
          source: card.source,
          categoryIcon: card.categoryIcon,
          accentColor: card.accentColor,
          fontSize: card.fontSize,
          isDark: card.isDark,
          onTap: () => ZadDetailDialog.show(context, card, _fontSize, isDark),
        );
      }).toList();
    } else if (_selectedSubTab == 1) {
      return ZadDataConstants.greatRewardDeeds
          .where((item) =>
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.hadithMatn.toLowerCase().contains(query) ||
              item.rewardDescription.toLowerCase().contains(query) ||
              item.actionTip.toLowerCase().contains(query) ||
              item.source.toLowerCase().contains(query))
          .map((item) {
        final card = ZadItemCard(
          title: item.title,
          categoryName: item.category,
          subtitle: item.actionTip,
          content: item.hadithMatn,
          reflectionOrBenefit: item.rewardDescription,
          source: item.source,
          categoryIcon: Icons.workspace_premium_rounded,
          accentColor: AppColors.terracottaPrimary,
          fontSize: _fontSize,
          isDark: isDark,
        );
        return ZadItemCard(
          title: card.title,
          categoryName: card.categoryName,
          subtitle: card.subtitle,
          content: card.content,
          reflectionOrBenefit: card.reflectionOrBenefit,
          source: card.source,
          categoryIcon: card.categoryIcon,
          accentColor: card.accentColor,
          fontSize: card.fontSize,
          isDark: card.isDark,
          onTap: () => ZadDetailDialog.show(context, card, _fontSize, isDark),
        );
      }).toList();
    } else {
      return ZadDataConstants.propheticPearls
          .where((item) =>
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.contextStory.toLowerCase().contains(query) ||
              item.practicalLesson.toLowerCase().contains(query) ||
              item.topic.toLowerCase().contains(query) ||
              item.source.toLowerCase().contains(query))
          .map((item) {
        final card = ZadItemCard(
          title: item.title,
          categoryName: item.topic,
          content: item.contextStory,
          reflectionOrBenefit: item.practicalLesson,
          source: item.source,
          categoryIcon: Icons.lightbulb_rounded,
          accentColor: AppColors.emeraldPrimary,
          fontSize: _fontSize,
          isDark: isDark,
        );
        return ZadItemCard(
          title: card.title,
          categoryName: card.categoryName,
          content: card.content,
          reflectionOrBenefit: card.reflectionOrBenefit,
          source: card.source,
          categoryIcon: card.categoryIcon,
          accentColor: card.accentColor,
          fontSize: card.fontSize,
          isDark: card.isDark,
          onTap: () => ZadDetailDialog.show(context, card, _fontSize, isDark),
        );
      }).toList();
    }
  }
}
