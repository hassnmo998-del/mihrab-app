## 2026-09-12T17:04:24Z
You are a Worker implementing Milestone 3: Presentation Screen Monolith Deconstruction for the Flutter Mosque application.

Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\worker_m3
The Flutter application directory is: c:\Users\moham\Desktop\masjed app\flutter_app
Authoritative User Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md (header ## 2026-09-12T13:47:05Z)
Project Document: c:\Users\moham\Desktop\masjed app\PROJECT.md
Presentation Blueprint: c:\Users\moham\Desktop\masjed app\.agents\explorer_presentation\presentation_report.md
Presentation Handoff: c:\Users\moham\Desktop\masjed app\.agents\explorer_presentation\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

File Write Ownership:
You have exclusive write ownership of files under `c:\Users\moham\Desktop\masjed app\flutter_app\lib\screens/`.

Your Mission:
Follow the exact extraction blueprint in `c:\Users\moham\Desktop\masjed app\.agents\explorer_presentation\presentation_report.md`:

1. Deconstruct `lib/screens/mosque_admin_screen.dart` (3,432 LOC) into `lib/screens/admin/`:
   - `admin_sheikhs_tab.dart` (Tab 0: Sheikhs list & modal triggers)
   - `admin_halaqat_tab.dart` (Tab 1: Halaqat list & modal triggers)
   - `admin_students_tab.dart` (Tab 2: Students list, search, filter & modal triggers)
   - `admin_courses_tab.dart` (Tab 3: Intensive courses list & triggers)
   - `admin_course_form_dialog.dart` (Consolidated add/edit course dialog, <300 LOC)
   - `admin_trips_tab.dart` (Tab 4: Trips list & modal triggers)
   - `admin_tracks_tab.dart` (Tab 5: Recitation tracks list & modal triggers)
   - `admin_rewards_tab.dart` (Tab 6: Rewards list & modal triggers)
   - `admin_executive_overview_tab.dart` (Tab 7: Executive overview matrix)
   - `admin_events_tab.dart` (Tab 8: Community events list & modal triggers)
   - `admin_locked_view.dart` (Registration form and access code unlock)
   - `admin_header_banner.dart` (Top app bar, metrics, QR badge dialog buttons)
   - Refactor `lib/screens/mosque_admin_screen.dart` into a slim coordinator (~100-120 LOC) hosting `TabBarView`.

2. Deconstruct `lib/screens/sheikh_screen.dart` (2,756 LOC) into `lib/screens/sheikh/`:
   - `sheikh_attendance_tab.dart` (Tab 0: Attendance grid, date picker, points dialog)
   - `sheikh_memorization_tab.dart` (Tab 1: Memorization management tab)
   - `sheikh_quran_recitation_inputs.dart` (Quran Surah/Ayah selection & batch recording, <250 LOC)
   - `multi_surah_selector_dialog.dart` (Multi-Surah selector dialog, <100 LOC)
   - `sheikh_today_recitations_card.dart` (Today's recorded recitations list, <100 LOC)
   - `sheikh_curriculum_tracks_tab.dart` (Tab 2: Custom recitation tracks)
   - `sheikh_trips_tab.dart` (Tab 3: Trips management & attendance, <250 LOC)
   - `sheikh_trip_form_dialog.dart` (Trip creation/editing dialog, <250 LOC)
   - `sheikh_executive_overview_tab.dart` (Tab 4: Sheikh overview matrix)
   - `sheikh_students_tab.dart` (Tab 5: Students list & modal triggers)
   - `sheikh_messages_tab.dart` (Tab 6: Messaging & compose/reply dialogs)
   - `sheikh_locked_view.dart` (Sheikh login/access code view)
   - `sheikh_header_banner.dart` (Top header banner with actions)
   - Refactor `lib/screens/sheikh_screen.dart` into a slim coordinator (~100-120 LOC) hosting `TabBarView`.

3. Deconstruct `lib/screens/student_screen.dart` (1,680 LOC) into `lib/screens/student/`:
   - `student_progress_tab.dart` (Tab 0: Quran 30 Ajza tree & progress view)
   - `student_juz_modal.dart` (Juz details dialog)
   - `student_attendance_tab.dart` (Tab 1: Attendance history & commitment rate)
   - `student_trips_tab.dart` (Tab 2: Trips list & baggage requirements display)
   - `student_rewards_tab.dart` (Tab 3: Rewards catalog & claim voucher)
   - `student_multi_reward_claim_dialog.dart` (Multi-voucher claim dialog)
   - `student_points_tab.dart` (Tab 4: Points logs history)
   - `student_contact_tab.dart` (Tab 5: Contact sheikh / messages)
   - `student_rankings_tab.dart` (Tab 6: Leaderboard & competitions)
   - `student_locked_view.dart` (Student login/access code view)
   - `student_header_banner.dart` (Top header banner)
   - Refactor `lib/screens/student_screen.dart` into a slim coordinator (~100 LOC) hosting `TabBarView`.

4. STRICT LINE COUNT CONSTRAINT:
   Verify that EVERY single extracted file in `lib/screens/admin/`, `lib/screens/sheikh/`, `lib/screens/student/`, and the parent screens is strictly UNDER 500 lines of code!

5. Zero Regression Verification:
   Run in `c:\Users\moham\Desktop\masjed app\flutter_app`:
   - `flutter analyze` (must pass with 0 errors)
   - `flutter test` (must pass 100% of all 118+ tests with 0 failures)

6. Write your handoff report to `c:\Users\moham\Desktop\masjed app\.agents\worker_m3\handoff.md` with file list, line counts, and verification outputs.
7. Send a message to your parent when done.
