# Product requirements

**Product:** ERP 2.0 for Senthil Enterprises (hardware, electrical, plumbing shop, India).
**Why:** ERP 1.0 (Electron) is laggy. ERP 2.0 must feel instant.

## Non-negotiables
1. Fast: no artificial splash, no lag while billing. Budgets: cold start under 1.5 s (3 s low-end), no action blocks the UI over 100 ms, product search under 16 ms per keystroke at 5,000 products, save bill under 150 ms, any list opens under 300 ms at 50,000 bills.
2. 100% offline. Internet only copies data to Firebase and signs in the first time on a device.
3. 100% free: Flutter, SQLite, GitHub, Firebase Spark. Never Blaze, never Functions/Storage/paid APIs.
4. Easy for ordinary people: simple words, big screens, no technical errors.
5. Never lose or corrupt data (see failure-modes.md).
6. Money in integer paise; GST rounding rules written and property-tested (data-model.md).

## Who uses it
The owner (full access, away often), his father (billing, wants it simple and fast), staff (cashier/manager roles later). Phone use for checking sales and stock.

## Features (everything in ERP 1 plus its lessons)
Dashboard; POS billing; Estimations with Saved Estimations (list, search, filter, view, edit-in-place keeping number and date, duplicate, convert to invoice, delete with reason); Sales register; Sales returns; Delivery; Products; Categories; Inventory; Purchases; Purchase returns; Stock adjustments; Opening balance and stock wizards; Customers; Dealers; Credit and dues with payments; Expenses; Daily closing; Reports and analytics; Export center (PDF, Excel, CSV); Warranty; House projects; Staff; Notifications; Settings; Help; About; Backup, restore and database health; ERP 1.0 importer.

### ERP 1 lessons that are requirements
- Product picker is a vertical table: full name always visible (wraps, never ellipsis), big bold name, price in its own column, stock with unit, separate "Out of stock" badge, "in bill" quantity badge, no images, windowed for 5,000+ products, Up/Down/Enter, barcode scan, Enter adds the first match.
- "+ Add Product" beside search and a "No product found. + Add '<text>'" row; quick-add dialog leaves the bill untouched; "Save and add to bill"; then print immediately.
- Billing screen fills the window; the product table and bill lines scroll inside themselves; Grand Total, payment mode, Save, Save and Print, Preview are pinned; no blank gap; works at 1920x1080, 1366x768, 1280x720, tablet, phone.
- Estimation print shows its own date DD/MM/YYYY beside its number, and "Edited on" only if edited.
- Keyboard first on desktop (F-keys, Ctrl+S, Ctrl+Shift+N, Esc); big touch targets on Android; phone layout uses lists and bottom sheets.
- Selling at stock 0 warns, never blocks.

## Owner decisions carried over from ERP 1
A4 direct print; zero-stock sales allowed with a warning; a Pending purchase adds no stock; cancelling a bill is owner-only with a reason.

## ERP 1.0 importer
Reads `ERP_Backup_*.json` (the `erp_*` and `auth_*` keys) from a path the owner gives, never from the repo and never written to. Dry run first: counts, warnings (negative stock, missing costs, duplicate names, invalid dates), totals. Import into a fresh ERP 2.0 database and prove equality (products, stock quantities, customer/dealer balances, bill count and sums, stock valuation). Idempotent: safe to run twice.

## Accounts
First launch per device: Google sign-in where supported, email + password everywhere, password reset by email. Stay signed in until Logout; open offline always. First account creates the shop and is the Owner. Staff are added by the owner typing their verified email. Optional app-lock PIN, default off.

## Out of scope for v2.0
Direct ESC/POS and Bluetooth printers, auto-update, SMS/phone auth, push notifications.

## Success
A real pilot at the shop passes; only then does the owner retire ERP 1.0 (it stays in use until he says so).
