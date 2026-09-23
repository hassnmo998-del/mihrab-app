# Implementation Plan - Multi-Mosque Cashier Support

We will upgrade the Cashier Portal to support multiple authorized mosques on a single device. This allows a user to manage rewards for several mosques without logging out and back in.

## User Review Required

> [!TIP]
> We will add a **"Mosque Switcher"** at the top of the Cashier screen. You can scan as many "Cashier Codes" as you want, and they will all be saved in your "Authorized List".

## Proposed Changes

### [Cashier Screen](file:///C:/Users/moham/Desktop/masjed%20app/flutter_app/lib/screens/cashier_screen.dart)

#### [MODIFY] [CashierScreenState](file:///C:/Users/moham/Desktop/masjed%20app/flutter_app/lib/screens/cashier_screen.dart)

- **Authorization Update**:
    - Change `isAuthorized` logic to check if there are *any* `cashier` sessions in the device's saved sessions list.
- **Active Mosque Selection**:
    - Add a state variable to track the *currently selected* cashier mosque.
    - If `currentSession` is not a cashier but saved sessions have some, auto-select the first one.
- **UI Enhancements**:
    - **Switcher Row**: A horizontal scroll of chips or a dropdown showing all authorized mosques.
    - **Add Button**: A button to scan a new `CSH-` code to add another mosque to the list.
    - **Data Filtering**: Ensure stats (this month's redemptions, total points) and history are filtered by the selected mosque's ID.
- **Scanning Logic**:
    - When scanning a student, check if they belong to any of the *authorized* mosques. If they belong to Mosque B but Mosque A is currently active, automatically switch the context to Mosque B or notify the user.

## Verification Plan

### Manual Verification
1.  Open the Cashier tab.
2.  Scan the first mosque's cashier code.
3.  Click "إضافة مسجد آخر" (Add another mosque) and scan a second code.
4.  Verify both mosques appear in the switcher.
5.  Toggle between them and ensure the mosque name, stats, and history change accordingly.
6.  Scan a student from the "inactive" mosque and verify the system recognizes them correctly.
7.  Perform a "Full Logout" and verify all cashier authorizations are wiped.
