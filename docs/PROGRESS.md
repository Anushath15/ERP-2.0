# Progress

**READY FOR OWNER REVIEW (Phase 1: screens with sample data).** Phase 2 does not start until the owner says "go".

_Last updated: 2026-10-13_

## How to look at it
- **Start the prototype (Windows):** unzip `dist/ERP2-prototype-windows.zip` and double-click `erp2.exe` (or, in this folder: `flutter run -d windows`).
- **Web:** `dist/ERP2-prototype-web.zip` (open `index.html` through any local web server), or `flutter run -d chrome`.
- **Without running anything:** screenshots of every screen are in [ui-review/index.md](ui-review/index.md) (phone, tablet, desktop; dark and light; plus text sizes 100/150/200%).
- Nothing is saved except per-device display settings; all data is made-up sample data.

## Phase 1 status (UI and UX, no database, no Firebase)
Done: design system, all 37 screens (first-run wizard, sign in, forgot password, Home, POS billing, estimates, saved estimates, sales register, sales returns, delivery, products, categories, stock left, purchases, purchase returns, stock changes, customers, dealers, money to collect, staff, expenses, daily closing, reports, export, import old data, warranty, house projects, notifications, settings, database health, help, about, More menu, and the four print previews: A4 invoice, 80 mm, 58 mm, estimate with its own date), English only, dark/light/match-computer, accents, high contrast, text size 80-200%, billing text size, density, two fonts, animations (Full/Gentle/Off), optional sounds.
Evidence and numbers: see the report in the last message and [perf-results.md](perf-results.md), [motion-guide.md](motion-guide.md), [design-system.md](design-system.md).

## Phase 0 recap
Environment, ERP 1 archive (verified identical copy `ERP-1.0.1`), plan documents, spikes S1-S4 plus Android and browser checks, quota analysis of rule lookups, convergence test: see [spikes.md](spikes.md).

## Blocked on the owner
- **GitHub:** `gh` is not signed in. First step next session: `gh auth status`, create the public repo ERP-2.0, push, publish the Windows zip as a pre-release. Until then the zips are in `dist/` (git-ignored).
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

## Open questions for the owner
- Which Google account owns the Firebase project (OWNER-SETUP step 3)?
- Is the Phase 1 look right? Corrections go in as a list; I apply them before Phase 2.
