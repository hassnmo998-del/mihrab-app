# DISPATCH: Explorer (Data & Service Layer)

- Working Directory: c:\Users\moham\Desktop\masjed app\.agents\explorer_data
- Target Files: c:\Users\moham\Desktop\masjed app\flutter_app\lib\services\data_service.dart, repositories, local storage, test/
- Original Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
- Deliverables: data_service_report.md and handoff.md in working directory

## 2026-09-12T13:56:28Z
You are an Explorer investigating the Data and Service layer of the Flutter Mosque application.
Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\explorer_data
Authoritative request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md (read header ## 2026-09-12T13:47:05Z).
Target file: c:\Users\moham\Desktop\masjed app\flutter_app\lib\services\data_service.dart (2,280 lines) and related files in `lib/services/` and `lib/data/` if any.

Your mission:
1. Analyze `data_service.dart` in detail:
   - What Supabase tables and queries are invoked?
   - What local caching, offline sync queue, and local persistence are implemented?
   - What business logic resides in `data_service.dart` (e.g. smart recitation timing detection ±30 min window, Quran deduplication across 30 Ajza / 6,236 Ayahs, trips CRUD, attendance log & commitment calculations, leaderboard filtering, rewards bank/vouchers, cashier dispensation)?
2. Inspect the test suite in `flutter_app/test/` to see what tests exercise `DataService`, how mocks or fakes are used, and what contract guarantees exist.
3. Propose a modular Clean Architecture decomposition:
   - Abstract repository contracts / interfaces (e.g. `HalaqatRepository`, `AttendanceRepository`, `RecitationRepository`, `RewardsRepository`, `TripsRepository`, etc.)
   - Dedicated remote data source (`SupabaseDataSource` or feature-specific remote sources)
   - Dedicated local data source / offline sync manager
   - Concrete repository implementations
   - Backwards-compatible `DataService` facade (or adapter) so existing screens/tests calling `DataService` methods continue to work seamlessly during refactoring.
4. Write your complete analysis to:
   `c:\Users\moham\Desktop\masjed app\.agents\explorer_data\data_service_report.md`
   and handoff to:
   `c:\Users\moham\Desktop\masjed app\.agents\explorer_data\handoff.md`.
5. Send a message to your parent when done with a summary of your findings and modular design.

