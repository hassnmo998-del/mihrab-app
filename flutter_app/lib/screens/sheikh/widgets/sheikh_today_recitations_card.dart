import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

class SheikhTodayRecitationsCard extends StatelessWidget {
  final List<MemorizationRecord> todayRecitations;
  final List<Student> students;

  const SheikhTodayRecitationsCard({
    super.key,
    required this.todayRecitations,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تسميعات اليوم (${todayRecitations.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  DateFormat('yyyy/MM/dd').format(DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 20),
            todayRecitations.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لم يتم تسجيل تسميع بعد في جلسة اليوم'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todayRecitations.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, idx) {
                      final item = todayRecitations[idx];
                      final st = students.firstWhere(
                        (s) => s.id == item.studentId,
                        orElse: () => Student(
                          id: '',
                          mosqueId: '',
                          halaqaId: '',
                          fullName: 'طالب',
                          gender: 'male',
                          phone: '',
                          code: '',
                        ),
                      );

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFD1FAE5),
                          child: Icon(Icons.menu_book, size: 16, color: AppTheme.emeraldPrimary),
                        ),
                        title: Text(
                          '${st.fullName} • ${item.surahName} (${item.fromAyah}-${item.toAyah})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'جزء ${item.juzNumber} • ${item.sessionType == "test" ? "اختبار معتمد" : (item.sessionType == "review" ? "مراجعة" : "حفظ جديد")}',
                        ),
                        trailing: item.pointsEarned > 0
                            ? Text(
                                '+${item.pointsEarned}ن',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emeraldPrimary,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
