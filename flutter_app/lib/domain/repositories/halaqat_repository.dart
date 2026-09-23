import '../../models/models.dart';

/// Contract for Halaqat management.
abstract class HalaqatRepository {
  List<Halaqa> getHalaqat({String? mosqueId, String? sheikhId});
  Halaqa? getHalaqaById(String id);
  Halaqa addHalaqa({
    required String mosqueId,
    String? sheikhId,
    List<String> coSheikhIds = const [],
    required String name,
    String? description,
    int ageGroupMin = 6,
    int ageGroupMax = 18,
    String schedule = 'السبت - الإثنين - الأربعاء (عصراً)',
    List<int> daysOfWeek = const [6, 1, 3],
    String timingType = 'prayer_linked',
    String? prayerName = 'asr',
    String prayerRelation = 'after',
    String? customTime,
  });
  void updateHalaqa({
    required String id,
    required String name,
    String? description,
    String? sheikhId,
    List<String>? coSheikhIds,
    int? ageGroupMin,
    int? ageGroupMax,
    String? schedule,
    List<int>? daysOfWeek,
    String? timingType,
    String? prayerName,
    String? prayerRelation,
    String? customTime,
  });
  void deleteHalaqa(String halaqaId);
}
