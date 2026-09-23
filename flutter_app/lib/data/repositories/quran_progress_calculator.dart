import '../../models/models.dart';
import '../quran_data.dart';

/// Pure computation helper for authentic Quran memorization calculations,
/// 6,236 Ayahs deduplication, and 30 Ajza completion metrics.
class QuranProgressCalculator {
  /// Deduplicates memorized Ayahs for a student across all records,
  /// skipping records not counted towards statistics or courses flagged
  /// as not counting towards Quran progress.
  static Set<String> computeMemorizedAyahKeys({
    required List<MemorizationRecord> records,
    required List<IntensiveCourse> intensiveCourses,
  }) {
    final keys = <String>{};

    for (final rec in records) {
      if (!rec.countsTowardsStatistics) {
        continue;
      }
      if (rec.courseId != null && rec.courseId!.isNotEmpty) {
        final course = intensiveCourses.firstWhere(
          (c) => c.id == rec.courseId,
          orElse: () => IntensiveCourse(
            id: '',
            mosqueId: '',
            name: '',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            countsTowardsQuranProgress: true,
            createdAt: DateTime.now(),
          ),
        );
        if (course.id.isNotEmpty && !course.countsTowardsQuranProgress) {
          continue;
        }
      }

      final surahNum = getSurahNumberByName(rec.surahName);
      final from = rec.fromAyah;
      final to = rec.toAyah;
      for (int a = from; a <= to; a++) {
        keys.add('$surahNum:$a');
      }
    }
    return keys;
  }

  /// Calculates completion status and progress ratio for a specific Juz (1..30).
  static Map<String, dynamic> computeJuzProgress({
    required Set<String> memorizedKeys,
    required int juzNumber,
  }) {
    final allKeysInJuz = getAllAyahKeysInJuz(juzNumber);
    final memorizedInJuz = memorizedKeys.intersection(allKeysInJuz);
    final total = allKeysInJuz.length;
    final count = memorizedInJuz.length;
    final progress = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final isCompleted = count >= total && total > 0;

    return {
      'juzNumber': juzNumber,
      'memorizedAyahs': count,
      'totalAyahs': total,
      'progress': progress,
      'isCompleted': isCompleted,
    };
  }

  /// Calculates aggregate Quran memorization progress across all 6,236 Ayahs and 30 Ajza.
  static Map<String, dynamic> computeOverallProgress(Set<String> memorizedKeys) {
    final count = memorizedKeys.length;
    final progress =
        totalQuranAyahs > 0 ? (count / totalQuranAyahs).clamp(0.0, 1.0) : 0.0;

    int completedAjza = 0;
    for (int j = 1; j <= 30; j++) {
      final juzProg = computeJuzProgress(
        memorizedKeys: memorizedKeys,
        juzNumber: j,
      );
      if (juzProg['isCompleted'] == true) {
        completedAjza++;
      }
    }

    return {
      'memorizedAyahs': count,
      'totalAyahs': totalQuranAyahs,
      'progress': progress,
      'completedAjza': completedAjza,
      'totalAjza': 30,
    };
  }

  /// Computes detailed status breakdown for each of the 30 Ajza.
  static Map<int, Map<String, dynamic>> compute30AjzaStatus(
      Set<String> memorizedKeys) {
    final map = <int, Map<String, dynamic>>{};
    for (int juz = 1; juz <= 30; juz++) {
      final juzProg = computeJuzProgress(
        memorizedKeys: memorizedKeys,
        juzNumber: juz,
      );
      final isCompleted = juzProg['isCompleted'] as bool;
      final count = juzProg['memorizedAyahs'] as int;
      final inProgress = !isCompleted && count > 0;

      map[juz] = {
        'status': isCompleted
            ? 'completed'
            : (inProgress ? 'in_progress' : 'not_started'),
        'memorizedAyahs': count,
        'totalAyahs': juzProg['totalAyahs'],
        'progress': juzProg['progress'],
        'isCompleted': isCompleted,
      };
    }
    return map;
  }
}
