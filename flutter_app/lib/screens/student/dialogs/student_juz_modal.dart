import 'package:flutter/material.dart';
import '../../../data/quran_data.dart';
import '../../../theme/app_theme.dart';

void showStudentJuzModal(
  BuildContext context,
  int juzNumber,
  JuzInfo juzInfo,
  Map<String, dynamic> prog,
  bool isDark,
) {
  final count = prog['memorizedAyahs'] as int;
  final total = prog['totalAyahs'] as int;
  final isComp = prog['isCompleted'] as bool;
  final statusAr = isComp
      ? 'تم إتقان وحفظ هذا الجزء كاملاً بنجاح ✅'
      : (count > 0 ? 'قيد التسميع والمتابعة ($count / $total آية) ⏳' : 'لم يبدأ بعد في هذا الجزء 📖');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.menu_book, color: AppTheme.emeraldPrimary),
          const SizedBox(width: 8),
          Expanded(child: Text('تفاصيل ${juzInfo.name}')),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(juzInfo.startDescription, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 10),
              Text('الحالة: $statusAr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: prog['progress'] as double,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComp ? AppTheme.emeraldPrimary : (count > 0 ? AppTheme.gold : Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('المحفوظ: $count آية من أصل $total آية كريمة'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ),
  );
}
