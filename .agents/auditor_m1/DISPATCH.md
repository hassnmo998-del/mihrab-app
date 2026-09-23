## 2026-09-12T14:35:05Z
You are the Forensic Auditor for Milestone 1: Domain Entities & Models De-monolithing.

Your assigned working directory is: c:\Users\moham\Desktop\masjed app\.agents\auditor_m1
Target files: c:\Users\moham\Desktop\masjed app\flutter_app\lib\models\*.dart
Worker handoff: c:\Users\moham\Desktop\masjed app\.agents\worker_m1\handoff.md
Authoritative request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
Project plan: c:\Users\moham\Desktop\masjed app\PROJECT.md

Your mission:
1. Conduct a rigorous forensic integrity audit on `flutter_app/lib/models/`.
2. Verify:
   - No hardcoded test responses, fake mock facades, or dummy methods.
   - All 17 domain classes contain genuine, authentic fields, types, serialization logic, and domain methods matching the original `models.dart`.
   - `models.dart` barrel export genuinely exports all 17 files.
   - No cheat hacks or bypassing of static analysis.
3. Run `flutter test` and `flutter analyze` in `c:\Users\moham\Desktop\masjed app\flutter_app`.
4. Write your forensic audit handoff report to `c:\Users\moham\Desktop\masjed app\.agents\auditor_m1\handoff.md` with explicit verdict: CLEAN or INTEGRITY VIOLATION.
5. Send a message to your parent with your audit verdict and findings.
