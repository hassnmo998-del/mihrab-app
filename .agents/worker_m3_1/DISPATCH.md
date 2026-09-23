## 2026-09-12T19:54:09Z

You are a Worker implementing Milestone 3: Presentation Screen Monolith Deconstruction for the Mosque & Quran Halaqat Flutter application.

Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\worker_m3_1
The Flutter application directory is: c:\Users\moham\Desktop\masjed app\flutter_app
Authoritative User Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md (read header ## 2026-09-12T13:47:05Z first)
Project Document: c:\Users\moham\Desktop\masjed app\PROJECT.md
Presentation Extraction Blueprint: c:\Users\moham\Desktop\masjed app\.agents\explorer_presentation\presentation_report.md
Presentation Explorer Handoff: c:\Users\moham\Desktop\masjed app\.agents\explorer_presentation\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

File Write Ownership:
You have exclusive write ownership of files under `c:\Users\moham\Desktop\masjed app\flutter_app\lib\screens/`.
Do NOT write to other agents' directories; write your state/handoff only to `c:\Users\moham\Desktop\masjed app\.agents\worker_m3_1`.

Your Mission:
Follow the exact extraction blueprint in `presentation_report.md` to deconstruct the three presentation monoliths into clean, modular, maintainable tabs and subcomponents:

1. Mosque Admin Screen (`lib/screens/mosque_admin_screen.dart`, originally 3,432 LOC) -> deconstruct into `lib/screens/admin/`:
   - `lib/screens/admin/tabs/admin_sheikhs_tab.dart` (Tab 0: Sheikhs list & modal triggers)
   - `lib/screens/admin/tabs/admin_halaqat_tab.dart` (Tab 1: Halaqat list & modal triggers)
   - `lib/screens/admin/tabs/admin_students_tab.dart` (Tab 2: Students list, search, filter & modal triggers)
   - `lib/screens/admin/tabs/admin_courses_tab.dart` (Tab 3: Intensive courses list & triggers)
   - `lib/screens/admin/dialogs/admin_course_form_dialog.dart` (Consolidated add/edit course dialog, <300 LOC)
   - `lib/screens/admin/tabs/admin_trips_tab.dart` (Tab 4: Trips list & modal triggers)
   - `lib/screens/admin/tabs/admin_tracks_tab.dart` (Tab 5: Recitation tracks list & modal triggers)
   - `lib/screens/admin/tabs/admin_rewards_tab.dart` (Tab 6: Rewards list & modal triggers)
   - `lib/screens/admin/tabs/admin_overview_tab.dart` (Tab 7: Executive overview matrix)
   - `lib/screens/admin/tabs/admin_events_tab.dart` (Tab 8: Community events list & modal triggers)
   - `lib/screens/admin/widgets/admin_locked_view.dart` (Registration form and access code unlock)
   - `lib/screens/admin/widgets/admin_header_banner.dart` (Top app bar, metrics, QR badge dialog buttons)
   - Refactor `lib/screens/mosque_admin_screen.dart` into a slim top-level coordinator (~100-120 LOC) hosting `TabBarView`.

2. Sheikh Screen (`lib/screens/sheikh_screen.dart`, originally 2,756 LOC) -> deconstruct into `lib/screens/sheikh/`:
   - `lib/screens/sheikh/tabs/sheikh_attendance_tab.dart` (Tab 0: Attendance grid, date picker, points dialog)
   - `lib/screens/sheikh/tabs/sheikh_memorization_tab.dart` (Tab 1: Memorization management tab)
   - `lib/screens/sheikh/widgets/sheikh_quran_recitation_inputs.dart` (Quran Surah/Ayah selection & batch recording, <250 LOC)
   - `lib/screens/sheikh/dialogs/multi_surah_selector_dialog.dart` (Multi-Surah selector dialog, <100 LOC)
   - `lib/screens/sheikh/widgets/sheikh_today_recitations_card.dart` (Today's recorded recitations list, <100 LOC)
   - `lib/screens/sheikh/tabs/sheikh_tracks_tab.dart` (Tab 2: Custom recitation tracks)
   - `lib/screens/sheikh/tabs/sheikh_trips_tab.dart` (Tab 3: Trips management & attendance, <350 LOC)
   - `lib/screens/sheikh/dialogs/sheikh_trip_form_dialog.dart` (Trip creation/editing dialog, <200 LOC)
   - `lib/screens/sheikh/tabs/sheikh_overview_tab.dart` (Tab 4: Sheikh overview matrix)
   - `lib/screens/sheikh/tabs/sheikh_students_tab.dart` (Tab 5: Students list & modal triggers)
   - `lib/screens/sheikh/tabs/sheikh_messages_tab.dart` (Tab 6: Messaging & compose/reply dialogs)
   - `lib/screens/sheikh/widgets/sheikh_locked_view.dart` (Sheikh login/access code view)
   - `lib/screens/sheikh/widgets/sheikh_header_banner.dart` (Top header banner with actions)
   - Refactor `lib/screens/sheikh_screen.dart` into a slim top-level coordinator (~100-120 LOC) hosting `TabBarView`.

3. Student Screen (`lib/screens/student_screen.dart`, originally 1,680 LOC) -> deconstruct into `lib/screens/student/`:
   - `lib/screens/student/tabs/student_progress_tab.dart` (Tab 0: Quran 30 Ajza tree & progress view)
   - `lib/screens/student/dialogs/student_juz_modal.dart` (Juz details dialog)
   - `lib/screens/student/tabs/student_attendance_tab.dart` (Tab 1: Attendance history & commitment rate)
   - `lib/screens/student/tabs/student_trips_tab.dart` (Tab 2: Trips list & baggage requirements display)
   - `lib/screens/student/tabs/student_rewards_tab.dart` (Tab 3: Rewards catalog & claim voucher)
   - `lib/screens/student/dialogs/student_multi_reward_claim_dialog.dart` (Multi-voucher claim dialog)
   - `lib/screens/student/tabs/student_points_tab.dart` (Tab 4: Points logs history)
   - `lib/screens/student/tabs/student_contact_tab.dart` (Tab 5: Contact sheikh / messages)
   - `lib/screens/student/tabs/student_rankings_tab.dart` (Tab 6: Leaderboard & competitions)
   - `lib/screens/student/widgets/student_locked_view.dart` (Student login/access code view)
   - `lib/screens/student/widgets/student_header_banner.dart` (Top header banner)
   - Refactor `lib/screens/student_screen.dart` into a slim top-level coordinator (~100 LOC) hosting `TabBarView`.

4. STRICT SIZE CONSTRAINT:
   Every single file under `lib/screens/` (including all tab files, widget files, dialog files, and the top-level screen files) MUST be strictly UNDER 500 lines of code.

5. Verification and Quality Checks:
   In `c:\Users\moham\Desktop\masjed app\flutter_app`:
   - Run `flutter analyze` and ensure 0 errors.
   - Run `flutter test` and ensure 100% passing rate across all 118+ tests.
   - Count lines of code across all files in `lib/screens/` to prove every file is <500 LOC.

6. Report:
   Write your handoff report to `c:\Users\moham\Desktop\masjed app\.agents\worker_m3_1\handoff.md` with:
   - Line count table of all presentation files
   - Build & test verification outputs (`flutter analyze`, `flutter test`)
   - Architecture summary
   Send a message to your parent when complete.
