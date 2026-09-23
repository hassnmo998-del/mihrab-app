# Presentation Layer Monolith Deconstruction Blueprint

**Author**: Presentation Layer Explorer  
**Date**: 2026-09-12  
**Target Files**:
- `lib/screens/mosque_admin_screen.dart` (3,432 lines, 9 tabs)
- `lib/screens/sheikh_screen.dart` (2,756 lines, 7 tabs)
- `lib/screens/student_screen.dart` (1,680 lines, 7 tabs)
**Total Monolithic Presentation Code**: 7,868 lines

---

## 1. Executive Summary & Objective

The Flutter Mosque Application currently houses the core workflows for three primary administrative and user roles inside three massive monolithic screen files totaling 7,868 lines of code. This architecture causes:
1. High cognitive load and editing conflict risk.
2. Inefficient Flutter widget rebuilds across unrelated tabs.
3. Code duplication in dialogs, form handling, and QR badge rendering.

This blueprint establishes an exhaustive, zero-regression architectural deconstruction plan. Each tab, locked screen, and heavy modal dialog is mapped and divided into dedicated modular components where **every single extracted file is strictly UNDER 500 lines of code** (ranging between 35 and 450 lines), while reducing the parent screen files from thousands of lines down to ~100 lines each.

---

## 2. Comprehensive Monolith Mapping

### 2.1. Mosque Admin Screen (`mosque_admin_screen.dart`) — 3,432 Lines, 9 Tabs

#### Architecture Overview
- **Session & Security**: Checks `DataService.getSessionForRole('mosque_admin')` or `widget.session`. If null or unauthorized, displays `_buildLockedView`.
- **Hero Header**: Official mosque banner with mosque name, city, official accreditation chip, and action buttons for Mosque Admin Official Badge (`PrintableBadgeDialog`), Women's Section Barcode (`WM-XXXX`), and Cashier Dispensation Barcode.
- **Metrics Summary Row**: 8 real-time metric cards (المحفظون, الحلقات, الطلاب, الدورات, الرحلات, المناهج, الجوائز, الفعاليات).
- **TabController**: Length 9, scrollable `TabBar`.

#### Tab Inventory & Line Mapping

| Tab Index | Tab Title | Method / Section | Line Range | Original Lines | State Variables & Controllers | Modals / Dialogs Invoked | Proposed Extracted Target File | Extracted Lines |
|---|---|---|---|---|---|---|---|---|
| **Tab 0** | المشايخ والمعلمات | `_buildSheikhsTab` | 488–560, 796–880 | ~160 | None at screen level; form controllers in modals | `_showAddSheikhModal`, `_showEditSheikhModal`, `_confirmDeleteSheikh`, `PrintableBadgeDialog`, `SectionQrCodeDialog` | `lib/screens/admin/tabs/admin_sheikhs_tab.dart` | ~170 |
| **Tab 1** | الحلقات القرآنية | `_buildHalaqatTab` | 561–619, 881–1170 | ~350 | None at screen level; schedule & capacity in modals | `_showAddHalaqaModal`, `_showEditHalaqaModal`, `_confirmDeleteHalaqa` | `lib/screens/admin/tabs/admin_halaqat_tab.dart` | ~350 |
| **Tab 2** | إدارة الطلاب | `_buildStudentsTab` | 620–737, 1171–1306 | ~255 | `_studentSearchQuery`, `_selectedHalaqaFilter` | `_showAddStudentModal`, `_showEditStudentModal`, `_confirmDeleteStudent`, `PrintableBadgeDialog`, `SectionQrCodeDialog` | `lib/screens/admin/tabs/admin_students_tab.dart` | ~260 |
| **Tab 3** | الدورات الاستثنائية 🎓 | `_buildIntensiveCoursesTab` | 1653–2452 | ~800 | None at screen level; course form controllers | `_showAddCourseModal` (287 lines), `_showEditCourseModal` (292 lines), `_confirmDeleteCourse` | `lib/screens/admin/tabs/admin_courses_tab.dart` + `admin_course_form_dialog.dart` | Tab: ~210<br>Dialog: ~280 |
| **Tab 4** | رحلات وأنشطة المسجد 🚌 | `_buildTripsTab` | 2453–2856 | ~404 | None at screen level; trip form controllers | `_showAddTripModal`, `_showEditTripModal`, `_confirmDeleteTrip` | `lib/screens/admin/tabs/admin_trips_tab.dart` | ~400 |
| **Tab 5** | المناهج والمتون 📚 | `_buildTracksTab` | 2857–3154 | ~298 | None at screen level; track form controllers | `_showAddTrackModal`, `_showEditTrackModal`, `_confirmDeleteTrack` | `lib/screens/admin/tabs/admin_tracks_tab.dart` | ~300 |
| **Tab 6** | بنك الجوائز 🎁 | `_buildRewardsTab` | 3155–3432 | ~278 | None at screen level; reward form controllers | `_showAddRewardModal`, `_showEditRewardModal`, `_confirmDeleteReward` | `lib/screens/admin/tabs/admin_rewards_tab.dart` | ~280 |
| **Tab 7** | لوحة المتابعة الشاملة 📊 | `_buildExecutiveOverviewTab` | 1472–1652 | ~181 | `_overviewSearch`, `_overviewHalaqaFilter`, `_overviewDate` | DatePicker, `UnifiedTable` | `lib/screens/admin/tabs/admin_overview_tab.dart` | ~185 |
| **Tab 8** | الفعاليات ومجالس العلم | `_buildEventsTab` | 738–795, 1307–1471 | ~223 | None at screen level; event form controllers | `_showAddEventModal`, `_showEditEventModal` | `lib/screens/admin/tabs/admin_events_tab.dart` | ~225 |

#### Auxiliary Components in Mosque Admin
- `_buildLockedView` (lines 270–470, ~200 lines): Mosque registration form with city picker and mosque access code validation. → Extract to `lib/screens/admin/widgets/admin_locked_view.dart`.
- `_buildMetricCard` & Hero Header Banner (lines 84–222, ~145 lines): → Extract to `lib/screens/admin/widgets/admin_header_banner.dart`.

---

### 2.2. Sheikh Screen (`sheikh_screen.dart`) — 2,756 Lines, 7 Tabs

#### Architecture Overview
- **Session & Security**: Verifies `DataService.getSessionForRole('sheikh')` or `widget.session`. Displays `_buildLockedView` if unauthenticated.
- **Hero Header**: Sheikh name, mosque association, halaqa count, student count, and official Sheikh Badge QR button (`PrintableBadgeDialog`).
- **TabController**: Length 7, scrollable `TabBar`.

#### Tab Inventory & Line Mapping

| Tab Index | Tab Title | Method / Section | Line Range | Original Lines | State Variables & Controllers | Modals / Dialogs Invoked | Proposed Extracted Target File | Extracted Lines |
|---|---|---|---|---|---|---|---|---|
| **Tab 0** | رصد الحضور اليومي | `_buildAttendanceTab` | 333–519, 2527–2601 | ~262 | `_attendanceDate`, `_enableAttendancePoints`, `_presentPoints`, `_latePoints`, `_absentPoints` | DatePicker, `CodeScannerDialog`, `_showAttendancePointsDialog` | `lib/screens/sheikh/tabs/sheikh_attendance_tab.dart` | ~270 |
| **Tab 1** | رصد التسميع والقرآن | `_buildMemorizationTab` | 520–593, 594–1398 | ~879 | `_selectedStudentId`, `_selectedCourseId`, `_recitationMode`, `_selectedSurahs`, `_singleSurah`, `_fromAyahCtrl`, `_toAyahCtrl`, `_selectedAjza`, `_memPointsCtrl`, `_memNotesCtrl`, `_sessionType`, `_memCountsTowardsStatistics`, track controllers | `_showMultiSurahSelectorDialog`, Smart Timing Detection banner, Today's Recitations list | `lib/screens/sheikh/tabs/sheikh_memorization_tab.dart` + subcomponents (inputs, dialog, card) | Tab: ~320<br>Inputs: ~240<br>Dialog: ~75<br>Card: ~60 |
| **Tab 2** | المناهج والمتون 📚 | `_buildCurriculumTracksTab` | 1402–1725 | ~324 | None at screen level; track form controllers | `_showAddSheikhTrackModal`, `_confirmDeleteSheikhTrack` | `lib/screens/sheikh/tabs/sheikh_tracks_tab.dart` | ~330 |
| **Tab 3** | رحلات وأنشطة الحلقة 🚌 | `_buildTripsTab` | 1726–2167 | ~442 | None at screen level; trip form controllers | `_showTripDialog` (add & edit) | `lib/screens/sheikh/tabs/sheikh_trips_tab.dart` | ~440 |
| **Tab 4** | لوحة المتابعة الشاملة 📊 | `_buildExecutiveOverviewTab` | 2602–2656 | ~55 | `_overviewSearch`, `_overviewHalaqaFilter`, `_overviewDate` | DatePicker, `UnifiedTable` | `lib/screens/sheikh/tabs/sheikh_overview_tab.dart` | ~60 |
| **Tab 5** | طلاب الحلقة والـ QR | `_buildStudentsTab` | 2168–2259, 2335–2436 | ~194 | None at screen level; student form controllers | `_showAddStudentModal`, `_showEditStudentModal`, `PrintableBadgeDialog`, `SectionQrCodeDialog` | `lib/screens/sheikh/tabs/sheikh_students_tab.dart` | ~200 |
| **Tab 6** | رسائل وتواصل الأهل | `_buildMessagesTab` | 2260–2334, 2437–2526 | ~165 | `_replyCtrl` | `_showComposeMessageDialog`, `_showReplyDialog` | `lib/screens/sheikh/tabs/sheikh_messages_tab.dart` | ~170 |

#### Auxiliary Components in Sheikh Screen
- `_buildLockedView` (lines 277–332, ~56 lines): Sheikh access code entry and scanner. → Extract to `lib/screens/sheikh/widgets/sheikh_locked_view.dart`.
- Hero Header Banner (lines 116–248, ~133 lines): → Extract to `lib/screens/sheikh/widgets/sheikh_header_banner.dart`.

---

### 2.3. Student Screen (`student_screen.dart`) — 1,680 Lines, 7 Tabs

#### Architecture Overview
- **Session & Security**: Verifies `DataService.getSessionForRole('student')` or `widget.session`. Displays `_buildLockedView` if unauthenticated.
- **Hero Header**: Student name, halaqa name, supervising sheikh name, points badge, and student official QR badge (`PrintableBadgeDialog`).
- **TabController**: Length 7, scrollable `TabBar`.

#### Tab Inventory & Line Mapping

| Tab Index | Tab Title | Method / Section | Line Range | Original Lines | State Variables & Controllers | Modals / Dialogs Invoked | Proposed Extracted Target File | Extracted Lines |
|---|---|---|---|---|---|---|---|---|
| **Tab 0** | تقدم حفظ القرآن والمناهج | `_buildProgressTab` | 324–712, 1057–1108 | ~441 | None at screen level | `_showJuzDetailsModal` (52 lines), Quran circular progress, 30 Ajza cards, Custom Tracks progress | `lib/screens/student/tabs/student_progress_tab.dart` + `student_juz_modal.dart` | Tab: ~390<br>Modal: ~55 |
| **Tab 1** | سجل الحضور والالتزام 📅 | `_buildAttendanceTab` | 713–884 | ~172 | None at screen level | Commitment percentage card, breakdown chips, log table | `lib/screens/student/tabs/student_attendance_tab.dart` | ~175 |
| **Tab 2** | رحلاتي وأنشطتي 🚌 | `_buildStudentTripsTab` | 885–1056 | ~172 | None at screen level | Target halaqa filtering, required items card ("ما يلزم إحضاره مع الطالب 🎒") | `lib/screens/student/tabs/student_trips_tab.dart` | ~175 |
| **Tab 3** | متجر الجوائز 🎁 | `_buildRewardsTab` | 1109–1490 | ~382 | None at screen level | `_showMultiRewardClaimDialog`, `RewardVoucherQrDialog` (`VCH-XXXX`) | `lib/screens/student/tabs/student_rewards_tab.dart` | ~385 |
| **Tab 4** | سجل النقاط الشفاف | `_buildPointsTab` | 1491–1518 | ~28 | None at screen level | Points ledger table | `lib/screens/student/tabs/student_points_tab.dart` | ~35 |
| **Tab 5** | تواصل مع الشيخ | `_buildContactTab` | 39–60, 1519–1636 | ~140 | `_msgController`, `_sendMessageToSheikh` | Chat list, inquiry input field | `lib/screens/student/tabs/student_contact_tab.dart` | ~145 |
| **Tab 6** | ترتيب الطالب | `_buildRankingsTab` | 1637–1714 | ~78 | None at screen level | Mosque & Halaqa leaderboards badges | `lib/screens/student/tabs/student_rankings_tab.dart` | ~85 |

#### Auxiliary Components in Student Screen
- `_buildLockedView` (lines 267–323, ~57 lines): Student code input and QR scanner. → Extract to `lib/screens/student/widgets/student_locked_view.dart`.
- Hero Header Banner (lines 100–238, ~139 lines): → Extract to `lib/screens/student/widgets/student_header_banner.dart`.

---

## 3. Shared Dialogs, QR/Barcode Actions & Common Widgets

### 3.1. Unified Barcode Actions Row (`UnifiedQrActionsRow`)
All QR and barcode dialogs across the platform rely on a consistent 3-action row:
1. **Copy (`نسخ`)**: Uses `Clipboard.setData(ClipboardData(text: code))` with an emerald floating `SnackBar`.
2. **Share (`مشاركة`)**: Invokes `Share.share(...)` via `share_plus` with formatted text containing code, title, and instructions.
3. **Save/Print (`حفظ/طباعة`)**: Triggers either high-resolution print hook or provides visual confirmation for screenshot/export.

### 3.2. Dialog Matrix

| Dialog Component | Source Path | Consumers | Unified Actions Supported | Notes |
|---|---|---|---|---|
| **PrintableBadgeDialog** | `lib/widgets/printable_badge_dialog.dart` | Admin, Sheikh, Student, Cashier | Copy, WhatsApp Share, Print | WhatsApp green branded badge with live QR, student/sheikh/admin credentials. |
| **SectionQrCodeDialog** | `lib/widgets/qr_dialogs.dart` | Admin, Sheikh | Copy, Share, Save/Print | Used for Women's section (`WM-XXXX`), Cashier unlock, and Sheikh/Student sharing. |
| **RewardVoucherQrDialog** | `lib/widgets/qr_dialogs.dart` | Student, Cashier | Copy, Share, Save/Print | Renders claimed voucher QR (`VCH-XXXX`), reward title, and spent points for cashier redemption. |
| **UniversalQrScannerDialog** | `lib/widgets/qr_dialogs.dart` | Global scanner | Detect, Manual Input fallback | Camera QR scanning with manual code entry fallback. |
| **CodeScannerDialog** | `lib/widgets/code_scanner_dialog.dart` | Locked screens, Sheikh attendance | 2 Tabs (Camera / Manual Code) | Verifies access code against `DataService.verifyCode()`. |

### 3.3. Reusable Presentation Widgets (`lib/presentation/widgets/`)
- `UnifiedCard`: Centralized card container obeying theme radius tokens (`AppRadius`).
- `UnifiedBadge`: Standard status chips (`حاضر`, `متأخر`, `غائب`, `معتمد`).
- `UnifiedTable`: Structured data table used in executive oversight tabs across Admin and Sheikh roles.
- `UnifiedDialog`: Modal wrapper guaranteeing consistent header, body styling, and dismiss actions.

---

## 4. Extraction Blueprint & File System Architecture

### 4.1. Directory Structure

```
flutter_app/lib/
├── screens/
│   ├── mosque_admin_screen.dart        # Refactored parent screen (~120 lines)
│   ├── sheikh_screen.dart              # Refactored parent screen (~110 lines)
│   ├── student_screen.dart             # Refactored parent screen (~100 lines)
│   │
│   ├── admin/
│   │   ├── widgets/
│   │   │   ├── admin_header_banner.dart        (~145 lines)
│   │   │   └── admin_locked_view.dart          (~200 lines)
│   │   ├── dialogs/
│   │   │   └── admin_course_form_dialog.dart   (~280 lines)
│   │   └── tabs/
│   │       ├── admin_sheikhs_tab.dart          (~170 lines)
│   │       ├── admin_halaqat_tab.dart          (~350 lines)
│   │       ├── admin_students_tab.dart         (~260 lines)
│   │       ├── admin_courses_tab.dart          (~210 lines)
│   │       ├── admin_trips_tab.dart            (~400 lines)
│   │       ├── admin_tracks_tab.dart           (~300 lines)
│   │       ├── admin_rewards_tab.dart          (~280 lines)
│   │       ├── admin_overview_tab.dart         (~185 lines)
│   │       └── admin_events_tab.dart           (~225 lines)
│   │
│   ├── sheikh/
│   │   ├── widgets/
│   │   │   ├── sheikh_header_banner.dart       (~135 lines)
│   │   │   ├── sheikh_locked_view.dart         (~60 lines)
│   │   │   ├── sheikh_quran_recitation_inputs.dart (~240 lines)
│   │   │   └── sheikh_today_recitations_card.dart  (~60 lines)
│   │   ├── dialogs/
│   │   │   └── multi_surah_selector_dialog.dart (~75 lines)
│   │   └── tabs/
│   │       ├── sheikh_attendance_tab.dart      (~270 lines)
│   │       ├── sheikh_memorization_tab.dart    (~320 lines)
│   │       ├── sheikh_tracks_tab.dart          (~330 lines)
│   │       ├── sheikh_trips_tab.dart           (~440 lines)
│   │       ├── sheikh_overview_tab.dart        (~60 lines)
│   │       ├── sheikh_students_tab.dart        (~200 lines)
│   │       └── sheikh_messages_tab.dart        (~170 lines)
│   │
│   └── student/
│       ├── widgets/
│       │   ├── student_header_banner.dart      (~140 lines)
│       │   └── student_locked_view.dart        (~60 lines)
│       ├── dialogs/
│       │   └── student_juz_modal.dart          (~55 lines)
│       └── tabs/
│           ├── student_progress_tab.dart       (~390 lines)
│           ├── student_attendance_tab.dart     (~175 lines)
│           ├── student_trips_tab.dart          (~175 lines)
│           ├── student_rewards_tab.dart        (~385 lines)
│           ├── student_points_tab.dart         (~35 lines)
│           ├── student_contact_tab.dart        (~145 lines)
│           └── student_rankings_tab.dart       (~85 lines)
```

---

## 5. Strict Constraint Verification: Line Counts (< 500 Lines)

Every file in the extraction blueprint strictly adheres to the `< 500 lines` constraint. Below is the verification ledger:

| File Name | Functional Scope | Estimated Lines | Strict Check (< 500) |
|---|---|:---:|:---:|
| `admin_header_banner.dart` | Hero banner, section QR buttons, quick metrics row | 145 | ✅ PASS |
| `admin_locked_view.dart` | Register mosque form & code unlock | 200 | ✅ PASS |
| `admin_sheikhs_tab.dart` | Sheikhs list, add/edit/delete modals, badges | 170 | ✅ PASS |
| `admin_halaqat_tab.dart` | Halaqat cards, capacity, schedule modals | 350 | ✅ PASS |
| `admin_students_tab.dart` | Student search, filter, add/edit modals | 260 | ✅ PASS |
| `admin_courses_tab.dart` | Intensive courses list & delete dialog | 210 | ✅ PASS |
| `admin_course_form_dialog.dart` | Unified add/edit course dialog (deduplicated) | 280 | ✅ PASS |
| `admin_trips_tab.dart` | Trips cards, add/edit modals, required items | 400 | ✅ PASS |
| `admin_tracks_tab.dart` | Recitation tracks & mutun curriculum management | 300 | ✅ PASS |
| `admin_rewards_tab.dart` | Reward catalog management | 280 | ✅ PASS |
| `admin_overview_tab.dart` | Executive table & filter oversight | 185 | ✅ PASS |
| `admin_events_tab.dart` | Mosque community events & councils | 225 | ✅ PASS |
| `mosque_admin_screen.dart` | Parent coordinator & TabBarView | 120 | ✅ PASS |
| `sheikh_header_banner.dart` | Sheikh profile, statistics, QR badge | 135 | ✅ PASS |
| `sheikh_locked_view.dart` | Sheikh code login & scanner | 60 | ✅ PASS |
| `sheikh_attendance_tab.dart` | Attendance log, scanner, points dialog | 270 | ✅ PASS |
| `sheikh_memorization_tab.dart` | Recitation orchestrator, timing detection | 320 | ✅ PASS |
| `sheikh_quran_recitation_inputs.dart` | Surah/Ayah pickers, mistake counters | 240 | ✅ PASS |
| `sheikh_today_recitations_card.dart` | Today's completed recitations list | 60 | ✅ PASS |
| `multi_surah_selector_dialog.dart` | Multi-surah selection modal | 75 | ✅ PASS |
| `sheikh_tracks_tab.dart` | Custom track assignments | 330 | ✅ PASS |
| `sheikh_trips_tab.dart` | Sheikh trips management modal & list | 440 | ✅ PASS |
| `sheikh_overview_tab.dart` | Sheikh executive table | 60 | ✅ PASS |
| `sheikh_students_tab.dart` | Halaqa students & QR generation | 200 | ✅ PASS |
| `sheikh_messages_tab.dart` | Parent communications & reply modals | 170 | ✅ PASS |
| `sheikh_screen.dart` | Parent coordinator & TabBarView | 110 | ✅ PASS |
| `student_header_banner.dart` | Student profile, points, printable badge | 140 | ✅ PASS |
| `student_locked_view.dart` | Student login & scanner | 60 | ✅ PASS |
| `student_progress_tab.dart` | Quran progress circle, Ajza grid, tracks | 390 | ✅ PASS |
| `student_juz_modal.dart` | Juz surahs & Ayahs completion details | 55 | ✅ PASS |
| `student_attendance_tab.dart` | Commitment rate & attendance ledger | 175 | ✅ PASS |
| `student_trips_tab.dart` | Student trips, items list, registration | 175 | ✅ PASS |
| `student_rewards_tab.dart` | Points store, claim modal, voucher QR | 385 | ✅ PASS |
| `student_points_tab.dart` | Transparent points transactions | 35 | ✅ PASS |
| `student_contact_tab.dart` | Sheikh chat & inquiry submission | 145 | ✅ PASS |
| `student_rankings_tab.dart` | Mosque & Halaqa leaderboards | 85 | ✅ PASS |
| `student_screen.dart` | Parent coordinator & TabBarView | 100 | ✅ PASS |

**Result**: 100% of extracted files are strictly `< 450 lines`, with 0 violations of the 500-line limit.

---

## 6. State, Callbacks & Dependency Flow Strategy (Zero Regression)

### 6.1. State Encapsulation vs Shared State
1. **Screen-Level Shared State**:
   - `ActiveSession` is retrieved once at the screen root via `DataService` / `context.watch<DataService>()`.
   - Core root entities (`Mosque`, `Sheikh`, `Student`) are resolved in the screen `build()` method and passed as immutable properties to child tabs.
2. **Tab-Specific Local State**:
   - Search strings (e.g. `_studentSearchQuery`), filter IDs (e.g. `_selectedHalaqaFilter`), and date pickers (e.g. `_overviewDate`) become internal state properties of their respective tab `StatefulWidget`.
   - This eliminates wasteful parent rebuilds when typing in search bars.
3. **Data Mutations & Reactivity**:
   - Tab widgets access `context.read<DataService>()` for mutations (`addStudent`, `recordAttendance`, `saveRecitation`, `addTrip`).
   - `DataService` fires `notifyListeners()`, causing all listening widgets to refresh seamlessly with zero data loss.
4. **Controllers Lifecycle**:
   - Form `TextEditingController`s and `FocusNode`s are instantiated in the `State` of the respective modal or tab and disposed properly in `dispose()`, preventing memory leaks.

### 6.2. Parent Coordinator Pattern Example (Mosque Admin)

```dart
class MosqueAdminScreen extends StatefulWidget {
  final ActiveSession? session;
  const MosqueAdminScreen({super.key, this.session});

  @override
  State<MosqueAdminScreen> createState() => _MosqueAdminScreenState();
}

class _MosqueAdminScreenState extends State<MosqueAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = data.getSessionForRole('mosque_admin') ?? widget.session ?? data.currentSession;
    final isUnlocked = session != null && session.role == 'mosque_admin';
    final currentMosqueId = session?.mosqueId ?? '';
    final mosque = data.getMosqueById(currentMosqueId) ?? (data.getMosques().isNotEmpty ? data.getMosques().first : null);

    if (!isUnlocked || mosque == null) {
      return AdminLockedView(data: data, isDark: isDark);
    }

    final sheikhs = data.getSheikhs(mosqueId: mosque.id);
    final halaqat = data.getHalaqat(mosqueId: mosque.id);
    final allStudents = data.getStudents(mosqueId: mosque.id);
    final events = data.getCommunityEvents().where((e) => e.mosqueId == mosque.id).toList();
    final courses = data.getIntensiveCourses(mosqueId: mosque.id);
    final trips = data.getTrips(mosqueId: mosque.id);
    final tracks = data.getRecitationTracks(mosqueId: mosque.id, activeOnly: false);
    final rewards = data.getRewards(mosqueId: mosque.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminHeaderBanner(
            mosque: mosque,
            sheikhsCount: sheikhs.length,
            halaqatCount: halaqat.length,
            studentsCount: allStudents.length,
            coursesCount: courses.length,
            tripsCount: trips.length,
            tracksCount: tracks.length,
            rewardsCount: rewards.length,
            eventsCount: events.length,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.emeraldPrimary,
            unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            indicatorColor: AppTheme.emeraldPrimary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.people), text: 'المشايخ والمعلمات'),
              Tab(icon: Icon(Icons.menu_book), text: 'الحلقات القرآنية'),
              Tab(icon: Icon(Icons.school), text: 'إدارة الطلاب'),
              Tab(icon: Icon(Icons.workspace_premium), text: 'الدورات الاستثنائية 🎓'),
              Tab(icon: Icon(Icons.directions_bus), text: 'رحلات وأنشطة المسجد 🚌'),
              Tab(icon: Icon(Icons.auto_stories), text: 'المناهج والمتون 📚'),
              Tab(icon: Icon(Icons.card_giftcard), text: 'بنك الجوائز 🎁'),
              Tab(icon: Icon(Icons.table_chart), text: 'لوحة المتابعة الشاملة 📊'),
              Tab(icon: Icon(Icons.event), text: 'الفعاليات ومجالس العلم'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 750,
            child: TabBarView(
              controller: _tabController,
              children: [
                AdminSheikhsTab(mosque: mosque, sheikhs: sheikhs),
                AdminHalaqatTab(mosque: mosque, halaqat: halaqat, sheikhs: sheikhs),
                AdminStudentsTab(mosque: mosque, students: allStudents, halaqat: halaqat),
                AdminCoursesTab(mosque: mosque, sheikhs: sheikhs, halaqat: halaqat, students: allStudents),
                AdminTripsTab(mosque: mosque, halaqat: halaqat, students: allStudents),
                AdminTracksTab(mosque: mosque),
                AdminRewardsTab(mosque: mosque),
                AdminOverviewTab(mosque: mosque),
                AdminEventsTab(mosque: mosque, events: events),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 7. Zero Regression Execution Plan

1. **Phase 1: Student Screen Extraction (Low-Risk Baseline)**
   - Extract 7 tabs + locked view + header banner into `lib/screens/student/`.
   - Run `flutter test` and `flutter analyze` to ensure 100% pass.
2. **Phase 2: Sheikh Screen Extraction (Medium Complexity)**
   - Extract 7 tabs + locked view + header banner + memorization subcomponents into `lib/screens/sheikh/`.
   - Validate attendance quick-scanner and recitation timing window detection (±30 min).
   - Run `flutter test`.
3. **Phase 3: Mosque Admin Screen Extraction (High Complexity)**
   - Extract 9 tabs + locked view + header banner + course dialog into `lib/screens/admin/`.
   - Run `flutter test` and `flutter analyze`.
4. **Phase 4: Full Suite Gate Verification**
   - Verify all 38+ automated tests pass without errors.
   - Verify compile checks and line count checks on all newly created files.
