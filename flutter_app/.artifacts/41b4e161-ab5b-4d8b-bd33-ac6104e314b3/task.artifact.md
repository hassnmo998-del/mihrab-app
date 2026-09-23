# Tasks - QR Scanning and Authentication Fix

- [x] Remote Data & Verification Improvements
    - [x] Update `SupabaseRemoteDataSource` with `fetchOneByColumn`
    - [x] Update `AuthSessionRepositoryImpl` with remote lookup logic
    - [x] Update `DataService` to inject remote source into repository
- [x] QR Scanning Reliability & Performance
    - [x] Optimize `UniversalQrScannerDialog` in `qr_dialogs.dart`
    - [x] Optimize and add controller to `CodeScannerDialog` in `code_scanner_dialog.dart`
- [x] UI Cleanup
    - [x] Remove fixed QR scanner icon from `main.dart`
