# Walkthrough - Multi-Mosque Cashier Support

I have upgraded the Cashier Portal to allow a single user to manage multiple mosques simultaneously. This is ideal for authorized distributors or organizations serving several communities.

## Key Enhancements

### 1. Unified Mosque Switcher 🕌↔️🕌
- Added a horizontal **Switcher Bar** at the top of the Cashier screen.
- All mosques for which you have scanned a "Cashier Code" will appear as selectable chips.
- Switching between mosques updates all statistics, available rewards, and history logs instantly.

### 2. Add New Mosque Button ➕
- A new icon in the AppBar allows you to scan additional `CSH-` codes without logging out.
- This expands your "Authorized List" on the device.

### 3. Context-Aware Student Scanning 🧠
- If you scan a student belonging to "Mosque B" while you are currently looking at "Mosque A":
    - The app automatically detects that you are also an authorized cashier for "Mosque B".
    - It **switches the context automatically** to "Mosque B" so you can proceed with the sale without manual intervention.

### 4. Filtered Statistics & History
- Stats like "Rewards dispensed this month" and "Total points redeemed" are now calculated specifically for the **active mosque** selected in the switcher.
- The history log also only shows transactions for that specific location.

## Technical Details
- Updated [CashierScreen](file:///C:/Users/moham/Desktop/masjed%20app/flutter_app/lib/screens/cashier_screen.dart) state management to handle multiple saved cashier sessions.
- Enhanced scanning logic to switch sessions based on the scanned student's origin.
- Ensured full compatibility with the "Complete Logout" system (all authorizations are wiped on logout).

render_diffs(file:///C:/Users/moham/Desktop/masjed%20app/flutter_app/lib/screens/cashier_screen.dart)
