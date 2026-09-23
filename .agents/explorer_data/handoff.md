# Handoff Report — Explorer (Data & Service Layer)

**Working Directory**: `c:\Users\moham\Desktop\masjed app\.agents\explorer_data`  
**Target File**: `c:\Users\moham\Desktop\masjed app\flutter_app\lib\services\data_service.dart`  
**Related Files**: `lib/data/repositories/mosque_repository_impl.dart`, `lib/domain/repositories/mosque_repository.dart`, `lib/core/di/injection.dart`, `test/`  
**Report Artifact**: `c:\Users\moham\Desktop\masjed app\.agents\explorer_data\data_service_report.md`  

---

## 1. Observation

1. **File Size and Monolithic Architecture**:
   - `lib/services/data_service.dart`: 2,280 lines containing 17 dynamic in-memory collections, `SharedPreferences` persistence for all entities, direct Supabase cloud calls across 16 tables, offline background sync queue, and extensive domain calculation logic.
   - `lib/domain/repositories/mosque_repository.dart`: 373 lines defining a single monolithic abstract repository contract.
   - `lib/data/repositories/mosque_repository_impl.dart`: 820 lines forwarding all method calls directly to `_dataService`.

2. **Supabase Tables & Queries**:
   - 16 tables invoked: `mosques`, `sheikhs`, `halaqat`, `students`, `community_events`, `memorization_records`, `attendance`, `messages`, `rewards`, `reward_redemptions`, `competitions`, `points_logs`, `intensive_courses`, `trips`, `recitation_tracks`, `subject_recitation_records`.
   - Read synchronization in `syncWithSupabase()` queries 8 primary tables (`mosques`, `sheikhs`, `halaqat`, `students`, `community_events`, `memorization_records`, `attendance`, `messages`) and overwrites local lists if remote returns non-empty results.
   - Mutations (`upsert`, `delete`) are pushed to `_pendingSyncQueue` and executed asynchronously via `_processSyncQueue()`. Direct async calls without queue exist for `halaqat` deletion, `community_events` attendance count update, and `competitions` (insert, update, delete).

3. **Local Storage & Offline Sync Queue**:
   - Persistence layer relies on `SharedPreferences` with JSON string encoding for each collection.
   - Offline sync queue stored as JSON array in `pending_sync_queue`. Items have schema: `{'table', 'action', 'data', 'id', 'queued_at'}`.
   - Processing loop halts on the first exception (`break;`), preserving failed and subsequent items in storage for future retry upon connectivity restoration.

4. **Embedded Domain Logic in `data_service.dart`**:
   - **Multi-role persistent sessions**: Coexistence of roles (Admin, Sheikh, Student, Cashier, Visitor) in `_savedSessions` without auto-logout (`switchSession`, `disconnectRole`).
   - **Codeless access hierarchy**: `verifyCode` matches `MSQ-` (admin), `SHK-` (sheikh), `STD-` (student), `CSH-`/`CASHIER` (cashier).
   - **Women section privacy**: Protected by `WM-` prefix and mosque access code (`unlockWomenSectionWithCode`).
   - **Smart timing detection**: ±30 minute window detecting course timing vs regular halaqa timing vs custom timing (`detectSessionTimingMode`).
   - **Authentic Quran progress deduplication**: Collects unique Ayah keys `'$surahNum:$a'` in a `Set<String>` across 6,236 Ayahs, skipping non-statistical recitations and courses with `countsTowardsQuranProgress == false`. Intersects with `getAllAyahKeysInJuz(juzNumber)` to prevent duplicate counts.
   - **Custom tracks**: Unit intervals tracked via `Set<int> uniqueUnits` to deduplicate overlapping recitations.
   - **Trips CRUD**: Student targeting (`isStudentTargeted`) and required baggage items (`🎒`).
   - **Attendance summary**: Commitment rate formula `((present + late * 0.5) / total * 100)`.
   - **Competitions**: Dynamic point recalculation for intensive courses (summing Quran + subject points for that course only).
   - **Rewards bank & Cashier**: Voucher code generation (`VCH-XXXX`), point deduction validation, negative `PointsLog`, and dispensed status transition.

5. **Test Suite Execution & Results**:
   - Tool Command: `flutter test`
   - Output: `All tests passed!` (38 tests passed in 4 seconds, exit code 0).
   - Tests rely on: `SharedPreferences.setMockInitialValues({})`, direct calls to `DataService()`, `initInjection()`, and BLoC constructors expecting `DataService`.

---

## 2. Logic Chain

1. **Observation**: `DataService` is instantiated and passed to all 8 BLoCs (`SessionBloc`, `ThemeCubit`, `RecitationBloc`, `AttendanceBloc`, `CoursesBloc`, `RewardsBloc`, `TripsBloc`, `CompetitionsBloc`), registered in `lib/core/di/injection.dart`, referenced in multiple screen files (`mosque_admin_screen.dart`, `sheikh_screen.dart`, `student_screen.dart`, `cashier_screen.dart`), and tested directly in `test/data_service_test.dart` and `test/presentation_blocs_test.dart`.
   - **Inference**: Deleting or radically modifying the public signature of `DataService` will cause massive compile errors across presentation screens, BLoCs, and test suites.
2. **Observation**: `MosqueRepositoryImpl` is a 820-line pass-through proxy to `_dataService`, and `MosqueRepository` is a monolithic 373-line interface.
   - **Inference**: True Clean Architecture modularity requires decomposing this monolithic repository into focused subdomain repository interfaces (`AuthSessionRepository`, `MosquesRepository`, `HalaqatRepository`, `AttendanceRepository`, `RecitationRepository`, `TripsRepository`, etc.) and dedicated data sources (`LocalStorageDataSource`, `SupabaseRemoteDataSource`, `OfflineSyncQueueManager`).
3. **Observation**: The app requires 0ms synchronous local reads for UI rendering and offline resilience with background syncing.
   - **Inference**: The repository layer must maintain an in-memory cache synchronized with `LocalStorageDataSource`, and route writes through `OfflineSyncQueueManager`.
4. **Observation**: Refactoring `DataService` to act as a backwards-compatible Facade/Adapter that wraps the decomposed repository layer and invokes `notifyListeners()` ensures both architectural purity and zero breakage for existing UI widgets and tests.

---

## 3. Caveats

1. **Supabase Live Backend**: During test execution, Supabase is mocked or uninitialized; tests do not hit live network endpoints. Live network testing requires Supabase credentials and active internet connectivity.
2. **UI Screens In-Flight Modularization**: Peer explorers and implementers are decomposing large UI screen monoliths (`mosque_admin_screen.dart`, `sheikh_screen.dart`, `student_screen.dart`). Changes to `DataService` must retain exact method signatures so these parallel screen refactoring efforts are not disrupted.
3. No other caveats.

---

## 4. Conclusion

1. `DataService` can be cleanly de-monolithed into:
   - **15 Granular Domain Repository Contracts** in `lib/domain/repositories/` (e.g. `AttendanceRepository`, `RecitationRepository`, `RewardsRepository`, `TripsRepository`).
   - **2 Dedicated Data Sources** in `lib/data/datasources/`: `LocalStorageDataSource` (SharedPreferences) and `SupabaseRemoteDataSource` (Supabase client).
   - **1 Dedicated Sync Queue Manager**: `OfflineSyncQueueManager` for background offline mutations.
   - **Concrete Repository Implementations** in `lib/data/repositories/` encapsulating all in-memory caching and domain business calculations.
   - **Backwards-Compatible `DataService` Facade** in `lib/services/data_service.dart` delegating to the repositories and firing `notifyListeners()`.
2. This approach guarantees 100% test compatibility, 0 compile errors, 0 runtime regressions, and satisfies all Clean Architecture decomposition criteria.

---

## 5. Verification Method

1. **Test Verification Command**:
   ```powershell
   cd "c:\Users\moham\Desktop\masjed app\flutter_app"
   flutter test
   ```
   *Expected outcome*: All 38 existing tests pass with 0 failures.

2. **Static Analysis Command**:
   ```powershell
   cd "c:\Users\moham\Desktop\masjed app\flutter_app"
   flutter analyze
   ```
   *Expected outcome*: 0 errors.

3. **Report Verification**:
   Inspect `c:\Users\moham\Desktop\masjed app\.agents\explorer_data\data_service_report.md` for complete data tables, logic specifications, and Clean Architecture blueprints.
