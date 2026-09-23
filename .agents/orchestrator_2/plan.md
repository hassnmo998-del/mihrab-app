# Plan: Mosque App Clean Architecture & De-monolithing

## Mission
Refactor the Mosque & Quran Halaqat Flutter application into a modular, feature-first Clean Architecture, de-monolithing massive files while maintaining 100% functional parity, zero test regressions (38+ tests passing), and zero breaking compilation errors.

---

## Phase 0: Survey & Scope Mapping (Current)
Dispatch 3 specialized explorers in parallel:
1. **Spec Miner (Models & Domain Entities)**:
   - Target: `flutter_app/lib/models/models.dart` (1,264 lines).
   - Enumerate all 17 domain entities, their fields, constructors, JSON/Supabase serialization, and inter-model dependencies.
   - Propose 17 dedicated model files and a backwards-compatible `models.dart` barrel export.
2. **Explorer 1 (Data & Service Layer)**:
   - Target: `flutter_app/lib/services/data_service.dart` (2,280 lines) and related services.
   - Map all Supabase remote queries, local cache mechanisms, and business operations.
   - Design repository interfaces and modular data sources.
3. **Explorer 2 (Presentation Screens Monoliths)**:
   - Targets: `mosque_admin_screen.dart` (3,432 lines, 9 tabs), `sheikh_screen.dart` (2,656 lines, 7 tabs), `student_screen.dart` (1,615 lines, 7 tabs).
   - Map each tab, its sub-components, dialogs, and state dependencies.
   - Define extraction blueprint ensuring all extracted files are strictly under 500 lines.

---

## Phase 1: Milestone 1 — Domain Entities & Models De-monolithing
- Worker creates 17 individual domain entity files under `lib/models/` (or domain model structure).
- Backwards-compatible barrel export in `lib/models/models.dart` so all existing imports throughout the app continue to work without breaking.
- Verification: Reviewer + Challenger run `flutter test` (all 38+ tests must pass) and verify model integrity.
- Forensic Auditor audit.

---

## Phase 2: Milestone 2 — Data & Service Layer Modularization
- Worker extracts `data_service.dart` into modular data sources (remote Supabase, local cache) and repository implementations.
- Preserve all multi-role authentication, offline queue, smart timing detection, deduplication, trips, attendance, and cashier rewards logic.
- Verification: Reviewer + Challenger test all database and business calculation paths with `flutter test`.

---

## Phase 3: Milestone 3 — Presentation Screen De-monolithing
- Worker decomposes:
  - Mosque Admin 9 tabs into dedicated modular tab files (<500 lines each).
  - Sheikh 7 tabs into dedicated modular tab files (<500 lines each).
  - Student 7 tabs into dedicated modular tab files (<500 lines each).
  - Common dialogs and sub-components into modular widgets (<500 lines each).
- Verification: Reviewer + Challenger verify widget hierarchy, state injection, line counts (<500 lines check).

---

## Phase 4: Verification & Test Suite Gate
- Run `flutter test` (must pass 100% of tests with 0 failures).
- Run `flutter analyze` (must pass with 0 breaking errors).
- Verify file line count limits (<500 LOC per presentation tab/component).
- Forensic Auditor full audit pass.

---

## Phase 5: Synthesis & Completion Delivery
- Compile final report, update documentation, and report back to caller/user.
