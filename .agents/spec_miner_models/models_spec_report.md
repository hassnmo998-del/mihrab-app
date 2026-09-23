# Specification Report: Domain Entities & Models De-Monolithing

**Date**: 2026-09-12  
**Target File**: `flutter_app/lib/models/models.dart` (1,264 lines)  
**Status**: Completed  
**Author**: Spec Miner (Domain Entities & Models)  

---

## 1. Executive Summary

The domain layer of the Mosque & Quran Halaqat application currently defines all 17 core domain models inside a single monolithic file: `flutter_app/lib/models/models.dart` (1,264 lines).
All 17 entities are pure Dart classes handling domain data representations, JSON serialization/deserialization, schedule calculations, permission/targeting checks, and domain logic.
Across the codebase and automated test suite (`flutter_app/test/`), consumers import `package:flutter_app/models/models.dart` or `'../models/models.dart'`.
The de-monolithing strategy extracts each entity into its own dedicated file under `lib/models/` and turns `models.dart` into a backwards-compatible barrel export file. This guarantees 100% zero-breakage across all 38 existing tests and 30+ importing files.

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Mosque Entity | `Mosque` | Mosque entity representing Islamic centers, geolocation, access codes, and branch isolation | ID, name, city, address, phone, gender ('male'/'female'), accessCode, womenAccessCode, lat, lng | `Mosque` instance, JSON map | Defaults city to 'دمشق', gender to 'male', coordinates to (33.5138, 36.2765). Auto-generates access code if missing. | `lib/models/models.dart:1-64` |
| 2 | Sheikh Entity | `Sheikh` | Sheikh / teacher entity associated with a mosque | ID, mosqueId, fullName, phone, code | `Sheikh` instance, JSON map | Auto-generates fallback `SHK-XXXX` code if omitted. | `lib/models/models.dart:66-98` |
| 3 | Halaqa Entity | `Halaqa` | Study group / circle entity with schedule, prayer links, and co-sheikhs | ID, mosqueId, sheikhId, coSheikhIds, name, description, age ranges, schedule, daysOfWeek, timingType, prayerName, prayerRelation, customTime | `Halaqa` instance, JSON map, timing checks | Default age 6-18, days [6, 1, 3] (Sat, Mon, Wed), prayer_linked to Asr after prayer. | `lib/models/models.dart:100-226` |
| 4 | Student Entity | `Student` | Student domain entity strictly tied to a halaqa and mosque | ID, mosqueId, halaqaId, sheikhId, fullName, birthDate, gender, notes, totalPoints, code | `Student` instance, JSON map | Total points defaults to 50. Code auto-generates `STD-XXXX` if omitted. | `lib/models/models.dart:228-280` |
| 5 | Recitation Record | `MemorizationRecord` | Quran memorization & review logging entity | ID, studentId, halaqaId, sheikhId, courseId, surahName, fromAyah, toAyah, juzNumber, sessionType, qualityRating, pointsEarned, notes, countsTowardsStatistics, recordedAt | `MemorizationRecord` instance, JSON map | `countsTowardsStatistics` defaults to true. Ayahs default to 1. | `lib/models/models.dart:282-354` |
| 6 | Attendance Record | `AttendanceRecord` | Student session attendance log entity | ID, studentId, halaqaId, sessionDate ('YYYY-MM-DD'), status ('present', 'absent', 'late', 'excused'), pointsEarned, notes | `AttendanceRecord` instance, JSON map | Status defaults to 'present', pointsEarned to 0. | `lib/models/models.dart:356-396` |
| 7 | Communication | `AppMessage` | Administrative / pedagogical messaging entity | ID, studentId, halaqaId, senderType, senderName, content, messageType, isRead, createdAt | `AppMessage` instance, JSON map | `messageType` defaults to 'general', `isRead` to false. | `lib/models/models.dart:398-446` |
| 8 | Community Activities | `CommunityEvent` | Mosque public events, lectures, Mawlid, and tajweed circles | ID, mosqueId, title, description, eventType, customTypeName, timingType, prayerName, prayerRelation, targetAudience, coordinates, eventDateTime, durationMinutes, organizer, attendanceCount, hasTapped, distanceMeters | `CommunityEvent` instance, timing strings, category formatting | Fallback coordinates, duration defaults to 60m, attendance to 0. | `lib/models/models.dart:448-576` |
| 9 | Gamification & Points | `PointsLog` | Ledger entry for student reward points audit trail | ID, studentId, points, reason, category, createdAt, competitionId | `PointsLog` instance, JSON map | Category defaults to 'memorization'. | `lib/models/models.dart:578-618` |
| 10 | Competitions | `Competition` | Mosque competitions across Quran, Hadith, and attendance | ID, mosqueId, title, description, startDate, endDate, countQuran, countHadith, countAttendance, bonusPoints, genderBranch | `Competition` instance, isActive check | Fallbacks: count flags true, bonus points 0, male branch, endDate +30 days. | `lib/models/models.dart:620-681` |
| 11 | Authentication / Session | `ActiveSession` | Multi-role persistent session entity (Admin, Sheikh, Student, Cashier, Visitor) | role, code, name, mosqueId, mosqueName, gender, sheikhId, studentId, halaqaId | `ActiveSession` instance, roleLabel, accessCode | Role defaults to 'visitor', roleLabel resolves to Arabic role string. | `lib/models/models.dart:683-750` |
| 12 | Rewards & Shop | `Reward` | Redeemable prize item in the rewards catalog | ID, mosqueId, title, description, pointsCost, isActive, createdAt | `Reward` instance, JSON map | Points cost defaults to 100, isActive to true. | `lib/models/models.dart:752-790` |
| 13 | Rewards Dispensation | `RewardRedemption` | Vouchers & redemption status for cashier / student | ID, studentId, studentName, mosqueId, mosqueName, rewardId, rewardTitle, pointsSpent, redemptionCode, status, redeemedAt, dispensedAt, cashierName | `RewardRedemption` instance, status checks (isDispensed, isPending) | Status defaults to 'pending'. | `lib/models/models.dart:792-857` |
| 14 | Intensive Courses | `IntensiveCourse` | Intensive summer/periodic Quran memorization courses | ID, mosqueId, name, description, startDate, endDate, sheikhIds, halaqaIds, studentIds, daysOfWeek, startTime, endTime, countsTowardsQuranProgress, createdAt | `IntensiveCourse` instance, enrollment checks, schedule detection (±30 min) | Empty studentIds means all students in linked halaqat enrolled. | `lib/models/models.dart:859-1007` |
| 15 | Trips & Outings | `Trip` | Mosque trips and outdoor activities | ID, mosqueId, title, destination, tripDate, meetingTime, deadlineDate, description, requiredItems, targetHalaqaIds, targetStudentIds, costPoints, status, createdAt | `Trip` instance, student targeting check, leader parsing | Required items default provided. Parses leader name & phone from description. | `lib/models/models.dart:1012-1128` |
| 16 | Curricula & Tracks | `RecitationTrack` | Non-Quran curriculum tracks (Arbaeen Nawawiyyah, Jazariyyah, Fiqh, etc.) | ID, mosqueId, name, category, unitLabel, totalUnits, pointsPerUnit, isActive, isDefaultQuran, targetHalaqaIds, sheikhId, createdAt | `RecitationTrack` instance, JSON map | Default category 'custom', unitLabel 'حديث', units 40, points 2. | `lib/models/models.dart:1133-1194` |
| 17 | Track Recitation Log | `SubjectRecitationRecord` | Log of progress within custom curricula tracks | ID, studentId, halaqaId, sheikhId, trackId, trackName, fromUnit, toUnit, unitsCount, pointsEarned, courseId, notes, countsTowardsStatistics, recordedAt | `SubjectRecitationRecord` instance, JSON map | Units count defaults to 1, points to 0, statistics to true. | `lib/models/models.dart:1196-1262` |

---

## 3. Edge Cases & Resilience Behaviors

| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | `Mosque.fromJson` | Missing `access_code` and `accessCode` in JSON | Generates synthetic code: `'MSQ-' + cleanId.padRight(6, 'X').substring(0, 6)`. |
| 2 | `Mosque.fromJson` | Missing `city` | Falls back to `json['neighborhood']`, then to default Arabic string `'دمشق'`. |
| 3 | `Mosque.fromJson` | Missing `gender` | Falls back to `json['gender_branch']`, then to `'male'`. |
| 4 | `Mosque.effectiveWomenCode` | `womenAccessCode` is null | Automatically derives `'WM-${accessCode.replaceAll("MSQ-", "")}'`. |
| 5 | `Mosque.effectiveCashierCode` | Call getter | Always returns `'CSH-${accessCode.replaceAll("MSQ-", "")}'`. |
| 6 | `Sheikh.fromJson` | Missing `code` | Auto-generates random 4-digit code: `'SHK-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}'`. |
| 7 | `Halaqa.isScheduledAt` | Prayer-linked timing or custom time | Computes ±30 minute window (default `bufferMinutes: 30`) around start hour/minute. Checks weekday first. |
| 8 | `Student.fromJson` | Missing `code` | Auto-generates random 4-digit code: `'STD-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}'`. |
| 9 | `IntensiveCourse.isScheduledAt` | Course with start/end time and buffer | Validates date is within `[startDate, endDate]`, weekday is in `daysOfWeek`, and time is within `[startTime - buffer, endTime + buffer]`. |
| 10 | `IntensiveCourse.isStudentEnrolled` | `studentIds` list is empty | Returns `true` (if empty, course applies universally to all students in linked halaqat). |
| 11 | `Trip.isStudentTargeted` | `targetStudentIds` and `targetHalaqaIds` are both empty | Returns `true` (open to all students in mosque). |
| 12 | `Trip.leaderName` / `leaderPhone` | Description contains 'المشرف: ... - هاتف: ...' | Parses and extracts the supervisor name and phone number without crashing if missing. |
| 13 | `ActiveSession.fromJson` | Missing role | Defaults to `'visitor'`. Uses camelCase keys for session persistence in SharedPreferences. |
| 14 | `ActiveSession.name` | `name` is null | Defaults to `'مدير المسجد'` if role == `'mosque_admin'`, else `'مستخدم المنظومة'`. |
| 15 | `RecitationTrack.fromJson` | Supports both snake_case and camelCase for target halaqat | Checks `json['target_halaqa_ids']` then falls back to `json['targetHalaqaIds']`. |

---

## 4. Detailed Specification for All 17 Entities

### 1. `Mosque`
- **Class**: `Mosque`
- **Source Lines**: 1–64
- **Fields**:
  - `final String id`
  - `final String name`
  - `final String city`
  - `final String? address`
  - `final String? phone`
  - `final String gender` ('male' or 'female')
  - `final String accessCode`
  - `final String? womenAccessCode`
  - `final double latitude` (default: 33.5138)
  - `final double longitude` (default: 36.2765)
- **Constructors**:
  - Generative: `Mosque({required id, required name, required city, address, phone, required gender, required accessCode, womenAccessCode, latitude = 33.5138, longitude = 36.2765})`
  - Factory: `Mosque.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `name`, `city`, `address`, `phone`, `gender`, `access_code`, `women_access_code`, `latitude`, `longitude`.
- **Computed Properties / Getters**:
  - `neighborhood => city`
  - `genderBranch => gender`
  - `effectiveWomenCode => womenAccessCode ?? 'WM-${accessCode.replaceAll("MSQ-", "")}'`
  - `effectiveCashierCode => 'CSH-${accessCode.replaceAll("MSQ-", "")}'`
- **Internal Model Dependencies**: None.

### 2. `Sheikh`
- **Class**: `Sheikh`
- **Source Lines**: 66–98
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String fullName`
  - `String? phone`
  - `final String code`
- **Constructors**:
  - Generative: `Sheikh({required id, required mosqueId, required fullName, phone, required code})`
  - Factory: `Sheikh.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `full_name`, `phone`, `code`.
- **Internal Model Dependencies**: References `mosqueId` (String).

### 3. `Halaqa`
- **Class**: `Halaqa`
- **Source Lines**: 100–226
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String? sheikhId`
  - `List<String> coSheikhIds`
  - `String name`
  - `String? description`
  - `int ageGroupMin` (default: 6)
  - `int ageGroupMax` (default: 18)
  - `String schedule` (default: 'السبت - الإثنين - الأربعاء (عصراً)')
  - `List<int> daysOfWeek` (default: `[6, 1, 3]`)
  - `String timingType` (default: 'prayer_linked')
  - `String? prayerName` (default: 'asr')
  - `String prayerRelation` (default: 'after')
  - `String? customTime`
- **Constructors**:
  - Generative: `Halaqa(...)` with default values.
  - Factory: `Halaqa.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `sheikh_id`, `co_sheikh_ids`, `name`, `description`, `age_group_min`, `age_group_max`, `schedule`, `days_of_week`, `timing_type`, `prayer_name`, `prayer_relation`, `custom_time`.
- **Methods & Getters**:
  - `bool isSheikhAssigned(String sId)`
  - `bool isScheduledToday()`
  - `bool isScheduledAt(DateTime dt, {int bufferMinutes = 30})`
  - `static String dayName(int weekday)`
  - `String get formattedDays`
- **Internal Model Dependencies**: None (scalar IDs).

### 4. `Student`
- **Class**: `Student`
- **Source Lines**: 228–280
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String halaqaId`
  - `String? sheikhId`
  - `String fullName`
  - `final String? birthDate`
  - `final String gender`
  - `String? notes`
  - `int totalPoints` (default: 50)
  - `final String code`
- **Constructors**:
  - Generative: `Student(...)`
  - Factory: `Student.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `halaqa_id`, `sheikh_id`, `full_name`, `birth_date`, `gender`, `notes`, `total_points`, `code`.
- **Internal Model Dependencies**: None. (Referenced by `Trip`).

### 5. `MemorizationRecord`
- **Class**: `MemorizationRecord`
- **Source Lines**: 282–354
- **Fields**:
  - `final String id`
  - `final String studentId`
  - `final String? halaqaId`
  - `final String? sheikhId`
  - `final String? courseId`
  - `final String surahName`
  - `final int fromAyah`
  - `final int toAyah`
  - `final int juzNumber`
  - `final String sessionType` ('new_memorization', 'review', 'test')
  - `final String qualityRating` ('excellent', 'good', 'needs_improvement')
  - `final int pointsEarned`
  - `final String? notes`
  - `final bool countsTowardsStatistics` (default: true)
  - `final DateTime recordedAt`
- **Constructors**:
  - Generative: `MemorizationRecord(...)`
  - Factory: `MemorizationRecord.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `student_id`, `halaqa_id`, `sheikh_id`, `course_id`, `surah_name`, `from_ayah`, `to_ayah`, `juz_number`, `session_type`, `quality_rating`, `points_earned`, `notes`, `counts_towards_statistics`, `recorded_at`.
- **Internal Model Dependencies**: None.

### 6. `AttendanceRecord`
- **Class**: `AttendanceRecord`
- **Source Lines**: 356–396
- **Fields**:
  - `final String id`
  - `final String studentId`
  - `final String halaqaId`
  - `final String sessionDate` ('YYYY-MM-DD')
  - `final String status` ('present', 'absent', 'late', 'excused')
  - `final int pointsEarned` (default: 0)
  - `final String? notes`
- **Constructors**:
  - Generative: `AttendanceRecord(...)`
  - Factory: `AttendanceRecord.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `student_id`, `halaqa_id`, `session_date`, `status`, `points_earned`, `notes`.
- **Internal Model Dependencies**: None.

### 7. `AppMessage`
- **Class**: `AppMessage`
- **Source Lines**: 398–446
- **Fields**:
  - `final String id`
  - `final String studentId`
  - `final String halaqaId`
  - `final String senderType` ('sheikh', 'parent', 'mosque_admin')
  - `final String senderName`
  - `final String content`
  - `final String messageType` ('note', 'alert', 'praise', 'inquiry', 'general')
  - `final bool isRead` (default: false)
  - `final DateTime createdAt`
- **Constructors**:
  - Generative: `AppMessage(...)`
  - Factory: `AppMessage.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `student_id`, `halaqa_id`, `sender_type`, `sender_name`, `content`, `message_type`, `is_read`, `created_at`.
- **Internal Model Dependencies**: None.

### 8. `CommunityEvent`
- **Class**: `CommunityEvent`
- **Source Lines**: 448–576
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String title`
  - `String description`
  - `String eventType` ('lesson', 'mawlid', 'dhikr_circle', 'tajweed', 'custom', 'general')
  - `String? customTypeName`
  - `String timingType` ('prayer_linked', 'custom_time')
  - `String? prayerName`
  - `String? prayerRelation`
  - `String targetAudience` ('male', 'female', 'general')
  - `final double latitude` (default: 33.5138)
  - `final double longitude` (default: 36.2765)
  - `DateTime eventDateTime`
  - `int durationMinutes` (default: 60)
  - `final String organizerType`
  - `final String organizerName`
  - `int attendanceCount` (default: 0)
  - `bool hasTapped` (default: false)
  - `double? distanceMeters`
- **Constructors**:
  - Generative: `CommunityEvent(...)`
  - Factory: `CommunityEvent.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `title`, `description`, `event_type`, `custom_type_name`, `timing_type`, `prayer_name`, `prayer_relation`, `target_audience`, `latitude`, `longitude`, `event_datetime`, `duration_minutes`, `organizer_type`, `organizer_name`, `attendance_count`.
- **Methods & Getters**:
  - `String get displayCategory`
  - `String get timingDescription`
- **Internal Model Dependencies**: None.

### 9. `PointsLog`
- **Class**: `PointsLog`
- **Source Lines**: 578–618
- **Fields**:
  - `final String id`
  - `final String studentId`
  - `final int points`
  - `final String reason`
  - `final String category` ('memorization', 'hadith', 'attendance', 'dhikr', 'behavior', 'competition', 'manual')
  - `final DateTime createdAt`
  - `final String? competitionId`
- **Constructors**:
  - Generative: `PointsLog(...)`
  - Factory: `PointsLog.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `student_id`, `points`, `reason`, `category`, `created_at`, `competition_id`.
- **Internal Model Dependencies**: None.

### 10. `Competition`
- **Class**: `Competition`
- **Source Lines**: 620–681
- **Fields**:
  - `final String id`
  - `final String mosqueId` (default: '')
  - `String title`
  - `String description`
  - `DateTime startDate`
  - `DateTime endDate`
  - `bool countQuran` (default: true)
  - `bool countHadith` (default: true)
  - `bool countAttendance` (default: true)
  - `int bonusPoints` (default: 0)
  - `final String genderBranch` ('male' or 'female')
- **Constructors**:
  - Generative: `Competition(...)`
  - Factory: `Competition.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `title`, `description`, `start_date`, `end_date`, `count_quran`, `count_hadith`, `count_attendance`, `bonus_points`, `gender_branch`.
- **Getters**:
  - `bool get isActive`
- **Internal Model Dependencies**: None.

### 11. `ActiveSession`
- **Class**: `ActiveSession`
- **Source Lines**: 683–750
- **Fields**:
  - `final String role` ('visitor', 'mosque_admin', 'sheikh', 'student', 'cashier')
  - `final String code`
  - `final String? rawName`
  - `final String? mosqueId`
  - `final String? mosqueName`
  - `final String? gender`
  - `final String? sheikhId`
  - `final String? studentId`
  - `final String? halaqaId`
- **Constructors**:
  - Generative: `ActiveSession({required role, required code, String? name, mosqueId, mosqueName, gender, sheikhId, studentId, halaqaId}) : rawName = name;`
  - Factory: `ActiveSession.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Note: Uses camelCase keys (`role`, `code`, `name`, `mosqueId`, `mosqueName`, `gender`, `sheikhId`, `studentId`, `halaqaId`).
- **Getters**:
  - `String get name => rawName ?? ...`
  - `String get accessCode => code`
  - `String get genderBranch => gender ?? 'male'`
  - `String get roleLabel`
- **Internal Model Dependencies**: None.

### 12. `Reward`
- **Class**: `Reward`
- **Source Lines**: 752–790
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String title`
  - `String? description`
  - `int pointsCost`
  - `bool isActive` (default: true)
  - `final DateTime createdAt`
- **Constructors**:
  - Generative: `Reward(...)`
  - Factory: `Reward.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `title`, `description`, `points_cost`, `is_active`, `created_at`.
- **Internal Model Dependencies**: None.

### 13. `RewardRedemption`
- **Class**: `RewardRedemption`
- **Source Lines**: 792–857
- **Fields**:
  - `final String id`
  - `final String studentId`
  - `final String studentName`
  - `final String mosqueId`
  - `final String mosqueName`
  - `final String rewardId`
  - `final String rewardTitle`
  - `final int pointsSpent`
  - `final String redemptionCode`
  - `String status` ('pending', 'dispensed', 'cancelled')
  - `final DateTime redeemedAt`
  - `DateTime? dispensedAt`
  - `String? cashierName`
- **Constructors**:
  - Generative: `RewardRedemption(...)`
  - Factory: `RewardRedemption.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `student_id`, `student_name`, `mosque_id`, `mosque_name`, `reward_id`, `reward_title`, `points_spent`, `redemption_code`, `status`, `redeemed_at`, `dispensed_at`, `cashier_name`.
- **Getters**:
  - `bool get isDispensed`
  - `bool get isPending`
- **Internal Model Dependencies**: None.

### 14. `IntensiveCourse`
- **Class**: `IntensiveCourse`
- **Source Lines**: 859–1007
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String name`
  - `String? description`
  - `DateTime startDate`
  - `DateTime endDate`
  - `List<String> sheikhIds` (default: `[]`)
  - `List<String> halaqaIds` (default: `[]`)
  - `List<String> studentIds` (default: `[]`)
  - `List<int> daysOfWeek` (default: `[6, 1, 3]`)
  - `String? startTime`
  - `String? endTime`
  - `bool countsTowardsQuranProgress` (default: true)
  - `final DateTime createdAt`
- **Constructors**:
  - Generative: `IntensiveCourse(...)`
  - Factory: `IntensiveCourse.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `name`, `description`, `start_date`, `end_date`, `sheikh_ids`, `halaqa_ids`, `student_ids`, `days_of_week`, `start_time`, `end_time`, `counts_towards_quran_progress`, `created_at`.
- **Methods**:
  - `IntensiveCourse copyWith(...)`
  - `bool isStudentEnrolled(String stId)`
  - `bool isScheduledAt(DateTime dt, {int bufferMinutes = 30})`
- **Internal Model Dependencies**: None.

### 15. `Trip`
- **Class**: `Trip`
- **Source Lines**: 1012–1128
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String title`
  - `String destination`
  - `DateTime tripDate`
  - `String meetingTime`
  - `DateTime? deadlineDate`
  - `String? description`
  - `String requiredItems` (default: 'لباس مريح، مصحف جيب، مياه وطعام خفيف')
  - `List<String> targetHalaqaIds` (default: `[]`)
  - `List<String> targetStudentIds` (default: `[]`)
  - `int costPoints` (default: 0)
  - `String status` (default: 'upcoming')
  - `final DateTime createdAt`
- **Constructors**:
  - Generative: `Trip(...)`
  - Factory: `Trip.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `title`, `destination`, `trip_date`, `meeting_time`, `deadline_date`, `description`, `required_items`, `target_halaqa_ids`, `target_student_ids`, `cost_points`, `status`, `created_at`.
- **Getters & Methods**:
  - `bool get isUpcoming`
  - `String get requirements`
  - `DateTime get registrationDeadline`
  - `List<String> get studentIds`
  - `List<String> get halaqaIds`
  - `String? get leaderName`
  - `String? get leaderPhone`
  - `Trip copyWith(...)`
  - `bool isStudentTargeted(Student s)`
- **Internal Model Dependencies**: Depends on `Student` class. Requires `import 'student.dart';`.

### 16. `RecitationTrack`
- **Class**: `RecitationTrack`
- **Source Lines**: 1133–1194
- **Fields**:
  - `final String id`
  - `final String mosqueId`
  - `String name`
  - `String category` ('quran', 'hadith', 'matn', 'pages', 'custom', default: 'custom')
  - `String unitLabel` (default: 'حديث')
  - `int totalUnits` (default: 40)
  - `int pointsPerUnit` (default: 2)
  - `bool isActive` (default: true)
  - `bool isDefaultQuran` (default: false)
  - `List<String> targetHalaqaIds` (default: `[]`)
  - `String? sheikhId`
  - `final DateTime createdAt`
- **Constructors**:
  - Generative: `RecitationTrack(...)`
  - Factory: `RecitationTrack.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `mosque_id`, `name`, `category`, `unit_label`, `total_units`, `points_per_unit`, `is_active`, `is_default_quran`, `target_halaqa_ids`, `sheikh_id`, `created_at`.
- **Getters**:
  - `String get title => name`
- **Internal Model Dependencies**: None.

### 17. `SubjectRecitationRecord`
- **Class**: `SubjectRecitationRecord`
- **Source Lines**: 1196–1262
- **Fields**:
  - `final String id`
  - `final String studentId`
  - `final String? halaqaId`
  - `final String? sheikhId`
  - `final String trackId`
  - `final String trackName`
  - `final int fromUnit`
  - `final int toUnit`
  - `final int unitsCount`
  - `final int pointsEarned`
  - `final String? courseId`
  - `final String? notes`
  - `final bool countsTowardsStatistics` (default: true)
  - `final DateTime recordedAt`
- **Constructors**:
  - Generative: `SubjectRecitationRecord(...)`
  - Factory: `SubjectRecitationRecord.fromJson(Map<String, dynamic> json)`
- **Serialization**: `Map<String, dynamic> toJson()`
  Keys: `id`, `student_id`, `halaqa_id`, `sheikh_id`, `track_id`, `track_name`, `from_unit`, `to_unit`, `units_count`, `points_earned`, `course_id`, `notes`, `counts_towards_statistics`, `recorded_at`.
- **Internal Model Dependencies**: None.

---

## 5. Test Suite & Codebase Usage Analysis

1. **Automated Test Results**:
   - `flutter test` executes **38 tests**, all passing (0 failures).
   - Test files importing `package:flutter_app/models/models.dart`:
     - `test/clean_architecture_domain_data_test.dart` (lines 6, 95: instantiates `ActiveSession`)
     - `test/data_service_test.dart` (lines 4, 30+: uses `Mosque`, `Sheikh`, `Halaqa`, `Student`, `Reward`, `Trip`, etc.)
     - `test/courses_trips_tracks_test.dart` (uses data service which returns model instances)
     - `test/presentation_blocs_test.dart` (tests BLoCs emitting states containing model instances)
2. **Code Quality Analysis**:
   - `flutter analyze` passes with **0 errors and 0 warnings**.
3. **Consumer Files in `lib/`**:
   - Over 30 files in `domain/`, `data/`, `presentation/`, `screens/`, and `widgets/` import `models/models.dart`.
   - By retaining `lib/models/models.dart` as a barrel export file, none of these 30+ files need to change their import paths unless desired for fine-grained isolation.

---

## 6. De-Monolithing Plan & Zero-Breakage Architecture

### 6.1 Dedicated 17 File Mapping

Each entity will be placed in a single dedicated file under `lib/models/`:

| # | Entity Class | Target File Path | Line Range in Monolith | Imports Needed |
|---|--------------|------------------|------------------------|----------------|
| 1 | `Mosque` | `lib/models/mosque.dart` | 1–64 (64 lines) | Pure Dart |
| 2 | `Sheikh` | `lib/models/sheikh.dart` | 66–98 (33 lines) | Pure Dart |
| 3 | `Halaqa` | `lib/models/halaqa.dart` | 100–226 (127 lines) | Pure Dart |
| 4 | `Student` | `lib/models/student.dart` | 228–280 (53 lines) | Pure Dart |
| 5 | `MemorizationRecord` | `lib/models/memorization_record.dart` | 282–354 (73 lines) | Pure Dart |
| 6 | `AttendanceRecord` | `lib/models/attendance_record.dart` | 356–396 (41 lines) | Pure Dart |
| 7 | `AppMessage` | `lib/models/app_message.dart` | 398–446 (49 lines) | Pure Dart |
| 8 | `CommunityEvent` | `lib/models/community_event.dart` | 448–576 (129 lines) | Pure Dart |
| 9 | `PointsLog` | `lib/models/points_log.dart` | 578–618 (41 lines) | Pure Dart |
| 10 | `Competition` | `lib/models/competition.dart` | 620–681 (62 lines) | Pure Dart |
| 11 | `ActiveSession` | `lib/models/active_session.dart` | 683–750 (68 lines) | Pure Dart |
| 12 | `Reward` | `lib/models/reward.dart` | 752–790 (39 lines) | Pure Dart |
| 13 | `RewardRedemption` | `lib/models/reward_redemption.dart` | 792–857 (66 lines) | Pure Dart |
| 14 | `IntensiveCourse` | `lib/models/intensive_course.dart` | 859–1007 (149 lines) | Pure Dart |
| 15 | `Trip` | `lib/models/trip.dart` | 1012–1128 (117 lines) | `import 'student.dart';` |
| 16 | `RecitationTrack` | `lib/models/recitation_track.dart` | 1133–1194 (62 lines) | Pure Dart |
| 17 | `SubjectRecitationRecord` | `lib/models/subject_recitation_record.dart` | 1196–1262 (67 lines) | Pure Dart |

*Notice: Every single file is well under the 500 lines limit (the longest is `IntensiveCourse` at 149 lines).*

### 6.2 Backwards-Compatible Barrel Export (`lib/models/models.dart`)

```dart
// Backwards-compatible barrel export for all 17 domain entities
export 'mosque.dart';
export 'sheikh.dart';
export 'halaqa.dart';
export 'student.dart';
export 'memorization_record.dart';
export 'attendance_record.dart';
export 'app_message.dart';
export 'community_event.dart';
export 'points_log.dart';
export 'competition.dart';
export 'active_session.dart';
export 'reward.dart';
export 'reward_redemption.dart';
export 'intensive_course.dart';
export 'trip.dart';
export 'recitation_track.dart';
export 'subject_recitation_record.dart';
```

### 6.3 Inter-Entity Dependency Graph

```
Trip ───────────────> Student (via method `isStudentTargeted(Student s)`)
(All other 16 entities are completely decoupled and import nothing from other model files)
```

---

## 7. Verification Steps for Implementation

1. Extract all 17 entities to their corresponding file paths under `lib/models/`.
2. Add `import 'student.dart';` inside `lib/models/trip.dart`.
3. Overwrite `lib/models/models.dart` with the 17 export statements.
4. Execute `flutter analyze` in `flutter_app/`:
   - Expected: 0 issues found.
5. Execute `flutter test` in `flutter_app/`:
   - Expected: All 38 tests pass.
