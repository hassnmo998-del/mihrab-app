## 2026-09-12T14:13:54Z

You are a Worker implementing Milestone 1: Domain Entities & Models De-monolithing for the Flutter Mosque application.

Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\worker_m1
The Flutter application directory is: c:\Users\moham\Desktop\masjed app\flutter_app
Authoritative User Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
Project Document: c:\Users\moham\Desktop\masjed app\PROJECT.md
Specification Report: c:\Users\moham\Desktop\masjed app\.agents\spec_miner_models\models_spec_report.md
Handoff Report: c:\Users\moham\Desktop\masjed app\.agents\spec_miner_models\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

File Write Ownership:
You have exclusive write ownership of files under `c:\Users\moham\Desktop\masjed app\flutter_app\lib\models\`.

Your Mission:
1. Read the specification report at `c:\Users\moham\Desktop\masjed app\.agents\spec_miner_models\models_spec_report.md`.
2. Extract each of the 17 domain entities from `lib/models/models.dart` into its dedicated file under `c:\Users\moham\Desktop\masjed app\flutter_app\lib\models/`:
   - `mosque.dart` (Mosque)
   - `sheikh.dart` (Sheikh)
   - `halaqa.dart` (Halaqa)
   - `student.dart` (Student)
   - `memorization_record.dart` (MemorizationRecord)
   - `attendance_record.dart` (AttendanceRecord)
   - `app_message.dart` (AppMessage)
   - `community_event.dart` (CommunityEvent)
   - `points_log.dart` (PointsLog)
   - `competition.dart` (Competition)
   - `active_session.dart` (ActiveSession)
   - `reward.dart` (Reward)
   - `reward_redemption.dart` (RewardRedemption)
   - `intensive_course.dart` (IntensiveCourse)
   - `trip.dart` (Trip) -> Must include `import 'student.dart';` since Trip references Student
   - `recitation_track.dart` (RecitationTrack)
   - `subject_recitation_record.dart` (SubjectRecitationRecord)
3. Replace `c:\Users\moham\Desktop\masjed app\flutter_app\lib\models\models.dart` with a clean backwards-compatible barrel export file exporting all 17 entity files.
4. Run verification in `c:\Users\moham\Desktop\masjed app\flutter_app`:
   - `flutter test` (all 38 existing tests MUST pass with 0 failures)
   - `flutter analyze` (must pass with 0 errors)
5. Write your handoff report to `c:\Users\moham\Desktop\masjed app\.agents\worker_m1\handoff.md` with:
   - Summary of extracted files and line counts (all must be well under 500 lines)
   - Build and test commands executed and exact outputs
6. Send a message to your parent when done with test and analyze outcomes.
