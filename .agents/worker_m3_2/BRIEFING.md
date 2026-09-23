# BRIEFING — 2026-09-12T20:42:00Z

## Mission
Complete Milestone 3: Mosque Admin Screen Deconstruction into modular tabs and dialogs under `lib/screens/admin/`, verify strictly <500 LOC per file across `lib/screens/`, verify `flutter analyze` clean and all tests passing.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: c:\Users\moham\Desktop\masjed app\.agents\worker_m3_2
- Original parent: a13611b8-8fab-4d74-93fc-ece4de5ce505
- Milestone: Milestone 3 Presentation Screen Monolith Deconstruction

## 🔒 Key Constraints
- Strictly UNDER 500 lines of code for EVERY file under `lib/screens/`.
- Zero functional regression: all existing features, dialogs, QR integrations, snackbars, and logic preserved.
- Pass `flutter analyze` with 0 errors/warnings.
- Pass `flutter test` with 100% pass rate.
- Exclusive write ownership of `lib/screens/` and `.agents/worker_m3_2/`.

## Current Parent
- Conversation ID: a13611b8-8fab-4d74-93fc-ece4de5ce505
- Updated: 2026-09-12T20:42:00Z

## Task Summary
- **What to build**:
  - `lib/screens/admin/tabs/admin_halaqat_tab.dart` (Tab 1: Halaqat list, add/edit/delete modals)
  - `lib/screens/admin/tabs/admin_students_tab.dart` (Tab 2: Students list, search, filter, modals)
  - `lib/screens/admin/tabs/admin_courses_tab.dart` (Tab 3: Intensive courses list & triggers)
  - `lib/screens/admin/dialogs/admin_course_form_dialog.dart` (Consolidated add/edit course dialog)
  - `lib/screens/admin/tabs/admin_trips_tab.dart` (Tab 4: Trips list & modals)
  - `lib/screens/admin/tabs/admin_tracks_tab.dart` (Tab 5: Recitation tracks list & modals)
  - `lib/screens/admin/tabs/admin_rewards_tab.dart` (Tab 6: Rewards list & modals)
  - `lib/screens/admin/tabs/admin_overview_tab.dart` (Tab 7: Executive overview matrix)
  - `lib/screens/admin/tabs/admin_events_tab.dart` (Tab 8: Community events list & modals)
  - Slim coordinator `lib/screens/mosque_admin_screen.dart` (~100-140 LOC)
- **Success criteria**:
  - All files in `lib/screens/` < 500 LOC
  - `flutter analyze` clean
  - `flutter test` 100% pass
- **Interface contracts**: PROJECT.md, presentation_report.md
- **Code layout**: `lib/screens/admin/{tabs,dialogs,widgets}/`

## Key Decisions Made
- Reusing already completed `student_screen.dart` and `sheikh_screen.dart` deconstructions from predecessor.
- Utilizing already created `admin_header_banner.dart`, `admin_locked_view.dart`, `admin_sheikhs_tab.dart`.
- Extracting remaining Mosque Admin tabs and dialogs cleanly.

## Change Tracker
- **Files modified**: TBD
- **Build status**: Pending
- **Pending issues**: None

## Quality Status
- **Build/test result**: Pending verification
- **Lint status**: Pending
- **Tests added/modified**: 0
