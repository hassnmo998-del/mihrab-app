# Architectural Analysis & Clean Architecture Decomposition Report
## Data & Service Layer (`DataService` Monolith)

**Date**: 2026-09-12  
**Target File**: `flutter_app/lib/services/data_service.dart` (2,280 lines)  
**Workspace**: `c:\Users\moham\Desktop\masjed app\flutter_app`  
**Author**: Explorer (Data & Service Layer)

---

## 1. Executive Summary

The `DataService` class in `flutter_app/lib/services/data_service.dart` is currently a monolithic **2,280-line** God class that combines:
1. **In-Memory State Holding**: 17 dynamic list collections representing the app's entire domain state.
2. **Local Persistence**: Direct synchronous read/write serialization to `SharedPreferences` for all 17 collections plus theme and session state.
3. **Remote Cloud API Access**: Direct Supabase queries and mutators across 16 database tables.
4. **Offline Resilience**: A persistent FIFO background synchronization queue (`_pendingSyncQueue`).
5. **Business & Domain Logic**: Complex calculations including authentic Quran progress deduplication across 6,236 Ayahs, smart recitation timing detection (±30 minute window), custom recitation track unit progress, student commitment percentages, competition score recalibration, rewards bank voucher creation, and cashier dispensation.
6. **Reactive State Dispatcher**: Extends `ChangeNotifier` to notify listeners throughout the presentation layer.

This report provides a granular audit of every responsibility in `data_service.dart`, reviews the existing test suite (38 passing tests), and proposes a modular, production-grade Clean Architecture decomposition into dedicated data sources, offline sync management, granular repository contracts, and a backwards-compatible facade adapter ensuring **100% zero-regression compliance**.

---

## 2. Granular Analysis of `data_service.dart`

### 2.1 Class Structure & Lifecycle
- **Class**: `class DataService extends ChangeNotifier`
- **Pattern**: Singleton with private constructor `DataService._internal()` and factory `factory DataService() => _instance;`.
- **Initialization (`init()`)**:
  1. Calls `Supabase.initialize()` wrapped in a silent try/catch block.
  2. Executes `_loadFromLocalStorage()` to populate all 17 in-memory lists from `SharedPreferences` (providing 0ms cold-start latency).
  3. Executes `_loadSyncQueue()` to retrieve queued offline mutations.
  4. Triggers `_processSyncQueue()` asynchronously in the background.
  5. Calls `syncWithSupabase()` to fetch remote data from Supabase and merge it into local cache.
  6. Dispatches `notifyListeners()`.

### 2.2 Supabase Tables and Operations Catalog

`DataService` interacts with **16 distinct Supabase tables**:

| # | Table Name | Operations Invoked | Queue vs Direct | Notes |
|---|------------|--------------------|-----------------|-------|
| 1 | `mosques` | `select`, `upsert`, `delete` | Queue (`_queueSync`) & `syncWithSupabase` | Mosques CRUD |
| 2 | `sheikhs` | `select`, `upsert`, `delete` | Queue (`_queueSync`) & `syncWithSupabase` | Linked to `mosqueId` |
| 3 | `halaqat` | `select`, `upsert`, `delete` | Upsert in Queue; Delete direct async | Halaqa schedules, timings |
| 4 | `students` | `select`, `upsert`, `delete` | Queue (`_queueSync`) & `syncWithSupabase` | Tracks `totalPoints` |
| 5 | `community_events` | `select`, `upsert`, `delete`, `update` | Upsert/delete in Queue; `attendance_count` update direct | Event tap counter |
| 6 | `memorization_records` | `select`, `upsert` | Queue (`_queueSync`) & `syncWithSupabase` | Quran recitation entries |
| 7 | `attendance` | `select`, `upsert` | Queue (`_queueSync`) & `syncWithSupabase` | Daily student attendance |
| 8 | `messages` | `select`, `upsert` | Queue (`_queueSync`) & `syncWithSupabase` | App messages / inquiries |
| 9 | `rewards` | `upsert`, `delete` | Queue (`_queueSync`) | Rewards catalog |
| 10 | `reward_redemptions` | `upsert` | Queue (`_queueSync`) | Vouchers (`VCH-XXXX`) |
| 11 | `competitions` | `insert`, `update`, `delete` | Direct async calls via `supabase?.from` | Contests and leaderboards |
| 12 | `points_logs` | `upsert` | Queue (`_queueSync`) | Points audit ledger |
| 13 | `intensive_courses` | `upsert`, `delete` | Queue (`_queueSync`) | Specialized programs |
| 14 | `trips` | `upsert`, `delete` | Queue (`_queueSync`) | Mosque trips and outings |
| 15 | `recitation_tracks` | `upsert`, `delete` | Queue (`_queueSync`) | Custom curricula (Hadith, Mutun) |
| 16 | `subject_recitation_records` | `upsert` | Queue (`_queueSync`) | Unit-based recitation progress |

### 2.3 Local Storage & Caching Layer
All local persistence currently operates through `SharedPreferences` keys:
- `'is_dark_mode'`: Theme mode boolean.
- `'saved_sessions'`: JSON list of all authenticated active sessions across roles.
- `'current_session_code'`: Access code of the currently selected active session.
- `'unlocked_women_mosques'`: String list of mosque IDs where the women's section is unlocked on this device.
- `'pending_sync_queue'`: Serialized JSON array of queued offline mutations.
- **Entity Collections (JSON-encoded lists)**:
  - `'real_mosques'`
  - `'real_sheikhs'`
  - `'real_halaqat'`
  - `'real_students'`
  - `'real_events'`
  - `'real_points_logs'`
  - `'real_competitions'`
  - `'real_memorization_records'`
  - `'real_attendance_records'`
  - `'real_messages'`
  - `'real_rewards'`
  - `'real_redemptions'`
  - `'real_intensive_courses'`
  - `'real_trips'`
  - `'real_recitation_tracks'`
  - `'real_subject_recitation_records'`

### 2.4 Offline Background Sync Queue Mechanism
The sync queue allows the app to operate offline seamlessly:
1. When data is modified (`add`, `update`, `delete`), local state is updated immediately, written to `SharedPreferences`, and an entry is pushed to `_pendingSyncQueue`:
   ```dart
   {
     'table': table,
     'action': action, // 'upsert' or 'delete'
     'data': data,
     'id': id,
     'queued_at': DateTime.now().toIso8601String(),
   }
   ```
2. `_saveSyncQueue()` persists the updated queue to `SharedPreferences`.
3. `_processSyncQueue()` runs non-blocking:
   - Iterates through queue items.
   - Calls `client.from(table).upsert(data)` or `client.from(table).delete().eq('id', id)`.
   - **Fault-tolerance rule**: If an operation throws a network or socket exception, the loop breaks (`break`), preserving the remaining queue items in storage for retry upon the next connectivity event.
   - Successfully dispatched operations are removed from `_pendingSyncQueue` and the queue is re-saved.

---

## 3. Embedded Business Logic Catalog

`DataService` currently houses extensive domain business rules that must be carefully preserved during modularization:

### 3.1 Multi-Role Persistent Sessions & Codeless Access
- **Simultaneous Multi-Role Coexistence**:
  - Roles: `visitor`, `student`, `sheikh`, `mosque_admin`, `cashier`.
  - Sessions are saved in `_savedSessions`. Switching sessions (`switchSession`) does NOT log out other roles.
  - `disconnectRole(role)` only removes the specified role; other active roles remain alive.
  - Auto-manager session: If `mosque_admin` role is requested and `_mosques` is non-empty, `DataService` auto-synthesizes an admin session for the primary mosque.
- **Codeless Access Hierarchy (`verifyCode`)**:
  - Codes are capitalized and trimmed:
    1. Checks if code matches `Mosque.accessCode` (`MSQ-XXXX`) -> logs in as `mosque_admin`.
    2. Checks if code matches `Sheikh.code` (`SHK-XXXX`) -> logs in as `sheikh`.
    3. Checks if code matches `Student.code` (`STD-XXXX`) -> logs in as `student`.
    4. Checks prefix `CSH-` or `CASHIER` -> logs in as `cashier`.

### 3.2 Women Section Privacy & Validation
- **Access Rule**:
  - Accessible if current session `genderBranch == 'female'`.
  - Accessible for a specific mosque if its ID is in `_unlockedWomenMosqueIds`.
  - `unlockWomenSectionWithCode(code)`:
    - Matches mosque's `effectiveWomenCode` or `accessCode` -> unlocks that specific mosque.
    - Matches `WM-` prefix or `'WOMEN'` -> unlocks all mosques and adds `'general_women'`.

### 3.3 Smart Recitation Timing Detection (±30 Min Window)
- **Algorithm (`detectSessionTimingMode`)**:
  1. Checks if current time is within **±30 minutes** of any active `IntensiveCourse` linked to the student/halaqa:
     - Calls `course.isScheduledAt(now, bufferMinutes: 30)`.
     - Returns mode `'course'`, the course object, label, and `countsTowardsQuran: course.countsTowardsQuranProgress`.
  2. If not in a course, checks if current time is within **±30 minutes** of the regular halaqa schedule:
     - Calls `halaqa.isScheduledAt(now, bufferMinutes: 30)`.
     - Returns mode `'normal'`, `countsTowardsQuran: true`.
  3. If outside both scheduled windows:
     - Returns mode `'custom'`, label `'تسميع بوقت مخصص (خارج الجلسات المعتادة)'`.

### 3.4 Authentic Quran Progress Deduplication (30 Ajza / 6,236 Ayahs)
- **Preventing Artificial Inflation**:
  - `getStudentMemorizedAyahKeys(studentId)`:
    - Scans all `MemorizationRecord`s for the student.
    - Filters: skips records where `countsTowardsStatistics == false`.
    - Skips records belonging to an intensive course that has `countsTowardsQuranProgress == false`.
    - Maps `surahName` to surah number using `getSurahNumberByName`.
    - Iterates from `fromAyah` to `toAyah`, generating keys in format `'$surahNum:$a'`.
    - Stores keys in a `Set<String>`, strictly deduplicating repeat recitations or reviews!
  - `getStudentJuzProgress(studentId, juzNumber)`:
    - Intersects `Set<String>` with `getAllAyahKeysInJuz(juzNumber)` from `quran_data.dart`.
    - Calculates `progress = (memorizedInJuz.length / totalAyahsInJuz)`.
    - Marks `isCompleted = count >= total && total > 0`.
  - `getStudentOverallQuranProgress(studentId)`:
    - Calculates overall memorized count against `totalQuranAyahs` (6,236).
    - Iterates over all 30 Ajza to calculate `completedAjza` (0 to 30).
  - `getStudent30AjzaStatus(studentId)`:
    - Categorizes each juz as `'completed'`, `'in_progress'`, or `'not_started'`.

### 3.5 Custom Recitation Tracks & Curriculums
- Flexible tracks for Hadith (e.g. Arbaeen), Mutun (e.g. Jazariyyah), Fiqh, and books.
- `recordSubjectRecitation`: Records unit range (`fromUnit` to `toUnit`), awards points, logs `PointsLog`.
- `getStudentSubjectProgress`: Calculates unique covered units using `Set<int> uniqueUnits` over all records where `countsTowardsStatistics == true` to prevent double-counting.

### 3.6 Mosque Trips & Outings
- CRUD operations for trips.
- Target filtering: checks halaqa eligibility (`targetHalaqaIds`) and individual student targeting (`isStudentTargeted`).
- Prominent baggage items field (`requiredItems`, e.g., "ما يلزم إحضاره مع الطالب 🎒").

### 3.7 Student Attendance & Commitment History
- `recordAttendance`: records status (`present`, `absent`, `late`, `excused`), replaces existing record on the same date to prevent duplicates, awards points, logs `PointsLog`, updates student `totalPoints`.
- `getStudentAttendanceSummary`: calculates status counts and commitment percentage:
  $$\text{Commitment Rate} = \frac{\text{present} + 0.5 \times \text{late}}{\text{total}} \times 100$$

### 3.8 Competitions & Honor Leaderboard
- Dual dropdown filtering: Mosque + Halaqa.
- Intensive course ranking mode: when filtering by `courseId`, student points are dynamically recalculated to sum only Quran points (`_memorizationRecords.where(m.courseId == courseId)`) and subject points (`_subjectRecitationRecords.where(s.courseId == courseId)`) earned inside that specific course.
- Assigns ordinal ranks (1..N) sorted descending by points.

### 3.9 Rewards Bank & Cashier Dispensation
- `claimReward`: verifies student has sufficient `totalPoints >= pointsCost`, generates unique voucher code (`VCH-XXXX`), creates redemption with status `'pending'`.
- `dispenseReward`:
  - Cashier scans or enters voucher code.
  - Verifies voucher exists and status is not already `'dispensed'`.
  - Verifies student `totalPoints >= pointsSpent`.
  - Deducts points from student `totalPoints`.
  - Creates negative `PointsLog` entry (`points: -red.pointsSpent`).
  - Sets redemption status to `'dispensed'`, stamps `dispensedAt = DateTime.now()` and `cashierName`.

### 3.10 Executive Oversight Matrix (`getExecutiveOverview`)
- Aggregates high-level supervisor matrix across students: student info, halaqa, sheikh, daily attendance record, last Quran recitation, last Hadith record, completed Ajza count, and total points.

---

## 4. Test Suite Audit & Contract Guarantees

### 4.1 Test Files Analysis
Running `flutter test` completes with **38 passed tests (100% success rate)** across 6 test suites:

| Test File | Lines | Scope & Methodologies |
|---|---|---|
| `test/data_service_test.dart` | 392 | Direct tests on `DataService` instance; uses `SharedPreferences.setMockInitialValues({})`; tests multi-role sessions, sheikh/student point separation, halaqa co-supervision, community events custom types, executive matrix, women section QR unlock, authentic Quran deduplication (Al-Fatihah repeat), rewards claim/cashier dispensation, `countsTowardsStatistics` toggle, course rankings, track halaqa filtering. |
| `test/clean_architecture_domain_data_test.dart` | 309 | Uses `get_it` injection container (`initInjection()`, `resetInjection()`); validates registration of `DataService`, `MosqueRepository`, 17 use cases, and 3 BLoCs; exercises sessions, recitation, attendance, trips, courses, and rewards use cases via `MosqueRepositoryImpl`. |
| `test/courses_trips_tracks_test.dart` | 175 | Tests smart timing detection with ±30m window (course vs halaqa vs custom), trip filtering & required baggage items (`🎒`), and Arbaeen 42 hadiths track with overlapping range deduplication. |
| `test/presentation_blocs_test.dart` | 269 | Tests `SessionBloc`, `RecitationBloc`, `TripsBloc`, `CoursesBloc`, `AttendanceBloc`, `ThemeCubit`. Crucially: all BLoCs take `dataService: dataService` in their constructors. |
| `test/unified_widgets_test.dart` | 185 | Tests unified theme components: `UnifiedCard`, `UnifiedBadge`, `UnifiedButton`, `UnifiedStatusChip`. |
| `test/widget_test.dart` | 20 | App smoke test initializing app widget tree. |

### 4.2 Key Contract Guarantees to Preserve
1. **Synchronous In-Memory Queries**: UI widgets and BLoCs expect instantaneous synchronous reads (e.g., `dataService.getMosques()`, `dataService.getStudents()`, `dataService.getTrips()`). Any repository architecture must maintain an in-memory cache to guarantee 0ms latency.
2. **`ChangeNotifier` Reactivity**: Many UI widgets listen directly to `DataService` via `AnimatedBuilder`, `ListenableBuilder`, or `Provider.of<DataService>`. Mutations must continue triggering `notifyListeners()`.
3. **`SharedPreferences` Mock Compatibility**: In unit tests, `SharedPreferences.setMockInitialValues({})` is invoked before each test. Data sources must continue using `SharedPreferences` without requiring real native plugins.
4. **Signature Stability**: All method names, parameter types, optional named arguments, and return types on `DataService` must remain 100% backwards-compatible.

---

## 5. Proposed Modular Clean Architecture Decomposition

To break down the 2,280-line monolith while guaranteeing zero breakage, we propose a modular Clean Architecture decomposition:

```
lib/
├── domain/
│   └── repositories/
│       ├── auth_session_repository.dart
│       ├── mosques_repository.dart
│       ├── sheikhs_repository.dart
│       ├── halaqat_repository.dart
│       ├── students_repository.dart
│       ├── attendance_repository.dart
│       ├── recitation_repository.dart
│       ├── recitation_tracks_repository.dart
│       ├── courses_repository.dart
│       ├── trips_repository.dart
│       ├── rewards_repository.dart
│       ├── competitions_repository.dart
│       ├── community_events_repository.dart
│       ├── messages_repository.dart
│       ├── executive_overview_repository.dart
│       └── mosque_repository.dart (Aggregated / umbrella contract)
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── local_storage_datasource.dart
│   │   │   └── offline_sync_queue_manager.dart
│   │   └── remote/
│   │       ├── supabase_remote_datasource.dart
│   │       └── supabase_sync_client.dart
│   └── repositories/
│       ├── auth_session_repository_impl.dart
│       ├── mosques_repository_impl.dart
│       ├── sheikhs_repository_impl.dart
│       ├── halaqat_repository_impl.dart
│       ├── students_repository_impl.dart
│       ├── attendance_repository_impl.dart
│       ├── recitation_repository_impl.dart
│       ├── recitation_tracks_repository_impl.dart
│       ├── courses_repository_impl.dart
│       ├── trips_repository_impl.dart
│       ├── rewards_repository_impl.dart
│       ├── competitions_repository_impl.dart
│       ├── community_events_repository_impl.dart
│       ├── messages_repository_impl.dart
│       ├── executive_overview_repository_impl.dart
│       └── mosque_repository_impl.dart (Delegating coordinator)
└── services/
    └── data_service.dart (Backwards-compatible Facade / ChangeNotifier)
```

### 5.1 Abstract Repository Contracts (Domain Layer)

Each subdomain receives a dedicated, focused repository contract:

1. **`AuthSessionRepository`**:
   ```dart
   abstract class AuthSessionRepository {
     ActiveSession? get currentSession;
     List<ActiveSession> get savedSessions;
     void switchSession(ActiveSession session);
     void setRoleSession(ActiveSession session);
     ActiveSession? getSessionForRole(String role);
     bool hasRole(String role);
     void disconnectRole(String role);
     void clearSession();
     Future<ActiveSession?> verifyCode(String code);
     bool isWomenSectionUnlocked([String? mosqueId]);
     bool unlockWomenSectionWithCode(String code);
   }
   ```
2. **`MosquesRepository`**:
   ```dart
   abstract class MosquesRepository {
     List<Mosque> getMosques({String? gender});
     Mosque? getMosqueById(String id);
     Mosque addMosque({required String name, required String address, required String city, required String gender, String? phone});
     void updateMosque({required String id, required String name, required String address, required String city, String? phone});
     void deleteMosque(String mosqueId);
   }
   ```
3. **`SheikhsRepository`**:
   ```dart
   abstract class SheikhsRepository {
     List<Sheikh> getSheikhs({String? mosqueId, String? gender});
     Sheikh addSheikh(String mosqueId, String fullName, String? phone);
     void updateSheikh({required String sheikhId, required String fullName, String? phone});
     void deleteSheikh(String sheikhId);
   }
   ```
4. **`HalaqatRepository`**:
   ```dart
   abstract class HalaqatRepository {
     List<Halaqa> getHalaqat({String? mosqueId, String? sheikhId});
     Halaqa? getHalaqaById(String id);
     Halaqa addHalaqa({required String mosqueId, String? sheikhId, List<String> coSheikhIds, required String name, ...});
     void updateHalaqa({required String id, required String name, ...});
     void deleteHalaqa(String halaqaId);
   }
   ```
5. **`StudentsRepository`**:
   ```dart
   abstract class StudentsRepository {
     List<Student> getStudents({String? halaqaId, String? sheikhId, String? mosqueId, String? gender});
     Student addStudent({required String mosqueId, required String halaqaId, String? sheikhId, required String fullName, required String gender, String? notes, String? birthDate, int welcomePoints});
     void updateStudent({required String studentId, required String fullName, required String halaqaId, String? notes});
     void deleteStudent(String studentId);
     List<PointsLog> getStudentPointsLog(String studentId);
   }
   ```
6. **`AttendanceRepository`**:
   ```dart
   abstract class AttendanceRepository {
     List<AttendanceRecord> getAttendanceForDate(String halaqaId, String sessionDate);
     void recordAttendance({required String studentId, required String halaqaId, required String sessionDate, required String status, int pointsEarned, String? notes});
     Map<String, dynamic> getStudentAttendanceSummary(String studentId);
   }
   ```
7. **`RecitationRepository`**:
   ```dart
   abstract class RecitationRepository {
     List<MemorizationRecord> getStudentMemorizations(String studentId);
     List<MemorizationRecord> getTodayMemorizations({String? halaqaId, String? sheikhId});
     void recordRecitationBatch({required String studentId, String? halaqaId, String? sheikhId, String? courseId, required List<Map<String, dynamic>> items, required String sessionType, required int points, String? notes, bool countsTowardsStatistics});
     void recordMemorization({required String studentId, ...});
     void recordHadith({required String studentId, String? halaqaId, required String hadithTitle, required int points});
     Set<String> getStudentMemorizedAyahKeys(String studentId);
     Map<String, dynamic> getStudentJuzProgress(String studentId, int juzNumber);
     Map<String, dynamic> getStudentOverallQuranProgress(String studentId);
     Map<int, Map<String, dynamic>> getStudent30AjzaStatus(String studentId);
     int getStudentCompletedAjzaCount(String studentId);
   }
   ```
8. **`RecitationTracksRepository`**:
   ```dart
   abstract class RecitationTracksRepository {
     List<RecitationTrack> getRecitationTracks({String? mosqueId, String? halaqaId, bool activeOnly});
     RecitationTrack addRecitationTrack({required String mosqueId, required String name, String category, String unitLabel, int totalUnits, int pointsPerUnit, bool isActive, List<String> targetHalaqaIds, String? sheikhId});
     void updateRecitationTrack(RecitationTrack track);
     void deleteRecitationTrack(String trackId);
     SubjectRecitationRecord recordSubjectRecitation({required String studentId, String? halaqaId, String? sheikhId, required String trackId, required String trackName, required int fromUnit, required int toUnit, required int pointsEarned, String? courseId, String? notes, bool countsTowardsStatistics});
     Map<String, dynamic> getStudentSubjectProgress(String studentId, String trackId);
     List<Map<String, dynamic>> getAllStudentSubjectProgresses(String studentId);
   }
   ```
9. **`CoursesRepository`**:
   ```dart
   abstract class CoursesRepository {
     List<IntensiveCourse> getIntensiveCourses({String? mosqueId, String? sheikhId});
     IntensiveCourse addIntensiveCourse({required String mosqueId, required String name, String? description, required DateTime startDate, required DateTime endDate, List<String> sheikhIds, List<String> halaqaIds, List<String> studentIds, List<int> daysOfWeek, String? startTime, String? endTime, bool countsTowardsQuranProgress});
     void updateIntensiveCourse(IntensiveCourse course);
     void deleteIntensiveCourse(String courseId);
     Map<String, dynamic> detectSessionTimingMode({required String halaqaId, String? studentId, DateTime? currentTime});
   }
   ```
10. **`TripsRepository`**:
    ```dart
    abstract class TripsRepository {
      List<Trip> getTrips({String? mosqueId, String? studentId, String? halaqaId});
      Trip addTrip({required String mosqueId, required String title, required String destination, required DateTime tripDate, String meetingTime, DateTime? deadlineDate, String? description, String requiredItems, List<String> targetHalaqaIds, List<String> targetStudentIds, int costPoints});
      void updateTrip(Trip trip);
      void deleteTrip(String tripId);
    }
    ```
11. **`RewardsRepository`**:
    ```dart
    abstract class RewardsRepository {
      List<Reward> getRewards({String? mosqueId});
      Reward addReward({required String mosqueId, required String title, String? description, required int pointsCost, bool isActive});
      void updateReward(Reward reward);
      void deleteReward(String rewardId);
      List<RewardRedemption> getRedemptions({String? mosqueId, String? studentId, String? status});
      RewardRedemption? claimReward({required String studentId, required String rewardId});
      Map<String, dynamic> dispenseReward({required String voucherCode, required String cashierName});
    }
    ```
12. **`CompetitionsRepository`**:
    ```dart
    abstract class CompetitionsRepository {
      List<Competition> getCompetitions({String? gender, String? mosqueId});
      Competition addCompetition({String mosqueId, required String title, required String description, required DateTime startDate, required DateTime endDate, bool countQuran, bool countHadith, bool countAttendance, int bonusPoints, required String genderBranch});
      void updateCompetition(Competition comp);
      void deleteCompetition(String competitionId);
      List<Map<String, dynamic>> getRankings({String? competitionId, String? mosqueId, String? halaqaId, String? gender, String? courseId});
    }
    ```
13. **`CommunityEventsRepository`**:
    ```dart
    abstract class CommunityEventsRepository {
      List<CommunityEvent> getCommunityEvents({String? gender, String? mosqueId});
      CommunityEvent addCommunityEvent({required String mosqueId, required String title, required String description, required String eventType, String? customTypeName, String timingType, String? prayerName, String prayerRelation, required String targetAudience, required DateTime eventDateTime, required String organizerType, required String organizerName, int durationMinutes});
      void updateCommunityEvent({required String eventId, ...});
      void deleteCommunityEvent(String eventId);
      void tapAttendance(String eventId);
    }
    ```
14. **`MessagesRepository`**:
    ```dart
    abstract class MessagesRepository {
      List<AppMessage> getStudentMessages(String studentId);
      List<AppMessage> getHalaqaMessages(String halaqaId);
      void sendMessage({required String studentId, required String halaqaId, required String senderType, required String senderName, required String content, String messageType});
    }
    ```
15. **`ExecutiveOverviewRepository`**:
    ```dart
    abstract class ExecutiveOverviewRepository {
      List<Map<String, dynamic>> getExecutiveOverview({String? mosqueId, String? sheikhId, String? halaqaId, String? searchQuery, DateTime? date});
    }
    ```

### 5.2 Dedicated Data Sources (Data Layer)

1. **`LocalStorageDataSource`**:
   - Encapsulates `SharedPreferences` read/write operations.
   - Methods: `loadAllCollections()`, `saveCollection<T>(String key, List<T> items)`, `getBool(String key)`, `setBool(String key, bool val)`, `getStringList(String key)`, `setStringList(String key, List<String> val)`.
2. **`SupabaseRemoteDataSource`**:
   - Encapsulates direct communication with Supabase: `fetchTable(String table)`, `upsertRecord(String table, Map<String, dynamic> data)`, `deleteRecord(String table, String id)`, `updateRecord(String table, String id, Map<String, dynamic> data)`.
   - Properly handles offline exceptions and null-client edge cases.
3. **`OfflineSyncQueueManager`**:
   - Manages `_pendingSyncQueue` state.
   - Persists queue to `SharedPreferences` on change.
   - Runs `processQueue(SupabaseRemoteDataSource remoteDataSource)`.
   - Handles network disconnection pauses and resumes cleanly without leaking background operations.

### 5.3 Backwards-Compatible `DataService` Facade / Adapter

The existing screens, tests, and BLoCs rely on `DataService` being a single injectable `ChangeNotifier`. To ensure **100% zero breakage**:

```dart
class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // Internal references to decomposed repositories
  late final AuthSessionRepository _authSessionRepo;
  late final MosquesRepository _mosquesRepo;
  late final SheikhsRepository _sheikhsRepo;
  late final HalaqatRepository _halaqatRepo;
  late final StudentsRepository _studentsRepo;
  late final AttendanceRepository _attendanceRepo;
  late final RecitationRepository _recitationRepo;
  late final RecitationTracksRepository _tracksRepo;
  late final CoursesRepository _coursesRepo;
  late final TripsRepository _tripsRepo;
  late final RewardsRepository _rewardsRepo;
  late final CompetitionsRepository _competitionsRepo;
  late final CommunityEventsRepository _eventsRepo;
  late final MessagesRepository _messagesRepo;
  late final ExecutiveOverviewRepository _overviewRepo;
  late final OfflineSyncQueueManager _syncManager;

  // Exact same public API methods delegate to respective repository:
  List<Mosque> getMosques({String? gender}) => _mosquesRepo.getMosques(gender: gender);
  Mosque addMosque(...) {
    final m = _mosquesRepo.addMosque(...);
    notifyListeners();
    return m;
  }
  // ... Identical delegating signatures for all methods!
}
```

This guarantees:
1. **Existing tests pass without modifying a single line of test code.**
2. **Existing screens continue to compile and function without alteration.**
3. **New BLoCs or Use Cases can inject granular repositories directly via `get_it` (e.g. `sl<AttendanceRepository>()`).**
4. **The 2,280-line monolith is decomposed into clean, maintainable, single-responsibility files under 300 lines each.**

---

## 6. Implementation Roadmap & Verification Gates

### Phase 1: Foundation Data Sources & Contracts
- Create `lib/data/datasources/local/` (`local_storage_datasource.dart`, `offline_sync_queue_manager.dart`).
- Create `lib/data/datasources/remote/` (`supabase_remote_datasource.dart`).
- Create granular domain repository contracts in `lib/domain/repositories/`.

### Phase 2: Concrete Repository Implementations
- Implement concrete repositories in `lib/data/repositories/`.
- Ensure all business logic (timing detection, Ayah deduplication, vouchers, ratings) is preserved with exact parity.

### Phase 3: Facade Wiring & DI Integration
- Refactor `DataService` to delegate all calls to the modular repositories and trigger `notifyListeners()`.
- Update `lib/core/di/injection.dart` to register granular repositories alongside `DataService` and `MosqueRepository`.

### Phase 4: Continuous Quality Gate
- Run `flutter analyze` ensuring 0 errors and 0 warnings.
- Run `flutter test` verifying all 38 tests pass with 100% green status.
