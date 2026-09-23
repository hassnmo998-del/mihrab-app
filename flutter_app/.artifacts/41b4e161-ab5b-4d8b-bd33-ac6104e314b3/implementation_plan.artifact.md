# Implementation Plan - QR Scanning Improvement, UI Cleanup, and Remote Code Verification

This plan addresses:
1.  **Scanning issues:** Difficulty scanning QR codes from laptop screens.
2.  **UI Cleanup:** User's request to remove the fixed QR scanner icon from the top of the screen.
3.  **Authentication issues:** Manual code entry failing on new/different devices due to local-only verification logic.

## User Review Required

> [!IMPORTANT]
> The fixed QR scanner icon will be removed from the top `AppBar` in the main screen.
> The "Verify Code" logic will now attempt to reach out to the cloud (Supabase) if the code is not found locally. This requires an internet connection for the first-time login on a new device.

## Proposed Changes

### 1. Remote Data & Verification Improvements
- **[MODIFY] [supabase_remote_datasource.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/data/datasources/supabase_remote_datasource.dart)**:
    - Add `fetchOneByColumn(String table, String column, String value)` to allow targeted remote lookup.
- **[MODIFY] [auth_session_repository_impl.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/data/repositories/auth_session_repository_impl.dart)**:
    - Inject `SupabaseRemoteDataSource`.
    - Update `verifyCode` to query Supabase if a local match is not found.
    - If a remote match is found, add the entity to the local cache and save it.
- **[MODIFY] [data_service.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/services/data_service.dart)**:
    - Update `AuthSessionRepositoryImpl` instantiation to pass the remote data source.

### 2. QR Scanning Reliability & Performance
- **[MODIFY] [qr_dialogs.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/widgets/qr_dialogs.dart)**:
    - Optimize `MobileScannerController` for better screen-to-screen detection:
        - `formats: [BarcodeFormat.qrCode]`
        - `detectionSpeed: DetectionSpeed.normal`
- **[MODIFY] [code_scanner_dialog.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/widgets/code_scanner_dialog.dart)**:
    - Add and configure a `MobileScannerController` with the same optimizations.

### 3. UI Cleanup
- **[MODIFY] [main.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/main.dart)**:
    - Remove the QR scanner button from the `AppBar` actions as requested.

## Verification Plan

### Automated Tests
- None (UI and Hardware dependent).

### Manual Verification
- **Login Test:** On a fresh device (or after clearing app data), try logging in with a known code (Mosque/Sheikh/Student) that exists in Supabase but not locally.
- **QR Test:** Verify that the QR scanner is more responsive when pointed at a laptop screen.
- **UI Test:** Confirm the top bar no longer has the scanner icon.
