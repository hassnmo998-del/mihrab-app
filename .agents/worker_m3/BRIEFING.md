# BRIEFING — 2026-09-12T17:04:24Z

## Mission
Deconstruct the 3 presentation screen monoliths (`mosque_admin_screen.dart`, `sheikh_screen.dart`, `student_screen.dart`) into granular modular sub-widgets under `lib/screens/admin/`, `lib/screens/sheikh/`, and `lib/screens/student/`, ensuring every single file is strictly under 500 LOC and all 118+ tests and analyze pass with 0 errors.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: c:\Users\moham\Desktop\masjed app\.agents\worker_m3
- Original parent: 39faac12-983d-490f-8632-0f5af6a65a5d
- Milestone: Milestone 3 - Presentation Screen Monolith Deconstruction

## 🔒 Key Constraints
- Exclusive write ownership: `lib/screens/` under `flutter_app`.
- Follow exact blueprint from `explorer_presentation/presentation_report.md`.
- STRICT LINE COUNT: EVERY single extracted file and parent screen must be strictly UNDER 500 lines of code.
- Zero regressions: `flutter analyze` must pass with 0 errors; `flutter test` must pass 100% of tests (118+ tests).
- Genuine implementations, no cheating or facades.

## Current Parent
- Conversation ID: 39faac12-983d-490f-8632-0f5af6a65a5d
- Updated: not yet

## Task Summary
- **What to build**: Deconstruction of 3 presentation screens:
  1. `mosque_admin_screen.dart` -> `lib/screens/admin/` (12 components + slim coordinator)
  2. `sheikh_screen.dart` -> `lib/screens/sheikh/` (13 components + slim coordinator)
  3. `student_screen.dart` -> `lib/screens/student/` (11 components + slim coordinator)
- **Success criteria**:
  - All files strictly < 500 LOC.
  - Zero analyzer errors.
  - All 118+ tests pass.
- **Interface contracts**: `PROJECT.md`, `presentation_report.md`
- **Code layout**: `flutter_app/lib/screens/{admin,sheikh,student}/`

## Change Tracker
- **Files modified**: None yet
- **Build status**: Untested
- **Pending issues**: None

## Quality Status
- **Build/test result**: Untested
- **Lint status**: Untested
- **Tests added/modified**: TBD

## Loaded Skills
- None required

## Key Decisions Made
- Follow blueprint specifications precisely.

## Artifact Index
- `.agents/worker_m3/DISPATCH.md` — Assignment dispatch
- `.agents/worker_m3/progress.md` — Progress tracker
- `.agents/worker_m3/handoff.md` — Final handoff report
