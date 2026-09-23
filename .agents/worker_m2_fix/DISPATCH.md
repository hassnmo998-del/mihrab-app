## 2026-09-12T16:17:00Z
You are a Worker implementing Milestone 2 Remediation for the Flutter Mosque application.

Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\worker_m2_fix
The Flutter application directory is: c:\Users\moham\Desktop\masjed app\flutter_app
Reviewer 2 Critique: c:\Users\moham\Desktop\masjed app\.agents\reviewer_m2_2\handoff.md
Authoritative User Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
Project Document: c:\Users\moham\Desktop\masjed app\PROJECT.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

File Write Ownership:
You have exclusive write ownership of files under `c:\Users\moham\Desktop\masjed app\flutter_app\lib\data\repositories/` and `c:\Users\moham\Desktop\masjed app\flutter_app\lib\services\data_service.dart`.

Your Mission:
1. Read the exact review feedback at `c:\Users\moham\Desktop\masjed app\.agents\reviewer_m2_2\handoff.md`.
2. Refactor `lib/data/repositories/mosque_repository_impl.dart`:
   - ELIMINATE LAYER INVERSION: Currently it injects and delegates to `DataService`. Change it so it directly delegates to the 15 underlying concrete repositories (`AuthSessionRepositoryImpl`, `MosquesRepositoryImpl`, `SheikhsRepositoryImpl`, `HalaqatRepositoryImpl`, `StudentsRepositoryImpl`, `AttendanceRepositoryImpl`, `RecitationRepositoryImpl`, `RecitationTracksRepositoryImpl`, `CoursesRepositoryImpl`, `TripsRepositoryImpl`, `RewardsRepositoryImpl`, `CompetitionsRepositoryImpl`, `CommunityEventsRepositoryImpl`, `MessagesRepositoryImpl`, `ExecutiveOverviewRepositoryImpl`).
   - STRICT LINE COUNT ENFORCEMENT (<300 LOC): Currently it is 739 non-blank LOC / 823 raw lines. Decompose `MosqueRepositoryImpl` using composite mixins, extension delegates, or part files (e.g. `mosque_repo_auth_delegate.dart`, `mosque_repo_quran_delegate.dart`, etc.) so that NO SINGLE FILE in `lib/data/repositories/` exceeds 300 lines of code!
3. Refactor `lib/data/repositories/recitation_repository_impl.dart`:
   - Currently 303 non-blank lines / 331 raw lines. Trim comments, or extract Quran Ayah parsing/deduplication helper functions into a helper class/file so that `recitation_repository_impl.dart` is strictly UNDER 300 lines of code.
4. Verify every single file in `lib/data/repositories/` is strictly under 300 lines of code.
5. Run verification in `c:\Users\moham\Desktop\masjed app\flutter_app`:
   - `flutter analyze` (must pass with 0 issues)
   - `flutter test` (must pass 100% of all tests — 118/118 tests passing)
6. Write your handoff report to `c:\Users\moham\Desktop\masjed app\.agents\worker_m2_fix\handoff.md`.
7. Send a message to your parent when done with test and analyze outcomes.

## 2026-09-12T16:45:57Z
**Context**: Milestone 2 Remediation Progress
**Content**: Checking on your test execution. We observed the part files (`mosque_repo_*_part.dart`) and `quran_progress_calculator.dart` created in `lib/data/repositories/`. Are you currently running `flutter test` and `flutter analyze`?
**Action**: Please provide a brief status update and update `progress.md`.
