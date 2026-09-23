import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/allah_names_full_data.dart';
import 'zad_card.dart';
import 'zad_detail_dialog.dart';

/// Interactive View displaying all 99 Beautiful Names of Allah with meanings,
/// heart reflections, authentic duas, and adaptive multi-column grid layout.
class AllahNamesView extends StatefulWidget {
  final bool isDark;

  const AllahNamesView({super.key, required this.isDark});

  @override
  State<AllahNamesView> createState() => _AllahNamesViewState();
}

class _AllahNamesViewState extends State<AllahNamesView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  double _fontSize = 17.0;

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
        // Controls Row: Search Input + Font Scaler Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الاسم أو اسمه أو المعنى أو الدعاء...',
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
                        'لا توجد أسماء مطابقة لبحثك: "$_searchQuery"',
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

  List<ZadItemCard> _getFilteredCards(BuildContext context, bool isDark) {
    final query = _searchQuery;

    return AllahNamesFullData.names
        .where((item) =>
            query.isEmpty ||
            item.number.toString() == query ||
            item.name.toLowerCase().contains(query) ||
            item.meaning.toLowerCase().contains(query) ||
            item.reflection.toLowerCase().contains(query) ||
            item.dua.toLowerCase().contains(query))
        .map((item) {
      final card = ZadItemCard(
        title: '${item.number}. ${item.name}',
        categoryName: 'اسم من أسماء الله الحسنى',
        subtitle: 'معنى ودعاء وأثر وجداني',
        content: item.meaning,
        reflectionOrBenefit: item.reflection,
        instructionOrDua: item.dua,
        source: 'القرآن الكريم وصحيح السنة المشرفة',
        categoryIcon: Icons.auto_awesome,
        accentColor: AppColors.goldDark,
        fontSize: _fontSize,
        isDark: isDark,
      );
      return ZadItemCard(
        title: card.title,
        categoryName: card.categoryName,
        subtitle: card.subtitle,
        content: card.content,
        reflectionOrBenefit: card.reflectionOrBenefit,
        instructionOrDua: card.instructionOrDua,
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
