# Progress

**PHASE 2 IN PROGRESS (the owner said "go").** Gate 2A (real database) is done; Gate 2B (import from ERP 1) is built and tested on synthetic files and is waiting at its STOP for the owner's backup copy and the stock-value decision. The owner review of Phase 1 and the security hardening are done.

_Last updated: 2026-10-15 (Phase 2, Gate 2A)_

## How to look at it
**Start with [REVIEW-GUIDE.md](REVIEW-GUIDE.md)**: a 15-minute walkthrough (₹150 bill with ₹100 given, the Credit button, Money to collect, customer and dealer profiles, Settle fully with Undo, WhatsApp preview, the Shop profile and the estimate printout, 200% text, 100 lines). Sample data is fake; nothing is saved or sent.
- **Current build: pre-release `v2.0.0-proto.2`** (checked on 2026-10-14: the Windows build ran for 10 seconds, the web build loaded with no console errors, the screenshot zip opened with 416 pictures) on GitHub (<https://github.com/Anushath15/ERP-2.0/releases>): `ASK-ERP-2.0-windows-v2.0.0-proto.2.zip` (unzip, double-click `ASK_ERP_2.exe`), `ASK-ERP-2.0-web-v2.0.0-proto.2.zip` and the full screenshot set `ASK-ERP-2.0-screenshots-v2.0.0-proto.2.zip`. They are built by the release workflow from the tagged commit.
- **Without running anything:** the main screens are in [ui-review/index.md](ui-review/index.md).
- Things that now really work in the prototype: Save as PDF (statements, bills, estimates; saved on this computer only), Ctrl+Shift+L fills 100 sample lines on New bill.

## Phase 1 status (UI and UX, no database, no Firebase)
Done: design system, all 37 screens (first-run wizard, sign in, forgot password, Home, POS billing, estimates, saved estimates, sales register, sales returns, delivery, products, categories, stock left, purchases, purchase returns, stock changes, customers, dealers, money to collect, staff, expenses, daily closing, reports, export, import old data, warranty, house projects, notifications, settings, database health, help, about, More menu, and the four print previews: A4 invoice, 80 mm, 58 mm, estimate with its own date), English only, dark/light/match-computer, accents, high contrast, text size 80-200%, billing text size, density, two fonts, animations (Full/Gentle/Off), optional sounds.
**Added in this round: customer credit and WhatsApp reminders** (screens + all rules as tested pure Dart; Phase 2 wiring is written in [data-model.md](data-model.md)): part payment becomes credit in the pinned POS footer, Credit and Dues, customer page (ageing, bill-wise dues, ledger, reminder history), Receive payment, write-off (owner), statement, payment receipt, WhatsApp reminder preview, Settings > Reminders, Received/Balance on print and bill view, Paid / Part paid / Unpaid chips.
Evidence and numbers: see the report in the last message and [perf-results.md](perf-results.md), [motion-guide.md](motion-guide.md), [design-system.md](design-system.md).

## Security hardening (2026-10-14): ten review findings
Status of each finding is in [threat-model.md](threat-model.md) (fixed / mitigated / accepted). Production Firestore rules (roles, field checks, device approval, daily counter, audit records) were tested on the emulator (62 rules tests) and **deployed to the real project `ask-erp-2`** (alias `prod`). Release pipeline hardened (pinned actions, `release` environment needing the owner's approval, checksums, attestations); the `v2.0.0-proto.3` tag is **not** pushed yet: it waits for the owner to look at the release environment (see the last report). Owner steps: [SECURITY-CHECKLIST-FOR-OWNER.md](SECURITY-CHECKLIST-FOR-OWNER.md).

**Follow-up (2026-10-14, later):** finding 9 revised: daily commit caps are now cashier 20 (raised from 16 on the owner's request), manager 24, owner 24 (worst case 10,000 to 12,000 of the 20,000 free writes), the app sends at most 100 documents per commit (`lib/domain/sync/batch_plan.dart`), the honest limit (rules cannot enforce batch size) and a two-minute emergency procedure are written down; finding numbers in `threat-model.md` now match the original review list. Rules redeployed to `ask-erp-2` (a second deploy said "already up to date", so the live rules equal the repo). Five Dependabot pull requests are open, all major-version bumps, none merged (four touch the workflows). The `v2.0.0-proto.3` tag is still **not** pushed: it waits for the owner to say "tag".

**Owner decisions on the follow-up (2026-10-14):** cashier cap raised to 20 commits a day (rules redeployed). `cupertino_icons` 1 to 2 merged after the full tests passed and all 416 screenshots came out byte-identical (the app code does not use that package's icons). The four workflow pull requests (checkout, attest-build-provenance, download-artifact, upload-artifact) stay open **until `v2.0.0-proto.3` is built, approved and verified**; then they go in together on one branch, tested with a test release run (not a public tag). The upload-artifact PR failed CI only because its branch was cut before a golden-image fix on main (the settings screenshot captured before the logo loaded), not because of the action. Tag still **not** pushed: waiting for the owner to say "tag".

## Phase 2, Gate 2A: the real database (done, 2026-10-15)
What now works: every screen reads and writes a real SQLite database through repositories (`lib/data`); the sample shop moved behind **Demo mode** (Settings, its own file `demo.sqlite`, an amber strip on every page while it is on); the first-run set-up asks for shop details, a bill-number prefix and **this computer's series letter** (a letter held by another computer is refused); the program starts with plain-English screens for a newer, damaged, locked, read-only or unreachable data file; a health check of the file runs after start-up in a separate isolate (weekly full check, daily self-check of every total), the disk is watched (warning under 500 MB, saving stopped under 100 MB), and the Health page shows the real figures and a working **Recalculate** (rebuilds every total from the raw rows).
Evidence (all run on this PC): see `docs/data-model.md` and `docs/perf-results.md` ("Real repository layer"). Power-cut test: **200 kills in the middle of saving, 20,002 bills, 0 problems, every acknowledged bill present** (`dart run tool/kill_test/run.dart 200`; the test suite runs 25 of them). The browser build opens the same schema in WebAssembly (checked in Chromium: demo shop seeded, survives a reload).
Found and fixed in earlier work while doing this: the prototype's `main.dart` never used the real device-settings store (settings were not remembered between runs); strings added during the security work were typed into the generated `strings.dart` and would have been lost on the next regeneration (they are in `tool/strings.txt` now); the sample "shop profile" (name, GSTIN, UPI id, bank) was the default for every shop (now empty for a real shop, filled only by the demo seeder).
Not verified: a real power cut (only process kills; SQLite `synchronous=FULL` is on), the browser build on Safari and Firefox, the Android build (not started), a restore (Gate 2C).

## Phase 2, Gate 2B: import from ERP 1 (built 2026-10-15, STOP: waiting for the owner)
What exists: `docs/erp1-import-map.md` (every ERP 1 list, its fields, where each goes, what has no home); the importer (`lib/import/erp1/` reading and checking, `lib/data/importer/erp1_writer.dart` writing, `tool/import_erp1.dart` command); a report with counts per list, sales and payments per month, customer and dealer balances, stock, **stock value three ways side by side (no rule applied; `valuation.rule` stays unset)**, every record rejected/repaired/noted with its reason, lists with no home, old bill numbers.
Rules it keeps: dry run by default; writes only a NEW file, in one transaction (a failure deletes the half-built file); stable ids from ERP 1 ids so a second run adds nothing; nothing queued for upload; original bill numbers kept in `old_bill_no` (searchable); customer/dealer balances and stock are made to equal ERP 1's figures exactly (opening entries), and anything the file could not explain is listed.
Run on **synthetic** files only (invented shop, planted flaws): 100,000 bills (95 MB file): read and check 5.9 s, write 26 s into a 220 MB database, every total read back equals the backup, the program's own consistency check finds 0 problems. 27 new tests (units, 12 planted flaws, hostile files: not JSON, truncated, wrong types, 5 MB names, 1e300, NaN, impossible dates, 200,000-deep nesting, 100,000 bad rows, idempotent second run, non-empty database refused, failure leaves nothing).
Also fixed: the Inventory screen's hint said "At average cost price" but used the buying price; it now says "At buying price (rule not chosen yet)".
**Needed from the owner:** the ERP 1 backup copy (steps in the import map, section 8) and the stock-value choice (selling / buying / average cost; worked example from the real data comes with the report).
Not verified: any real ERP 1 data; ERP 1's checksum; the in-app import screen is not built (command only).

## Gate 2B follow-up (2026-10-15): slow save, stock value, file check
- **Slow save found and measured** (details and tables in `docs/perf-results.md`, failure mode #32): SQLite's checkpoint inside a save cost about 13 ms once in ~20 saves (now moved to quiet moments between saves, with SQLite's own checkpoint kept as a net); the rare 120-200 ms save is the disk flush of `synchronous=FULL` on this PC (proved by switching to NORMAL: it disappears) and cannot be removed without losing power-cut safety. Re-measured, 3,000 saves at person speed on the 4.7 GB file: p50 5.2 ms, p95 6.4 ms, p99 15.2 ms, p99.9 179 ms, max 197 ms; 0.8% of saves over 50 ms. Kill test re-run with checkpoints firing: 200 kills, 0 problems.
- **Stock value** is now one calculation (`lib/domain/stock_value.dart`) used by Inventory, Health and the import report, and one setting (`valuation.rule`, unset until the owner's father chooses). Until then average cost is shown as "Recommended, not chosen yet"; cost-not-set, inactive and negative stock are separate lines as asked. Needed a schema change: `products.avg_cost_paise` (version 2, migration + test from version 1 pass).
- **File check:** the importer re-computes ERP 1's own SHA-256 checksum and the record counts and prints the result at the top of the report; tampering is caught in tests.
- Found and fixed: the power-cut test reused a stale built writer after a schema change and waited 30 s per run; it now rebuilds when sources change.
- Tests: 587 pass (11 skipped). Waiting: the owner's ERP 1 copy (dry run), the report approval, then the real `--write`, then the in-app import screen.

## Phase 0 recap
Environment, ERP 1 archive (verified identical copy `ERP-1.0.1`), plan documents, spikes S1-S4 plus Android and browser checks, quota analysis of rule lookups, convergence test: see [spikes.md](spikes.md).

## Blocked on the owner
- **GitHub: done.** Code: <https://github.com/Anushath15/ERP-2.0> (public, history about 44 MB). CI (analyze, tests, web and Windows builds) passes on `main`. Pre-release **v2.0.0-proto.1** with the Windows zip, web zip and full screenshot zip: <https://github.com/Anushath15/ERP-2.0/releases/tag/v2.0.0-proto.1>. Secret scanning and push protection are on.
- **Firebase: made on 2026-10-14 under anushath15@gmail.com (Owner)**: project **`ask-erp-2`**, Spark plan, **no billing attached**, Firestore `(default)` in **asia-south1 (Mumbai)** (reasons: docs/firebase-setup-notes.md), closed to everyone except the two shop addresses in the deployed rules, Web app registered, Hosting live at <https://ask-erp-2.web.app> (prototype with sample data; checked on desktop and phone width). The app is **not** connected to it (Phase 2). **Still waiting on you (click steps in OWNER-SETUP section 4):** A turn on Email/Password and Google sign-in, B the public-facing name, C the plain-English password-reset email (and test it), D add senthilenterprises.erp@gmail.com as second Owner (it must accept the invitation), E look at the plan badge. Keep **two Owners** at all times.
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
