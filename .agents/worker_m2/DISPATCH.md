## 2026-09-12T14:56:17Z

You are a Worker implementing Milestone 2: Data & Service Layer Modularization for the Flutter Mosque application.

Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\worker_m2
The Flutter application directory is: c:\Users\moham\Desktop\masjed app\flutter_app
Authoritative User Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
Project Document: c:\Users\moham\Desktop\masjed app\PROJECT.md
Data Explorer Report: c:\Users\moham\Desktop\masjed app\.agents\explorer_data\data_service_report.md
Data Explorer Handoff: c:\Users\moham\Desktop\masjed app\.agents\explorer_data\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

File Write Ownership:
You have exclusive write ownership of files under:
- `c:\Users\moham\Desktop\masjed app\flutter_app\lib\data/`
- `c:\Users\moham\Desktop\masjed app\flutter_app\lib\domain/repositories/`
- `c:\Users\moham\Desktop\masjed app\flutter_app\lib\services\data_service.dart`

Your Mission:
1. Review the data architecture report at `c:\Users\moham\Desktop\masjed app\.agents\explorer_data\data_service_report.md`.
2. Extract the data and storage layer into dedicated data sources in `lib/data/datasources/`:
   - `local_storage_datasource.dart`: Handles SharedPreferences persistence, JSON encoding/decoding, and in-memory cache for all 17 entity lists.
   - `supabase_remote_datasource.dart`: Handles direct Supabase client remote calls across all 16 tables.
   - `offline_sync_queue_manager.dart`: Handles the persistent FIFO queue (`pending_sync_queue`), enqueueing mutations, and processing sync queue on network availability.
3. Modularize repository contracts and implementations:
   - Create focused domain repository interfaces under `lib/domain/repositories/` (e.g. `auth_session_repository.dart`, `mosques_repository.dart`, `sheikhs_repository.dart`, `halaqat_repository.dart`, `students_repository.dart`, `attendance_repository.dart`, `recitation_repository.dart`, `trips_repository.dart`, `rewards_repository.dart`, `competitions_repository.dart`, `events_repository.dart`, `messages_repository.dart`).
   - Implement concrete repositories under `lib/data/repositories/` orchestrating the data sources and business rules (e.g., smart timing detection ±30m window, Quran 6,236 Ayahs & 30 Ajza deduplication, custom track deduplication, attendance commitment formula, voucher generation `VCH-XXXX` and cashier dispensation).
4. Update `lib/services/data_service.dart`:
   - Provide a clean, backwards-compatible `DataService` facade (extending `ChangeNotifier`) that delegates to these underlying repositories and data sources, preserving all existing method signatures and `notifyListeners()` calls.
   - This ensures 100% backwards compatibility with all existing screens, BLoCs, and automated tests.
5. Run verification commands in `c:\Users\moham\Desktop\masjed app\flutter_app`:
   - `flutter analyze` (must have 0 errors)
   - `flutter test` (must pass 100% of all tests — all 89+ tests must pass with 0 failures)
6. Write your handoff report to `c:\Users\moham\Desktop\masjed app\.agents\worker_m2\handoff.md` detailing the extracted files, architecture, test results, and analysis outputs.
7. Send a message to your parent when done with test and analyze outcomes.
