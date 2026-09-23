# Original User Request

## 2026-09-12T02:22:10Z

Refactor the Mosque & Quran Halaqat Flutter application to a production-grade Clean Architecture with BLoC state management and get_it dependency injection, retaining 100% of existing features, while centralizing all design tokens and theme styles into a single unified theme engine.

Working directory: c:\Users\moham\Desktop\masjed app\flutter_app
Integrity mode: development

## Requirements

### R1. Clean Architecture & BLoC State Management with get_it
Restructure the application into modular Clean Architecture layers:
- **Domain Layer**: Pure Dart entities, use cases, and abstract repository contracts with zero Flutter UI or external database dependencies.
- **Data Layer**: Data sources (SQLite local persistence + local SharedPreferences + Supabase background sync queue), data transfer objects / models, and concrete repository implementations.
- **Presentation Layer**: BLoCs / Cubits (`flutter_bloc`), reactive state consumers/builders, and screen components.
- **Dependency Injection**: Service locator configured via `get_it` registering repositories, data sources, use cases, and BLoCs for seamless decoupling and testability.

### R2. 100% Feature Parity & Zero Data Loss
Preserve every existing feature, calculation logic, and business rule without omitting any capability:
- **Multi-role persistent sessions**: (Visitor, Student, Sheikh, Mosque Admin, Cashier) coexisting simultaneously without automatic logout.
- **Offline-first local data persistence**: Instant UI responses with silent background Supabase synchronization queue.
- **Smart Recitation Timing Detection**: (±30 minutes window) intelligently identifying intensive course sessions, regular halaqa sessions, and custom timing sessions.
- **Authentic Quran Recitation & Progress**: Deduplication across all 30 Ajza (6,236 Ayahs) preventing artificial inflation of memorized Ayahs.
- **Custom Recitation Tracks & Curriculums**: Flexible support for Hadith (e.g. Arbaeen), Mutun (e.g. Jazariyyah), Fiqh, and book pages with authentic progress tracking.
- **Mosque Trips & Outings**: Full CRUD, target student/halaqa filtering, and prominent required items display ("ما يلزم إحضاره مع الطالب 🎒").
- **Student Attendance & Commitment History**: Dedicated attendance log with commitment percentage and status breakdown (حاضر / متأخر / غائب).
- **Competitions & Honor Leaderboard**: Dual dropdown filtering (Mosque + Halaqa) and dedicated Intensive Courses showcase tab with search by course name.
- **Rewards Bank & Cashier Dispensation**: Reward vouchers (`VCH-XXXX`), QR scanning/manual code redemption, and real-time point deduction.
- **Women Section Privacy**: Protected by QR validation credential (`WM-XXXX`).
- **Unified Barcode Actions**: Consistent 3 actions (Copy, Share, Save/Print) across all QR and barcode dialogs.

### R3. Centralized Unified Design System & Theme Engine
Consolidate all design styling rules into a centralized theme system (`AppTheme`, `ThemeData`, `ThemeExtension`, and Design Tokens):
- **Typography**: Unified fonts, text scales, weights, and letter spacing across all headers, subtitles, and body text.
- **Components Theme**: Universal styles for Dialogs, Buttons (Elevated, Outlined, Text), Dropdowns, TextFields, Cards, Tables, Badges, and Chips.
- **Shapes & Radiuses**: Global radius tokens (e.g. `AppRadius.sm`, `AppRadius.md`, `AppRadius.lg`) eliminating scattered hardcoded `BorderRadius.circular`.
- **Colors & Palettes**: Light & Dark mode tokens centrally managed so any future visual redesign can be achieved by simply updating theme tokens in one central location without modifying individual screen files.
- **Preserve Existing Aesthetic**: Retain the existing emerald green, gold, and dark/light visual style during this refactor; unify its implementation without changing the look.

## Acceptance Criteria

### Architectural Integrity
- [ ] Codebase is cleanly separated into `core/`, `features/`, `domain/`, `data/`, and `presentation/`.
- [ ] UI widgets contain zero direct database queries or state mutation logic; all state flow is managed via BLoC events/states.
- [ ] Dependency injection is cleanly handled via `get_it`.
- [ ] Easy extensibility: new features can be added in an isolated feature directory without touching unrelated screens.

### Feature Completeness & Parity
- [ ] All 12+ existing unit tests in `test/` pass without regressions.
- [ ] New BLoC and UseCase tests are added to verify state handling.
- [ ] Every user workflow across all roles (Admin, Sheikh, Student, Cashier, Visitor) functions identically to current behavior.

### Design System Centralization
- [ ] A centralized design token / theme configuration file controls all UI appearances.
- [ ] Changing a central token (e.g., primary color, border radius) propagates across the entire app without requiring individual screen edits.

### Code Quality & Build Verification
- [ ] `flutter analyze` passes with 0 errors and 0 warnings.
- [ ] `flutter test` completes with 100% passing tests.

## 2026-09-12T13:47:05Z

Refactor the Flutter Mosque Application into a clean, highly modular, feature-based Clean Architecture ("زي الكتاب ما بيقول"), breaking down monolithic files into decoupled components so that adding or modifying any feature, theme, or style is effortless and isolated, with strict zero-breakage enforcement.

Working directory: c:\Users\moham\Desktop\masjed app\flutter_app
Integrity mode: development

## Verification Resources
- Existing automated test suite: `test/` (38 passing tests verifying sessions, multi-role access, Quran progress calculations, cashier rewards, and presentation blocs).
- Flutter CLI verification tools: `flutter test` and `flutter analyze`.

## Requirements

### R1. De-monolithing & Architectural Separation
Decompose the monolithic files into decoupled, maintainable modules:
- Split the monolithic models file (`models/models.dart`, 1,264 lines) into independent domain entities/models, while maintaining backwards-compatible barrel export.
- Break down the massive presentation screen monoliths (`mosque_admin_screen.dart` [3,432 lines], `sheikh_screen.dart` [2,656 lines], `student_screen.dart` [1,615 lines]) by extracting all tab views, sub-components, and dialogs into dedicated, focused widget files.
- Modularize the monolithic data and service layer (`data_service.dart`, 2,280 lines) into dedicated data sources (remote Supabase, local cache) and proper repository contracts.

### R2. Extensible Theming & Feature Modularization
Ensure that every feature, tab, theme mode, and visual style is isolated in a feature-first structure so that new capabilities or UI customizations can be added without modifying unrelated files.

### R3. Zero Functional Regression & Continuous Verification
Ensure 100% preservation of all existing application features, roles (Visitor, Admin, Sheikh, Student, Cashier), authentication logic, offline sync, and business calculations.

## Acceptance Criteria

### Quality & Test Suite Gate
- [ ] 100% of existing tests pass (`flutter test`) with zero failures.
- [ ] `flutter analyze` runs without breaking compilation errors.
- [ ] No single presentation tab or component file exceeds 500 lines of code.

### Architectural Delivery
- [ ] The 9 tabs of Mosque Admin, 7 tabs of Sheikh, and 7 tabs of Student operate from distinct, modular widget files.
- [ ] All 17 domain entities are separated into dedicated model files.
- [ ] Adding a new tab or modifying existing styling can be done independently within its own module.
