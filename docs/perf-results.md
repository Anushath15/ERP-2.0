# Frame-timing results (billing flow, Full animations, real Windows build)

Measured on 2026-10-13 with `tool/perf/frame_timing_main.dart` run as a **Windows profile build** (a real release-like build, not a widget test):
`flutter run -t tool/perf/frame_timing_main.dart -d windows --profile`. Machine: Intel Core i5-12500H (16 CPU threads), 16 GB RAM, Windows 11, built-in display pipeline. Raw numbers: [perf/frame-timing.json](perf/frame-timing.json).

The program drives the real app by itself with **Full animations**: it adds **100 bill lines** (one every 25 ms, faster than a person), types a product search character by character, then flips through **10 pages** (sales register with 20,000 bills, products, customers, reports, estimates, stock, settings, home, money to collect, billing). Frame time = build + raster time of each frame.

| Run | Frames | Average | Median | 95th percentile | 99th | **Worst** | Frames over 16.7 ms | Over 33.4 ms |
|---|---|---|---|---|---|---|---|---|
| Normal | 705 | 6.71 ms | 5.93 ms | **11.46 ms** | 13.78 ms | **27.79 ms** | 2 | 0 |
| Contended (8 busy CPU processes, half of all threads kept at 100%) | 636 | 11.16 ms | 10.13 ms | **19.63 ms** | 22.72 ms | **25.43 ms** | 87 | 0 |

**Budget: worst frame under 33 ms, 95th percentile under 16 ms.**
- Normal: **both met** (worst 27.8 ms, p95 11.5 ms).
- Contended ("throttled" machine): worst frame **met** (25.4 ms), 95th percentile **not met** (19.6 ms, budget 16 ms). Even then the average (11.2 ms) is far from the 22 ms where the auto-protect guard would drop to Gentle, and no frame was over 33 ms.

What we changed because of the first run (it failed the budget: worst frame 119 ms, p95 18.7 ms): the sales register built all 20,000 bills at once when opened. Bills are now built only when they are shown (lazy list) and the reports and sales statistics stop at the first bill outside their range.

**Not verified:** a real low-end PC or tablet, a real shop PC under real use. A true CPU throttle is not possible on this machine, so "contended" means other busy programs, not a slower processor.

Other timing facts (widget tests, `test/motion_test.dart`): scan x20 + Save take effect in the very next frame with animations Off and Full; the wall time of that flow was 1.5 s (Off) and 1.2-1.4 s (Full) in the test harness, i.e. no added waiting.


---

# Owner corrections round (2026-10-14): page switching, and a shop with 1,000,000 bills

## Page switching: before and after (Windows profile build, Full animations, run twice each)
**Cause:** every page change was a Navigator transition. The old page stayed in the picture under the new one for the whole fade, like a slide show. **Fix:** the new page replaces the old one at once; it only fades in from 55% to 100% in 100 ms (nothing at all when animations are Off). The sidebar and header are not rebuilt. A frame-by-frame test (`test/page_switch_test.dart`, every 8 ms for 400 ms, three animation levels) proves that no frame ever has both pages and that the first frame already has the new page's content.

| Frames while flipping through 10 pages | Before (run 1 / run 2) | After (run 1 / run 2) |
|---|---|---|
| Average | 6.77 / 6.76 ms | **5.53 / 4.86 ms** |
| 95th percentile | 13.66 / 10.92 ms | **11.91 / 8.52 ms** |
| Worst frame | 20.12 / 19.83 ms | 28.41 / 27.92 ms |
| Frames over 33 ms | 0 / 0 | 0 / 0 |

Same test while 8 CPU processes keep half of the threads busy: page-switch 95th percentile 13.5 ms before, 10.9 ms after; worst 27.1 ms before, 33.1 ms after.

**Honest reading:** on average a page change is about 20% lighter and the 95th percentile is better, but the **worst single frame is about 8 ms worse** (still under the 33 ms limit in normal use; 33.1 ms when the machine is busy). The reason: the new page is now built in one go instead of the old page keeping the screen busy during its fade. The worst frames are the first visit to a heavy page (worst frame per page, after, ms): Money to collect 43, Reports 26, Settings 25, everything else 10 to 20. **Money to collect (43 ms, also 41 ms before the change) is over the 33 ms budget on its first visit; not fixed in this round.**

## 50,000 products on New bill (Windows profile build)
- Scrolling the product list very fast (15 rows a frame, 655 frames): average 7.7 ms, 95th percentile 9.8 ms, worst 12.1 ms, none over 16 ms. **Pass.**
- Typing a search over the 50,000 products: 95th percentile 7.2 ms, worst 9.5 ms. **Pass after a fix.**
- **Found and fixed by this test:** after scrolling far down the list, the first letter typed in the search box froze the screen for 1.1 to 5.3 seconds (it rebuilt every row between the old scroll position and the top). Each new search is now a fresh list view that starts at the top: first keystroke 15 ms.
- (The real app will not hold 50,000 products in memory: Phase 2 asks the database for the best 50 matches, see below.)

## 1,000,000 bills (`spikes/s2_drift_perf/bin/scale1m.dart`, the database file is a test file and is not committed)
Setup: 1,000,000 bills over 5 years (3 to 8 lines each, 5.0 on average), 5,000,000 bill lines, 5,000,000 stock movements, 5,000 customers (one with 5,741 ledger rows), 50,000 products, summary tables, FTS5. SQLite WAL, `synchronous=FULL` (safest), **SQLite cache limited to 32 MB** (to imitate a small PC). This machine: SSD, plenty of memory.

**Size:** 3,619 MB = **3,795 bytes per bill** (a bill with its lines, movements, ledger row and every index). Biggest parts: stock movements 718 MB, bill lines 695 MB, index of lines by product 488 MB, index of movements by product 308 MB, three indexes on text ids 271 MB each. Seeding took 592 s.

| Measure (budget) | p50 | p95 | max | Result |
|---|---|---|---|---|
| Cold start: open + first data (1000 ms) | 19.5 ms | | | pass |
| New bill: product search per keystroke, FTS5 (50 ms) | 1.97 ms | 2.82 ms | 6.3 ms | pass |
| New bill: barcode scan lookup (50 ms) | 0.01 ms | 0.02 ms | 0.3 ms | pass |
| New bill: add an item (price and stock) (50 ms) | 0.02 ms | 0.04 ms | 0.3 ms | pass |
| Product list: next 50 rows by cursor, 20,000 rows deep (50 ms) | 0.55 ms | 1.02 ms | 1.5 ms | pass |
| **Save bill**, one transaction with everything (100 ms) | 1.49 ms | 15.9 ms | 26.0 ms | pass |
| Sales register: first 50 bills (300 ms) | 0.05 ms | 0.07 ms | 0.2 ms | pass |
| Sales register: 50 rows three years back, by cursor (300 ms) | 0.05 ms | 0.17 ms | 0.5 ms | pass |
| Bill search by number prefix / exact number (50 ms) | 0.05 / 0.01 ms | 0.08 / 0.03 ms | 0.5 ms | pass |
| One customer's newest 50 bills (300 ms) | 0.25 ms | 0.41 ms | 0.6 ms | pass |
| One day by date range, cancelled bills only (300 ms) | 0.05 / 0.01 ms | 0.09 / 0.01 ms | 0.4 ms | pass |
| Customer search by name or phone, FTS5 (50 ms) | 0.11 ms | 0.21 ms | 0.4 ms | pass |
| Customers: first 50 with balances (300 ms) | 0.04 ms | 0.06 ms | 0.3 ms | pass |
| Money to collect: top 50 and the totals (300 ms) | 0.04 / 0.12 ms | 0.07 / 0.16 ms | 0.3 ms | pass |
| Customer profile of the heaviest customer, header + unpaid bills + 50 ledger rows (300 ms) | 0.20 ms | 0.47 ms | 2.1 ms | pass |
| Same customer, all **5,741 ledger rows** at once (statement) (300 ms) | 6.2 ms | 21.8 ms | 21.8 ms | pass |
| Dashboard: today, 7 days, month, year from day totals (300 ms) | 0.04 ms | 0.14 ms | 0.4 ms | pass |
| Stock left: first 50 (300 ms) | 0.05 ms | 0.12 ms | 0.4 ms | pass |
| Reports: sales by day for 12 months, from day totals (300 ms) | 0.14 ms | 0.22 ms | 0.35 ms | pass |
| Reports: top 20 products in a year, from product-month totals (300 ms) | 87.9 ms | 90.5 ms | 91.4 ms | pass |
| One product over 5 years from raw lines, indexed (1000 ms) | 1.8 ms | 295.7 ms | 365 ms | pass |
| *For comparison, not used by any screen:* top 20 products by scanning all 5,000,000 lines | 26,404 ms | | | **this is why the summary tables exist** |
| *For comparison:* total of one year by scanning 200,000 bills | 72 ms | | | |

**Backup and restore:** backup with `VACUUM INTO` (compacts and checks while copying) **79 s** for 3.6 GB; plain file copy after a checkpoint **10.6 s**; opening the backup and running `quick_check` (restore verification) **48 s**. Whole-file `quick_check` **42 s**: it runs in the background after the first screen, never before it.

**Archiving a year inside the big file does not work:** the oldest year (199,765 bills) took 1,078 s in 300-bill steps, each step **1.58 s (p95 1.78 s, worst 24.5 s) with the write lock held**, which would stop bills from being saved (budget 100 ms). Shrinking the file afterwards: 17 s in 85 steps of about 250 ms each; the file went from 3,621 MB to 2,961 MB.
**What works instead, year files** (`bin/scale_shards.dart`): a finished year is copied in order into its own file. 196,978 bills: **61 s**, each step 29 ms (worst 120 ms), the live database only read, then 5 s for the indexes. The year file is **571 MB (3,042 bytes per bill)**. Attaching it takes 4.7 ms; a page of bills from a year file p95 0.24 ms; a page that crosses the live file and a year file p95 0.23 ms; one customer's bills across both p95 6.5 ms. Design: data-model.md, "Built for 1,000,000 bills".

**Frame time p95 under 16 ms:** measured in the real app only for the 50,000-product list (above) and the page switches; the database runs off the screen thread in Phase 2, and no query above took more than 91 ms.

**Not verified:**
- **A 4 GB PC with a hard disk.** The numbers are warm-cache numbers from an SSD machine; a cold random read on a hard disk costs about 10 ms, so an indexed lookup that touches 3 to 4 pages should still be about 30 to 40 ms (inside the 50 ms budget but tight) and a page of 50 rows about 100 ms. Saving a bill will cost an extra 10 to 30 ms for the disk flush. Not measured.
- **Android and web storage.** Android's private storage was measured earlier for 50,000 bills only (116 MB), not for 1,000,000. For the **web**, a browser limits what a site may store (the limit differs by browser and by free disk space, and the browser may clear it unless the site is allowed to keep its data). When the browser says it is full, writing a bill fails; the app must then stop saving and say so in plain words. 3.8 KB a bill means 100,000 bills are about 380 MB, so the web version should hold only the recent months. How much the real browsers allow was **not measured**.
- Free-disk checks before a backup or archive are designed (data-model.md) but not built.


## Money to collect, first visit (2026-10-14)
The first visit of Money to collect cost one 41 ms frame (budget 33 ms; the second visit cost 20 ms). About 22 ms of that was work done only once: building the list of 134 customers with ageing and overdue amounts. The app now prepares that list right after the first screen is drawn, while nobody is waiting. **First visit now 18.7 ms (second visit 17.9 ms).** Pass.
Worst frame on the first visit of each page, now: Reports 24.5 ms, Settings 23.1 ms, everything else 9 to 20 ms. All under 33 ms.
The motion test `scan x20 + save` used to compare wall-clock times and failed on a busy computer. It now uses the test's own clock: it checks that 20 scans and a save need no animation time at all, with Off and with Full. It passed twice while another heavy test ran at the same time.


---

# Real repository layer, 1,000,000 bills (Phase 2, Gate 2A, 2026-10-15)
Run with `dart run tool/perf/db_scale.dart 1000000` (the database is a test file and is not committed). It builds a file in the REAL schema (1,000,000 bills over 5 years, 5.0 lines each, 5,000,000 lines and stock movements, 50,000 products with barcodes, 5,000 customers, credit on 10% of bills, every summary table, FTS5, every index) and measures through the same repositories the screens use. SQLite WAL, `synchronous=FULL`; this machine: SSD, 16 threads. **File size 4,362 MB (4.4 GB, 4,577 bytes per bill with all indexes).** Build time 297 s.

| Measure (budget) | p50 | p95 | max | Result |
|---|---|---|---|---|
| Cold start: open + first bills + today (1000 ms) | 16.0 ms | | | pass |
| Start-up: read 50,000 products and 5,000 customers into memory | 431 ms | | | pass (inside the 1000 ms budget) |
| New bill: product search per keystroke, FTS5 (50 ms) | 2.2 ms | 4.2 ms | 16.9 ms | pass |
| New bill: barcode scan lookup (50 ms) | 0.06 ms | 0.14 ms | 0.6 ms | pass |
| Sales register: first page of 50 (300 ms) | 0.43 ms | 0.68 ms | 1.0 ms | pass |
| Sales register: next page, keyset (300 ms) | 0.65 ms | 1.0 ms | 1.8 ms | pass |
| Sales register: a page 900 days back (300 ms) | 59 ms | 62 ms | 65 ms | pass |
| Sales register: search by bill number (300 ms) | 19 ms | 21 ms | 24 ms | pass (was 423 ms before the search was made index-based) |
| Sales register: search by customer name (300 ms) | 19 ms | 21 ms | 21 ms | pass (was 412 ms) |
| Sales register: filter "on credit" (300 ms) | 0.5 ms | 1.0 ms | 1.0 ms | pass (was 484 ms; partial index) |
| Sales register: sorted by amount (300 ms) | 1.0 ms | 1.3 ms | 1.3 ms | pass |
| Home: day totals, to collect, low stock (300 ms) | 27 ms | 28 ms | 28 ms | pass |
| Reports: a year of sales by day (300 ms) | 1.1 ms | 1.1 ms | 1.1 ms | pass |
| Reports: top products of a year (300 ms) | 222 ms | 227 ms | 227 ms | pass, close (was 400 ms; covering index) |
| Reports: top products of the last 30 days (300 ms) | 82 ms | 112 ms | 112 ms | pass |
| Customer profile: whole account, 37 ledger entries (300 ms) | 1.5 ms | 10.7 ms | 10.7 ms | pass |
| Money to collect: 500 biggest balances (300 ms) | 4.2 ms | 5.1 ms | 5.1 ms | pass |
| **SAVE BILL**, one transaction with everything (100 ms) | **1.9 ms** | **12.2 ms** | **213 ms** | p50 and p95 pass; **one save in 400 took 213 ms** (earlier runs: 31 ms and 79 ms); the likely cause is SQLite's automatic WAL checkpoint, not yet proven or tuned |
| Receive payment, one transaction (100 ms) | 2.5 ms | 3.8 ms | 12.5 ms | pass |

Background checks (separate connection, billing carries on): SQLite `quick_check` **7.1 s**; the program's own self-check of every total **21 s** (it was 120 s: two checks were made index-friendly and the slowest, "every bill line has its stock movement", moved to the deep form because a bill is saved with its movements in one transaction). The self-check found 0 problems in the generated file.
**Not verified:** a slower PC (this machine has a fast SSD and 16 threads), the browser (WebAssembly) at this size, a 3-hour continuous billing session.


---

# The slow save: what it was (2026-10-15)
Question: one save in 400 took 213 ms (budget 100 ms) at 1,000,000 bills. Measured with `tool/perf/save_tail.dart` (per-save time, whether the main database file was written during that save = a checkpoint inside it, WAL size), 2,000 to 20,000 saves per run, on the 4.7 GB file unless stated.

| Question tested | Result |
|---|---|
| Is it SQLite's automatic WAL checkpoint? | Partly. A save that contains a checkpoint costs 14.7 ms median (against 1.7 ms) and happens about every 20th save, which is what made the 95th percentile 13 ms. But the 120-210 ms saves were NOT those: of 6 saves over 50 ms in a 10,000-save run only 1 contained a checkpoint. With checkpoints switched off entirely, 4 saves in 3,000 still took 116-176 ms. |
| Cold index pages read from disk? | No. 3,000 random cold lookups in the file: max 10.8 ms, none over 50 ms (`tool/perf/read_tail.dart`). A 200 MB page cache removed the slow saves in one run but 65 MB and 32 MB did not, so the cache is not the cause. |
| Does it depend on the file size? | No. The same slow saves appear with a 220 MB database (1 in 4,000 to 1 in 8,000 back-to-back). |
| Is it the disk flush? | Yes. 20,000 back-to-back saves with `synchronous=FULL`: 5 and 3 saves over 50 ms (up to 193 ms); with `synchronous=NORMAL` (no flush per commit; NOT safe against power cuts): 0 and 1 (max 52 ms). With a person-speed pause between saves (350 ms), FULL: 9 of 1,000 saves over 50 ms, median 5.1 ms; NORMAL: 1 of 1,000, median 0.8 ms. A plain 16 KB write-and-flush loop with no database never stalled (max 10 ms, 18,000 flushes), so it is the flush of the database log on this disk after it has been idle, not the program. |

What was changed: checkpoints now run between saves (`CheckpointPolicy`, `AppDatabase.startControlledCheckpoints`), SQLite's automatic one stays as a net at 4,000 pages. The kill test (200 hard kills, 22,326 bills) was re-run with checkpoints firing constantly: 0 problems.
What cannot be changed without losing the power-cut guarantee: the flush on every commit.

**Re-measured** (4.7 GB file, 1,000,000+ bills, real policy, a 350 ms pause between saves like a person at the counter, 3,000 saves):
| | p50 | p95 | p99 | p99.9 | max | over 50 ms |
|---|---|---|---|---|---|---|
| Before (SQLite checkpoint inside the save), 10,000 saves back to back | 1.7 ms | 13.2 ms | 17.4 ms | 42.9 ms | 204 ms | 6 |
| Before, 1,000 saves with 350 ms pauses (220 MB file) | 5.1 ms | 14.8 ms | 20.3 ms | 197 ms | 197 ms | 9 |
| **After (controlled checkpoints), 3,000 saves with 350 ms pauses** | **5.2 ms** | **6.4 ms** | **15.2 ms** | **179 ms** | **197 ms** | **25 (0.8%)** |
| After, 10,000 saves back to back with 12 ms pauses | 2.8 ms | 4.2 ms | 15.2 ms | 23.7 ms | 199 ms | 3 |

Reading it: the 95th percentile is within budget and halved; the 99th is 15 ms; about 1 save in 120 (0.8%) is held up 120-200 ms by the disk flush, which is over the 100 ms budget and is listed in failure-modes.md (#32). **Not verified:** the shop PC's own disk (a spinning disk would make every save slower, not only the tail).
