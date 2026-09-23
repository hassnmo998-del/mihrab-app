import 'package:flutter/material.dart';
import '../../../data/quran_data.dart';
import '../../../theme/app_theme.dart';

void showMultiSurahSelectorDialog(
  BuildContext context,
  Set<String> selectedSurahs,
  VoidCallback onSelectionChanged,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = quranSurahsInfo
              .where((s) => s.name.contains(query) || s.number.toString().contains(query))
              .toList();
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.library_books, color: AppTheme.emeraldPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'اختيار سور التسميع (تعدد)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      160)
                  .clamp(220.0, 420.0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن اسم السورة أو رقمها...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setDialogState(() => query = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final isSelected = selectedSurahs.contains(s.name);
                        return CheckboxListTile(
                          dense: true,
                          value: isSelected,
                          title: Text('${s.number}. سورة ${s.name} (${s.ayahCount} آية)'),
                          subtitle: Text('بداية الجزء ${s.startJuz}'),
                          activeColor: AppTheme.emeraldPrimary,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedSurahs.add(s.name);
                              } else {
                                selectedSurahs.remove(s.name);
                              }
                            });
                            onSelectionChanged();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('تم (${selectedSurahs.length} سور مختارة)'),
              ),
            ],
          );
        },
      );
    },
  );
}
