import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/book_content.dart';

/// فهرس الكتاب: كل العناوين بتدرّجها، مع بحث، ويفتح عند موضع القراءة الحالي.
/// يعيد رقم الصفحة المختارة.
class BookTocSheet extends StatefulWidget {
  final BookIndex index;
  final int currentPage;
  final String bookTitle;

  const BookTocSheet({
    super.key,
    required this.index,
    required this.currentPage,
    required this.bookTitle,
  });

  static Future<int?> show(
    BuildContext context, {
    required BookIndex index,
    required int currentPage,
    required String bookTitle,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookTocSheet(index: index, currentPage: currentPage, bookTitle: bookTitle),
    );
  }

  @override
  State<BookTocSheet> createState() => _BookTocSheetState();
}

class _BookTocSheetState extends State<BookTocSheet> {
  final TextEditingController _search = TextEditingController();
  late final int _currentEntry = widget.index.tocIndexAt(widget.currentPage);
  late List<int> _visible = List.generate(widget.index.toc.length, (i) => i);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// يطابق بلا تشكيل وبتوحيد صور الألف والياء والتاء المربوطة.
  static String _fold(String s) => s
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  void _filter(String query) {
    final q = _fold(query.trim());
    final toc = widget.index.toc;
    setState(() {
      _visible = [
        for (var i = 0; i < toc.length; i++)
          if (q.isEmpty || _fold(toc[i].title).contains(q)) i,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final toc = widget.index.toc;
    final searching = _search.text.trim().isNotEmpty;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.86,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 10),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'فهرس ${widget.bookTitle}',
                        style: AppTypography.font(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${toc.length} عنواناً',
                      style: AppTypography.font(fontSize: 12, color: secondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: _filter,
                  style: TextStyle(fontSize: 13.5, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'ابحث في عناوين الكتاب...',
                    hintStyle: TextStyle(fontSize: 12.5, color: secondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: secondary),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _visible.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد عنوان مطابق',
                          style: AppTypography.font(fontSize: 13, color: secondary),
                        ),
                      )
                    : ScrollablePositionedList.builder(
                        // البحث يبدّل القائمة كلها؛ مفتاح جديد يعيدها إلى أولها
                        key: ValueKey(_search.text.trim()),
                        itemCount: _visible.length,
                        initialScrollIndex: searching || _currentEntry < 3 ? 0 : _currentEntry - 2,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemBuilder: (context, i) {
                          final entryIndex = _visible[i];
                          final entry = toc[entryIndex];
                          final isCurrent = entryIndex == _currentEntry;
                          final label = widget.index.printLabel(entry.page);
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.pop(context, entry.page),
                            child: Container(
                              padding: EdgeInsetsDirectional.only(
                                start: 10 + (entry.level - 1).clamp(0, 5) * 14.0,
                                end: 10,
                                top: 9,
                                bottom: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent ? primary.withValues(alpha: 0.12) : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.title,
                                      style: AppTypography.font(
                                        fontSize: entry.level == 1 ? 14 : 13,
                                        fontWeight: entry.level == 1 || isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        height: 1.5,
                                        color: isCurrent ? primary : textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    label.isEmpty ? 'صـ ${entry.page}' : label,
                                    style: AppTypography.font(fontSize: 11, color: secondary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
