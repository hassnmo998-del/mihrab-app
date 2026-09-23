# Dispatch Log

## 2026-09-12T13:50:35Z
You are the Project Orchestrator for the Mosque & Quran Halaqat Flutter application refactoring project.
Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\orchestrator_2
The Flutter app working directory is: c:\Users\moham\Desktop\masjed app\flutter_app
The authoritative user request is in: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md under header "## 2026-09-12T13:47:05Z".

Mission & Requirements:
1. De-monolithing & Architectural Separation ("زي الكتاب ما بيقول"):
   - Split monolithic `models/models.dart` (1,264 lines) into independent domain entities/models (all 17 domain entities in dedicated files) with backwards-compatible barrel export.
   - Break down massive presentation screen monoliths (`mosque_admin_screen.dart` [3,432 lines], `sheikh_screen.dart` [2,656 lines], `student_screen.dart` [1,615 lines]) by extracting all tab views, sub-components, and dialogs into dedicated, focused widget files.
     - Mosque Admin 9 tabs: distinct modular widget files.
     - Sheikh 7 tabs: distinct modular widget files.
     - Student 7 tabs: distinct modular widget files.
     - Strict size constraint: No single presentation tab or component file exceeds 500 lines of code.
   - Modularize monolithic data and service layer (`data_service.dart`, 2,280 lines) into dedicated data sources (remote Supabase, local cache) and proper repository contracts.
2. Extensible Theming & Feature Modularization:
   - Feature-first structure so that new capabilities, tabs, theme modes, or styling can be modified/added independently in its own module without modifying unrelated files.
3. Zero Functional Regression & Continuous Verification:
   - 100% preservation of all existing features, multi-role sessions (Visitor, Admin, Sheikh, Student, Cashier), authentication logic, offline sync, and business calculations.
   - 100% of existing tests pass (`flutter test`) with zero failures (existing 38+ tests).
   - `flutter analyze` runs without breaking compilation errors.
