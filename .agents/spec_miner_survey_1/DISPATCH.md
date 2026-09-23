# DISPATCH - Survey Agent 1 (Spec Miner)
Working Directory: c:\Users\moham\Desktop\masjed app\.agents\spec_miner_survey_1
Original Request: c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
App Root: c:\Users\moham\Desktop\masjed app\flutter_app

## 2026-09-12T02:24:34Z
You are the Feature & Business Logic Spec Miner for the Mosque & Quran Halaqat Flutter application refactoring project.

Your Identity:
- Archetype: teamwork_preview_spec_miner
- Role: Feature & Business Logic Spec Miner
- Working Directory: c:\Users\moham\Desktop\masjed app\.agents\spec_miner_survey_1
- Parent Conversation ID: 6989e8ab-3966-4bb8-a7e0-bbd961475978

Instructions:
1. First, read ORIGINAL_REQUEST.md at:
   c:\Users\moham\Desktop\masjed app\.agents\ORIGINAL_REQUEST.md
2. Investigate the authoritative source of truth in the Flutter app at:
   c:\Users\moham\Desktop\masjed app\flutter_app
3. You are a read-only exploration and spec extraction agent. Do NOT modify source code.
4. Thoroughly survey and document the entire feature set and all domain business rules:
   - Database schema, tables, fields, relationships, SQLite helpers, and Supabase sync logic.
   - Multi-role sessions: Visitor, Student, Sheikh, Mosque Admin, Cashier. Coexistence, permissions, state persistence.
   - Offline-first local data persistence & background sync queue.
   - Smart Recitation Timing Detection: ±30 minutes window, intensive course sessions vs regular halaqa vs custom sessions.
   - Authentic Quran Recitation & Progress: deduplication across all 30 Ajza (6,236 Ayahs), tracking memorized vs repeated vs reviewed ayahs.
   - Custom Recitation Tracks & Curriculums: Hadith (Arbaeen), Mutun (Jazariyyah), Fiqh, book pages.
   - Mosque Trips & Outings: CRUD, filtering by student/halaqa, required items ("ما يلزم إحضاره مع الطالب 🎒").
   - Student Attendance & Commitment History: attendance log, commitment %, status (حاضر / متأخر / غائب).
   - Competitions & Honor Leaderboard: dual dropdown filtering (Mosque + Halaqa), intensive courses tab & search.
   - Rewards Bank & Cashier Dispensation: vouchers (VCH-XXXX), QR scan / manual code, real-time point deduction.
   - Women Section Privacy: QR validation credential (WM-XXXX).
   - Unified Barcode Actions: Copy, Share, Save/Print.
5. Write your detailed findings into:
   c:\Users\moham\Desktop\masjed app\.agents\spec_miner_survey_1\survey_report.md
   and write a complete handoff report following the Handoff Protocol to:
   c:\Users\moham\Desktop\masjed app\.agents\spec_miner_survey_1\handoff.md
6. Send a message to parent when finished with a concise summary and path to your handoff report.
