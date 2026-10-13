# Progress

**READY FOR OWNER REVIEW (Phase 1: screens with sample data).** Phase 2 does not start until the owner says "go".

_Last updated: 2026-10-13_

## How to look at it
**Start with [REVIEW-GUIDE.md](REVIEW-GUIDE.md)**: a 15-minute walkthrough (₹150 bill with ₹100 given, Money to collect, WhatsApp preview and Undo, walk-in with a balance, 200% text, 100 lines). Sample data is fake; nothing is saved or sent.
- **Current build (built from commit `68c77d1`, 2026-10-13):** `dist/ERP2-prototype-windows-2026-10-13-68c77d1.zip` (unzip, double-click `erp2.exe`) and `dist/ERP2-prototype-web-2026-10-13-68c77d1.zip` (open `index.html` through a local web server). Both include all current screens (credit, Money to collect, customer page, reminders, billing footer with Received and Balance, statement PDF). Older zips are in `dist/superseded/`. `dist/` is git-ignored.
- **Checked:** the Windows zip was unzipped to a fresh folder and started (window opened, stayed running 8 seconds, then closed by me); the web zip was unzipped, served on localhost and Money to collect loaded with no browser console errors. Not checked: a second PC, a Mac, a phone.
- **Without running anything:** screenshots of every screen are in [ui-review/index.md](ui-review/index.md).
- The Statement's **Save as PDF now makes a real A4 PDF** (Downloads folder, or a browser download). **Print** is still a "not connected" message (no printing in the prototype).
- Preview helper: **Ctrl+Shift+L** on New bill fills the bill with 100 sample lines.

## Phase 1 status (UI and UX, no database, no Firebase)
Done: design system, all 37 screens (first-run wizard, sign in, forgot password, Home, POS billing, estimates, saved estimates, sales register, sales returns, delivery, products, categories, stock left, purchases, purchase returns, stock changes, customers, dealers, money to collect, staff, expenses, daily closing, reports, export, import old data, warranty, house projects, notifications, settings, database health, help, about, More menu, and the four print previews: A4 invoice, 80 mm, 58 mm, estimate with its own date), English only, dark/light/match-computer, accents, high contrast, text size 80-200%, billing text size, density, two fonts, animations (Full/Gentle/Off), optional sounds.
**Added in this round: customer credit and WhatsApp reminders** (screens + all rules as tested pure Dart; Phase 2 wiring is written in [data-model.md](data-model.md)): part payment becomes credit in the pinned POS footer, Credit and Dues, customer page (ageing, bill-wise dues, ledger, reminder history), Receive payment, write-off (owner), statement, payment receipt, WhatsApp reminder preview, Settings > Reminders, Received/Balance on print and bill view, Paid / Part paid / Unpaid chips.
Evidence and numbers: see the report in the last message and [perf-results.md](perf-results.md), [motion-guide.md](motion-guide.md), [design-system.md](design-system.md).

## Phase 0 recap
Environment, ERP 1 archive (verified identical copy `ERP-1.0.1`), plan documents, spikes S1-S4 plus Android and browser checks, quota analysis of rule lookups, convergence test: see [spikes.md](spikes.md).

## Blocked on the owner
- **GitHub:** `gh` is installed but **not signed in** (checked 2026-10-13: "not logged into any GitHub hosts"). Nothing is pushed. When you sign in (`gh auth login`), I create the public repo ERP-2.0, push all commits and publish the two zips as a pre-release. Until then the zips are in `dist/`.
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
20. Credit limit default is off; Settings > Credit limit: Off / Warn / Block (owner chooses).
21. Write-off is owner-only, needs a reason, and cannot exceed what is owed.
22. A reminder record means "Open WhatsApp was pressed", never "delivered"; the screens say "Reminders opened in WhatsApp". Undo for 8 seconds; 24-hour guard asks before a repeat (hours in Settings > Reminders).
23. The app never sends by itself and never bulk-sends. Offline: button disabled with the reason, "Copy message" offered. Default country code +91.
24. Phase 1 opens links with small built-in code (no plugin); Phase 2 swaps in `url_launcher` once Developer Mode is on (Android needs it).
25. Reminder events are held 10 seconds before upload so Undo needs no cloud delete; about 20 small writes a day (quota-budget.md).

## Open questions for the owner
- Which Google account owns the Firebase project (OWNER-SETUP step 3)?
- Is the WhatsApp message wording (Friendly and Firm) right for your customers? Edit in Settings > Reminders.
- Is the Phase 1 look right? Corrections go in as a list; I apply them before Phase 2.
