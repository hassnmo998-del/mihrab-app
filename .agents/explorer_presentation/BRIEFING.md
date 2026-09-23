# BRIEFING — 2026-09-12T14:14:15Z

## Mission
Investigate the presentation screen monoliths (`mosque_admin_screen.dart`, `sheikh_screen.dart`, `student_screen.dart`) and formulate a zero-regression, modular tab-extraction blueprint ensuring all files are under 500 lines.

## 🔒 My Identity
- Archetype: explorer
- Roles: Presentation Layer Investigation, Component Mapping, Extraction Blueprinting
- Working directory: c:\Users\moham\Desktop\masjed app\.agents\explorer_presentation
- Original parent: 39faac12-983d-490f-8632-0f5af6a65a5d
- Milestone: presentation_exploration

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Target strictly under 500 lines of code per extracted tab/subcomponent file
- Zero functional regression (state, callbacks, controllers, dialogs preserved)
- Map all 9 tabs of Mosque Admin, 7 tabs of Sheikh, 7 tabs of Student screen

## Current Parent
- Conversation ID: 39faac12-983d-490f-8632-0f5af6a65a5d
- Updated: 2026-09-12T14:11:48Z

## Investigation State
- **Explored paths**: `flutter_app/lib/screens/mosque_admin_screen.dart`, `sheikh_screen.dart`, `student_screen.dart`, `widgets/qr_dialogs.dart`, `widgets/printable_badge_dialog.dart`, `widgets/code_scanner_dialog.dart`, `presentation/widgets/`.
- **Key findings**:
  1. All 23 tabs mapped across 3 screens (Admin 9, Sheikh 7, Student 7).
  2. Tab states are local and decoupled; no cross-tab mutable dependencies exist.
  3. Admin Intensive Courses (~800 lines) and Sheikh Memorization (~879 lines) must decouple dialogs/inputs to satisfy the < 500 lines limit.
  4. 30 modular files designed, all strictly between 35 and 450 lines.
  5. Automated test baseline: 38/38 tests passing.
- **Unexplored areas**: None for presentation exploration.

## Key Decisions Made
- Deconstruct monoliths into `lib/screens/admin/`, `lib/screens/sheikh/`, and `lib/screens/student/` under `tabs/`, `widgets/`, and `dialogs/`.
- Decouple Course dialogs into `admin_course_form_dialog.dart` and Quran inputs into `sheikh_quran_recitation_inputs.dart` to strictly meet the under-500-lines constraint.

## Artifact Index
- DISPATCH.md — record of task assignment & updates
- progress.md — liveness heartbeat
- presentation_report.md — comprehensive analysis and extraction blueprint
- handoff.md — 5-component handoff report
