# Progress

**READY FOR OWNER REVIEW (Phase 1: screens with sample data).** Phase 2 does not start until the owner says "go".

_Last updated: 2026-10-14 (evening)_

## How to look at it
**Start with [REVIEW-GUIDE.md](REVIEW-GUIDE.md)**: a 15-minute walkthrough (₹150 bill with ₹100 given, the Credit button, Money to collect, customer and dealer profiles, Settle fully with Undo, WhatsApp preview, the Shop profile and the estimate printout, 200% text, 100 lines). Sample data is fake; nothing is saved or sent.
- **Current build: pre-release `v2.0.0-proto.2`** (checked on 2026-10-14: the Windows build ran for 10 seconds, the web build loaded with no console errors, the screenshot zip opened with 416 pictures) on GitHub (<https://github.com/Anushath15/ERP-2.0/releases>): `ASK-ERP-2.0-windows-v2.0.0-proto.2.zip` (unzip, double-click `ASK_ERP_2.exe`), `ASK-ERP-2.0-web-v2.0.0-proto.2.zip` and the full screenshot set `ASK-ERP-2.0-screenshots-v2.0.0-proto.2.zip`. They are built by the release workflow from the tagged commit.
- **Without running anything:** the main screens are in [ui-review/index.md](ui-review/index.md).
- Things that now really work in the prototype: Save as PDF (statements, bills, estimates; saved on this computer only), Ctrl+Shift+L fills 100 sample lines on New bill.

## Phase 1 status (UI and UX, no database, no Firebase)
Done: design system, all 37 screens (first-run wizard, sign in, forgot password, Home, POS billing, estimates, saved estimates, sales register, sales returns, delivery, products, categories, stock left, purchases, purchase returns, stock changes, customers, dealers, money to collect, staff, expenses, daily closing, reports, export, import old data, warranty, house projects, notifications, settings, database health, help, about, More menu, and the four print previews: A4 invoice, 80 mm, 58 mm, estimate with its own date), English only, dark/light/match-computer, accents, high contrast, text size 80-200%, billing text size, density, two fonts, animations (Full/Gentle/Off), optional sounds.
**Added in this round: customer credit and WhatsApp reminders** (screens + all rules as tested pure Dart; Phase 2 wiring is written in [data-model.md](data-model.md)): part payment becomes credit in the pinned POS footer, Credit and Dues, customer page (ageing, bill-wise dues, ledger, reminder history), Receive payment, write-off (owner), statement, payment receipt, WhatsApp reminder preview, Settings > Reminders, Received/Balance on print and bill view, Paid / Part paid / Unpaid chips.
Evidence and numbers: see the report in the last message and [perf-results.md](perf-results.md), [motion-guide.md](motion-guide.md), [design-system.md](design-system.md).

## Phase 0 recap
Environment, ERP 1 archive (verified identical copy `ERP-1.0.1`), plan documents, spikes S1-S4 plus Android and browser checks, quota analysis of rule lookups, convergence test: see [spikes.md](spikes.md).

## Blocked on the owner
- **GitHub: done.** Code: <https://github.com/Anushath15/ERP-2.0> (public, history about 44 MB). CI (analyze, tests, web and Windows builds) passes on `main`. Pre-release **v2.0.0-proto.1** with the Windows zip, web zip and full screenshot zip: <https://github.com/Anushath15/ERP-2.0/releases/tag/v2.0.0-proto.1>. Secret scanning and push protection are on.
- **Firebase: waiting on the owner.** Needs the shop Gmail address (OWNER-SETUP step 3), then `firebase login` with it in the browser (step 4). The CLI on this PC is currently signed in with the personal Gmail, so I did not create anything. Nothing is created, no billing, the app is not connected to Firebase.
- **Windows Developer Mode is still off** (checked again today). Needed only to build apps with native plugins on this PC (official Firebase plugins, printing/scanner plugins in Phase 2). The Phase 1 prototype needs no plugin. OWNER-SETUP step 1.
- **Firebase project** (OWNER-SETUP step 3): not needed until real sync in Phase 2.

## Decisions taken on my own (change by telling me)
1. Cloud layer = plain REST behind interfaces, not the official Firebase plugins (evidence: S1; reason in spikes.md).
2. Stock movements and ledger rows are derived locally from bills; only bills and non-derivable events are uploaded (keeps first restore under the 50,000 reads/day limit).
3. Pull cursor is (server timestamp, document id).
4. Invoice series is per device (`A-`, `B-`).
5. Start-up check is `quick_check`; full `integrity_check` weekly / on the Health page.
6. Stock valuation default: average cost, unpriced stock = 0.
7. Tamil removed by owner, English only. All text, fonts and print code are English; a name someone types is stored and shown exactly as typed.
8. Nothing was sent to the HP printer (no test page without the owner's say-so).
9. `ERP-2.0` stays where it is inside `D:\Senthil Enterprises`; the parent repository ignores it through its local `.git/info/exclude` (not committed).
10. English text lives in one plain file (`tool/strings.txt`, turned into `lib/strings.dart`), not ARB: simpler, no locale code.
11. Fonts: **Inter** (default) and **Atkinson Hyperlegible Next** (the first Atkinson release has no rupee sign). Change: Settings > Appearance > Letter style.
12. Accent colours: Blue (default), Teal, Green, Orange, Violet, each checked for contrast. Change: Settings > Appearance > Accent colour; to add or change a colour, edit `Accent` in `lib/design/tokens.dart`.
13. **Default animation level is Gentle** (page/window/press effects only); the billing effects (new-line slide, count-up totals, success tick) are Full. Change: Settings > Animations.
14. Width is judged as the text sees it (window width divided by text size), so big text switches to the roomier phone layout. Change: `effectiveWidth` in `lib/core/responsive.dart`.
15. Sounds use the computer's beep in this preview (no audio plugin yet): the volume slider is stored but has no effect until real audio is added in Phase 2.
16. Per-device display settings are saved as a small JSON file in the user's data folder (`%APPDATA%\SenthilERP2\device.json`) or browser local storage; phones keep them only while the app runs until Phase 2 adds the database.
17. Credit sale needs a named customer (pick or quick-add name and phone) before saving; a walk-in with a balance cannot be saved. Change: `_save` in `lib/features/billing/billing_screen.dart`.
18. Overpayment shows change to give back by default; "Keep as advance" is a tick, only for a named customer. A payment above the dues becomes an advance.
19. Receive payment goes to the OLDEST bills first; "Choose bills" overrides. Overdue = older than 30 days. Change: `overdueAmount(termDays)` in `lib/domain/credit/dues.dart`.
20. Credit limit: Off / Warn / Block (owner chooses); default **Warn**. It lives on the Shop profile page now.
21. Write-off is owner-only, needs a reason, and cannot exceed what is owed.
22. A reminder record means "Open WhatsApp was pressed", never "delivered"; the screens say "Reminders opened in WhatsApp". Undo for 8 seconds; 24-hour guard asks before a repeat (hours in Settings > Reminders).
23. The app never sends by itself and never bulk-sends. Offline: button disabled with the reason, "Copy message" offered. Default country code +91.
24. Phase 1 opens links with small built-in code (no plugin); Phase 2 swaps in `url_launcher` once Developer Mode is on (Android needs it).
25. Reminder events are held 10 seconds before upload so Undo needs no cloud delete; about 20 small writes a day (quota-budget.md).

26. **Page changes** replace the old page at once; the new page fades in from 55% to 100% in 100 ms (nothing when animations are Off). Change: `motionPage` in `lib/design/motion.dart`.
27. **The app is "ASK ERP 2.0"** with the ERP 1.0 logo. The Windows file is `ASK_ERP_2.exe`. The shop name in the header comes from the Shop profile.
28. **No Preview step.** "Save and print" and "Print again" open one Print screen (Print and Save as PDF only; printing itself is still "not connected" in the prototype). The sample printouts at `/preview/...` are kept only for screenshots and tests, they are not linked from any menu.
29. **Credit** is the fourth payment mode: Paid now (starts at 0), Nothing / Half / Full ("Full" turns it back into a normal full payment). A smaller Amount received on Cash, UPI or Card works the same and uses the same "who is this credit for?" window.
30. **Profiles** (customers and dealers) are for the shopkeeper's own eyes: no link, no sharing, no sending. Wrong entries are reversed by a new entry, never deleted. Money paid beyond the bills first pays an old opening balance and only the rest becomes an advance. Settle fully has an 8-second Undo (the entries are held back before upload, like reminders).
31. **Shop profile** is its own sidebar page and its own data (it syncs with the shop in Phase 2); Settings keeps only this computer's choices (text size, theme, density, animations, sounds, paper and print text size, backup, sync status, security). The estimate switches are all OFF by default.
32. **Printouts and PDFs** come from one layout, so the screen and the PDF always agree. Estimate PDFs and roll paper are exactly as long as their content (no blank space); A4 and A5 tax invoices are normal pages. Print text size: Smaller 8 pt, **Small 9.5 pt (default)**, Normal 11 pt rows; title 12 pt, total 11 pt at Small. A bold font file (`Inter-Bold.ttf`, made from Inter) is bundled for PDFs.
33. **For 1,000,000 bills (agreed by the owner 2026-10-14)** the design is: cursor paging, summary tables updated in the same transaction, and one database file per finished year (archiving a year inside the live file was measured and rejected). Only the last 24 months of bills go to Firebase; older ones stay on the PC and in a yearly backup file the owner keeps. Phase 2 adds a yearly backup reminder and a "Restore an old year" action (details: quota-budget.md and data-model.md).
34. **First visit of Money to collect** is prepared right after the first screen (18.7 ms instead of 41 ms). The motion timing test uses a fake clock and no longer fails on a busy computer.
35. Fixed on the way: adding a customer used to reset all credit data, reminders and estimates (they were rebuilt from the sample data); a search typed after scrolling far down a long product list froze the screen for seconds.

## Open questions for the owner
- Which Google account owns the Firebase project (OWNER-SETUP step 3)?
- Is the WhatsApp message wording (Friendly and Firm) right for your customers? Edit in Settings > Reminders.
- Is the Phase 1 look right? Corrections go in as a list; I apply them before Phase 2.
