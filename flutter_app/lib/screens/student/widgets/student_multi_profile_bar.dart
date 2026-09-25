import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../widgets/app_user_avatar.dart';

/// Ultra-compact, single-row multi-profile selector strip.
/// Eliminates all button duplications, fits perfectly on mobile screens,
/// and allows 1-tap switching and adding of child profiles.
class StudentMultiProfileBar extends StatelessWidget {
  final List<ActiveSession> studentSessions;
  final ActiveSession? activeSession;
  final List<Student> students;
  final List<Mosque> mosques;
  final List<Halaqa> halaqat;
  final bool isDark;
  final Function(String studentId) onSelectStudent;
  final VoidCallback onAddStudent;
  final Function(ActiveSession session) onUnlinkStudent;

  const StudentMultiProfileBar({
    super.key,
    required this.studentSessions,
    required this.activeSession,
    required this.students,
    required this.mosques,
    required this.halaqat,
    required this.isDark,
    required this.onSelectStudent,
    required this.onAddStudent,
    required this.onUnlinkStudent,
  });

  Student? _findStudent(ActiveSession session) {
    if (session.studentId != null) {
      final match = students.where((s) => s.id == session.studentId).firstOrNull;
      if (match != null) return match;
    }
    return students.where((s) => s.code == session.code).firstOrNull;
  }

  void _showUnlinkConfirmation(BuildContext context, ActiveSession session, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'إلغاء ربط ملف الطالب',
                style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد إلغاء ربط ملف الطالب ($studentName) من هذا الجهاز؟\n\nلن تُحذف بيانات الطالب أو رصيد نقاطه وسجل حفظه من المسجد، ويمكنك إعادة ربطه بأي وقت عبر مسح الكود مجدداً.',
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            height: 1.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('تراجع', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onUnlinkStudent(session);
            },
            child: Text('إلغاء الربط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = studentSessions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: count + 2, // 0 is header label, 1..count are children, count+1 is add button
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // Index 0: Header Section Pill
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                  border: Border.all(color: AppColors.terracottaPrimary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_alt_rounded, size: 15, color: AppColors.terracottaPrimary),
                    const SizedBox(width: 5),
                    Text(
                      'أبنائي في الحلقات ($count)',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.terracottaPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Last Item: Single Dedicated Add Child Button
            if (index == count + 1) {
              return InkWell(
                onTap: onAddStudent,
                borderRadius: BorderRadius.circular(AppRadius.rPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.rPill),
                    border: Border.all(
                      color: AppColors.terracottaPrimary,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 15, color: AppColors.terracottaPrimary),
                      const SizedBox(width: 5),
                      Text(
                        'إضافة ابن',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terracottaPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Child Profile Pill
            final session = studentSessions[index - 1];
            final student = _findStudent(session);
            final studentId = session.studentId ?? session.code;
            final isActive = (activeSession?.studentId != null &&
                    session.studentId == activeSession!.studentId) ||
                session.code == activeSession?.code;

            final studentName = student?.fullName ?? session.name;
            final totalPoints = student?.totalPoints ?? 0;

            final borderColor = isActive
                ? AppColors.terracottaPrimary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

            final bgColor = isActive
                ? (isDark
                    ? AppColors.terracottaPrimary.withValues(alpha: 0.22)
                    : AppColors.terracottaPrimary.withValues(alpha: 0.1))
                : (isDark ? AppColors.darkInputFill : AppColors.lightInputFill);

            return InkWell(
              onTap: () {
                if (!isActive) {
                  onSelectStudent(studentId);
                }
              },
              onLongPress: () {
                _showUnlinkConfirmation(context, session, studentName);
              },
              borderRadius: BorderRadius.circular(AppRadius.rPill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                  border: Border.all(
                    color: borderColor,
                    width: isActive ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mini Avatar
                    AppUserAvatar(
                      radius: 12,
                      name: studentName,
                      imageUrl: student?.profileImageUrl,
                      role: 'student',
                    ),
                    const SizedBox(width: 6),

                    // Name
                    Text(
                      studentName,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.obsidianEspresso,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Points Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.goldBright.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.rPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, size: 11, color: AppColors.goldBright),
                          const SizedBox(width: 2),
                          Text(
                            '$totalPoints',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.goldBright : const Color(0xFF996500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isActive) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E7E34).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.rPill),
                        ),
                        child: Text(
                          'المعروض',
                          style: GoogleFonts.cairo(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E7E34),
                          ),
                        ),
                      ),
                    ],

                    // Unlink option button
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () => _showUnlinkConfirmation(context, session, studentName),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
