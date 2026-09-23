# Project: Mosque & Quran Halaqat Flutter App Clean Architecture Refactoring

## Architecture
Clean, feature-first modular architecture separating domain entities, data sources, repository contracts, and decoupled presentation widgets:
- **Domain Layer**: 17 decoupled entity models (`lib/models/*.dart`) exported cleanly via `lib/models/models.dart`. Abstract repository contracts in `lib/domain/repositories/`.
- **Data Layer**: Dedicated data sources (`LocalStorageDataSource` for SharedPreferences cache, `SupabaseRemoteDataSource` for 16 Supabase tables, `OfflineSyncQueueManager` for offline FIFO background mutations). Concrete repository implementations in `lib/data/repositories/`. A backwards-compatible `DataService` facade in `lib/services/data_service.dart`.
- **Presentation Layer**: Decomposed, modular tab widgets and dialogs for Mosque Admin (9 tabs), Sheikh (7 tabs), and Student (7 tabs) under `lib/screens/admin/`, `lib/screens/sheikh/`, and `lib/screens/student/`. Every presentation file is strictly `< 500 lines of code`.
- **State & DI**: BLoC pattern (`flutter_bloc`) with dependency injection via `get_it` and reactive `DataService` listener notifications.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | `Mosque` entity | Dedicated model file `lib/models/mosque.dart` | M1 | Survey |
| 2 | `Sheikh` entity | Dedicated model file `lib/models/sheikh.dart` | M1 | Survey |
| 3 | `Halaqa` entity | Dedicated model file `lib/models/halaqa.dart` | M1 | Survey |
| 4 | `Student` entity | Dedicated model file `lib/models/student.dart` | M1 | Survey |
| 5 | `MemorizationRecord` entity | Dedicated model file `lib/models/memorization_record.dart` | M1 | Survey |
| 6 | `AttendanceRecord` entity | Dedicated model file `lib/models/attendance_record.dart` | M1 | Survey |
| 7 | `AppMessage` entity | Dedicated model file `lib/models/app_message.dart` | M1 | Survey |
| 8 | `CommunityEvent` entity | Dedicated model file `lib/models/community_event.dart` | M1 | Survey |
| 9 | `PointsLog` entity | Dedicated model file `lib/models/points_log.dart` | M1 | Survey |
| 10 | `Competition` entity | Dedicated model file `lib/models/competition.dart` | M1 | Survey |
| 11 | `ActiveSession` entity | Dedicated model file `lib/models/active_session.dart` | M1 | Survey |
| 12 | `Reward` entity | Dedicated model file `lib/models/reward.dart` | M1 | Survey |
| 13 | `RewardRedemption` entity | Dedicated model file `lib/models/reward_redemption.dart` | M1 | Survey |
| 14 | `IntensiveCourse` entity | Dedicated model file `lib/models/intensive_course.dart` | M1 | Survey |
| 15 | `Trip` entity | Dedicated model file `lib/models/trip.dart` (depends on `Student`) | M1 | Survey |
| 16 | `RecitationTrack` entity | Dedicated model file `lib/models/recitation_track.dart` | M1 | Survey |
| 17 | `SubjectRecitationRecord` entity | Dedicated model file `lib/models/subject_recitation_record.dart` | M1 | Survey |
| 18 | `models.dart` Barrel Export | Exports all 17 entity files for 100% backwards compatibility | M1 | Survey |
| 19 | Supabase Remote Data Source | Handles remote queries across all 16 tables | M2 | Survey |
| 20 | Local Storage Data Source | Handles instant in-memory cache and SharedPreferences persistence | M2 | Survey |
| 21 | Offline Sync Queue Manager | Manages persistent FIFO queue for offline writes | M2 | Survey |
| 22 | Multi-Role Persistent Sessions | Visitor, Admin, Sheikh, Student, Cashier persistent sessions | M2 | Survey |
| 23 | Smart Recitation Timing Detection | ±30 min window for course vs regular vs custom recitation timing | M2 | Survey |
| 24 | Authentic Quran Progress Deduplication | 6,236 Ayahs & 30 Ajza deduplication via Set of Ayah keys | M2 | Survey |
| 25 | Custom Recitation Tracks Progress | Mutun/Hadith/Book pages deduplication across units | M2 | Survey |
| 26 | Trips CRUD & Baggage Checklist | Student targeting and required items ("ما يلزم إحضاره مع الطالب 🎒") | M2 | Survey |
| 27 | Student Attendance Commitment | Commitment rate calculation: `(present + late*0.5)/total * 100` | M2 | Survey |
| 28 | Competitions & Course Leaderboard | Course-specific points recalculation and dual filtering | M2 | Survey |
| 29 | Rewards Bank & Cashier Dispensation | Voucher code generation (`VCH-XXXX`), QR validation, cashier redemption | M2 | Survey |
| 30 | Women Section Privacy | Mosque code validation with `WM-` prefix | M2 | Survey |
| 31 | Unified QR & Barcode Actions | 3 actions (Copy, Share, Save/Print) across QR dialogs | M3 | Survey |
| 32 | Mosque Admin 9 Tabs Modularization | 9 distinct tab widgets + dialogs in `lib/screens/admin/`, each <500 LOC | M3 | Survey |
| 33 | Sheikh Screen 7 Tabs Modularization | 7 distinct tab widgets + dialogs in `lib/screens/sheikh/`, each <500 LOC | M3 | Survey |
| 34 | Student Screen 7 Tabs Modularization | 7 distinct tab widgets + dialogs in `lib/screens/student/`, each <500 LOC | M3 | Survey |
| 35 | Presentation Components & Dialogs | Modular dialog files (`admin_course_form_dialog.dart`, etc.), each <500 LOC | M3 | Survey |
| 36 | Strict File Size Constraint (<500 LOC) | Zero presentation files exceeding 500 lines of code | M4 | Survey |
| 37 | Automated Test Suite Integrity | All 38 existing tests pass with 0 failures | M4 | Survey |
| 38 | Static Analysis Cleanliness | `flutter analyze` reports 0 breaking errors | M4 | Survey |
| 39 | Forensic Integrity Audit | Systematic verification of authentic logic, no mocks/stubs bypassing code | M4 | Survey |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Domain Entities & Models De-monolithing | Split `lib/models/models.dart` into 17 files, barrel export | none | DONE |
| 2 | Data & Service Layer Modularization | Decompose `data_service.dart` into data sources, repositories & facade | M1 | DONE |
| 3 | Presentation Screens De-monolithing | Modularize Admin (9 tabs), Sheikh (7 tabs), Student (7 tabs) <500 LOC | M1, M2 | DONE |
| 4 | Verification, Audit & Delivery | Verify 100% tests pass (118/118), 0 analyze errors, <500 LOC check, Forensic Audit | M3 | DONE |

---

## Interface Contracts

### Domain Layer Barrel Contract (`lib/models/models.dart`)
```dart
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

### Data Layer Facade Contract (`lib/services/data_service.dart`)
Preserves the public API of `DataService` extends `ChangeNotifier` so that all existing BLoCs, UI widgets, and tests continue to work without a single broken invocation. It delegates data operations to underlying domain repositories and notifies listeners.

### Presentation Layer Screen Contract
- `MosqueAdminScreen`: Top-level coordinator (~120 LOC) hosting `TabBarView` rendering 9 modular tabs:
  `AdminSheikhsTab`, `AdminHalaqatTab`, `AdminStudentsTab`, `AdminCoursesTab`, `AdminTripsTab`, `AdminTracksTab`, `AdminRewardsTab`, `AdminExecutiveOverviewTab`, `AdminEventsTab`.
- `SheikhScreen`: Top-level coordinator (~110 LOC) hosting `TabBarView` rendering 7 modular tabs:
  `SheikhAttendanceTab`, `SheikhMemorizationTab`, `SheikhCurriculumTracksTab`, `SheikhTripsTab`, `SheikhExecutiveOverviewTab`, `SheikhStudentsTab`, `SheikhMessagesTab`.
- `StudentScreen`: Top-level coordinator (~100 LOC) hosting `TabBarView` rendering 7 modular tabs:
  `StudentProgressTab`, `StudentAttendanceTab`, `StudentTripsTab`, `StudentRewardsTab`, `StudentPointsTab`, `StudentContactTab`, `StudentRankingsTab`.

---

## Code Layout
```
flutter_app/lib/
├── models/                         # 17 domain entities + models.dart barrel
│   ├── mosque.dart
│   ├── sheikh.dart
│   ├── halaqa.dart
│   ├── student.dart
│   ├── memorization_record.dart
│   ├── attendance_record.dart
│   ├── app_message.dart
│   ├── community_event.dart
│   ├── points_log.dart
│   ├── competition.dart
│   ├── active_session.dart
│   ├── reward.dart
│   ├── reward_redemption.dart
│   ├── intensive_course.dart
│   ├── trip.dart
│   ├── recitation_track.dart
│   ├── subject_recitation_record.dart
│   └── models.dart                 # Backward-compatible barrel
├── domain/
│   ├── repositories/               # Domain repository contracts
│   └── usecases/                   # Clean architecture usecases
├── data/
│   ├── datasources/
│   │   ├── local_storage_datasource.dart
│   │   ├── supabase_remote_datasource.dart
│   │   └── offline_sync_queue_manager.dart
│   └── repositories/               # Concrete repository implementations
├── services/
│   └── data_service.dart           # Backwards-compatible Facade adapter
├── screens/
│   ├── mosque_admin_screen.dart    # Slim coordinator
│   ├── sheikh_screen.dart          # Slim coordinator
│   ├── student_screen.dart         # Slim coordinator
│   ├── admin/                      # 9 Admin modular tab widgets (<500 LOC each)
│   ├── sheikh/                     # 7 Sheikh modular tab widgets (<500 LOC each)
│   └── student/                    # 7 Student modular tab widgets (<500 LOC each)
└── widgets/                        # Shared UI components & dialogs (<500 LOC each)
```
