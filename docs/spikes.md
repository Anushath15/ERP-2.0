# Phase 0 spike results

Machine: Windows 11, Intel Core i5-12500H, 16 GB RAM, SSD. Date: 2026-10-13. Everything below was actually run unless marked Not verified.

## S1 - Firebase Auth + Firestore
**Passed on Windows, using plain REST calls (Identity Toolkit + Firestore REST) against the Firebase Emulator Suite.** 6 of 6 tests pass (`spikes/s1_rest_sync/test/s1_test.dart`): sign up, verify email, sign in, token refresh, read/write, batch of 500 (1.7 s on the emulator), cursor paging, bad token rejected, plus the security-rules tests listed in failure-modes #23 and #19.

| Target | Result |
|---|---|
| Windows, REST | **Pass** (pure Dart, no native code) |
| Android, REST | **Pass** on an Android emulator (see below) |
| Web (Chrome), REST | **Pass** against the emulator from a browser page (S1b); a Flutter web build compiles (Phase 1 web build) |
| macOS, REST | Same pure-Dart code. **Not verified** (no Mac) |
| Official `firebase_*` SDK on Windows | **Not verified.** Building any Flutter app with native plugins on this PC needs Windows Developer Mode (symlinks); it is still off, and changing it is a system setting only the owner should change. The REST layer needs no plugin |

**Decision (written reason):** build the cloud layer on REST behind `AuthRepository` / `RemoteStore` interfaces. Reasons: it is proven here; it is identical on all four platforms; it needs no native plugin (the Windows C++ SDK is the riskiest piece); and it keeps the sync wire format fully under our control (idempotent commits, our cursor). If the official SDK is later preferred on a platform, only the implementation behind the interface changes.
Google sign-in on REST needs a browser OAuth hand-off (Identity Toolkit `signInWithIdp`); email + password with reset (guaranteed baseline) works now. Google sign-in is Planned for Phase 2 and must be tried on real Firebase (needs the owner's project).

## S2 - Drift/SQLite performance (Windows native, 50,000 bills)
Database 116 MB (5,000 products, 5,000-10,000 customers, 50,000 bills, 200,000 lines, 200,000 stock movements, 50,000 ledger rows). WAL, `synchronous=FULL` (safest) unless noted. Source: `spikes/s2_drift_perf`, results in `results/`.

| Measure | Budget | Result |
|---|---|---|
| Product search per keystroke, FTS5 prefix, 5,000 products | under 16 ms | p50 0.42 ms, p95 1.3 ms, max 3.6 ms |
| Same with 757 products | | p50 0.24 ms, p95 0.5 ms |
| Customer search (10,000) | | p95 0.3 ms |
| Barcode lookup | | p95 0.6 ms (scan, add an index in the real schema) |
| Bill list page (50 rows, joined, deep offsets) | under 300 ms | p50 16 ms, p95 45 ms |
| Save bill (1 transaction, 4 lines, 4 movements, ledger, outbox) | under 150 ms | p50 3.6 ms, p95 7-20 ms, worst 290 ms once (first WAL checkpoint) |
| 30-day sales by day | | 9 ms |
| Customer balances, all 10,000 | | 240-280 ms |
| **Stock of all products from movements (200,000 rows)** | | **1.3-2.1 s** |
| **Top 20 products over 200,000 lines** | | **1.4-2.2 s** |
| Inventory page of 50 with live stock sub-query | | 58-336 ms |
| `quick_check` / `integrity_check` | | 0.3 s / 2.6-4.4 s |
| Bulk seed 50,000 bills | | 13-18 s |

**Findings that change the design:**
1. Whole-table aggregates take 1-2 s and are over the 100 ms UI budget. Therefore: a cached `stock_cache` table updated in the same save transaction (rebuildable, checked nightly), and big reports run in a background isolate with a progress bar.
2. `COUNT(*)+1` for invoice numbers is O(n); use a counter row per series.
3. Start-up check uses `quick_check` (0.3 s), not `integrity_check` (up to 4.4 s, run weekly or from the Health page).
4. The worst save (290 ms) is a one-off WAL checkpoint; set `wal_autocheckpoint` and checkpoint on idle.

Android emulator: see the section at the end (pass). A true low-end phone and Web (WASM + OPFS): **Not verified**.

## S3 - Printing
- A4 invoice, 80 mm and 58 mm receipts generated from the `pdf` package (pure Dart): A4 with 26 lines 220-280 ms, 80 mm 50-60 ms, 58 mm 20 ms. Wrapping of long names, Indian digit grouping, Code128 barcode: **Pass** (viewed in the browser pane).
- **Non-Latin text:** the `pdf` package does not shape complex scripts. This no longer matters: the owner decided the software is English only (Latin letters, digits, the rupee sign and punctuation). A test checks that the rupee sign and common punctuation print correctly.
- Real printer: an "HP Smart Tank 580-590 series" is attached to this PC but **nothing was printed** (no test page was sent without the owner's say-so). Real 80 mm thermal printer: **Not verified**.

## S4 - Sync chaos (emulator, `test/s4_chaos_test.dart`)
5 of 5 tests pass:
| Test | Result |
|---|---|
| S4-1: 2,500 records, 15% requests lost, 15% replies lost (duplicate delivery), 5% process kills with the engine rebuilt from the file | No loss, no duplicates; a new device restores all 2,500 with 2,506 reads; 77 calls, 9 lost replies, 3,100 writes (24% overhead) |
| S4-2: 1 poisoned record in a batch of 500 | Found by splitting; 499 delivered, 1 in Needs attention |
| S4-3: offline with 5,000 changes, then online | 5,000 uploaded in 5.3 s, exactly 5,000 writes |
| S4-4: two devices edit one product, one clock two days ahead | Converged; loser kept in history; clock warning raised on the skewed device |
| S4-5: two devices bill 300 each at once with failures | 600 bills, unique numbers, both devices identical |

Bugs found and fixed by the spikes: (a) timestamp-only pull cursor skipped documents of a 500-batch; (b) a re-sent append-only record was rejected by the rules and failed the whole batch (rules now allow a re-stamp); (c) the emulator answers 500 for a rejected multi-write batch, which looked retryable forever (now split after 2 attempts); (d) `getAfter()` is needed in the rules when the shop and its owner row are created in one batch.

## Final stack (from this evidence)
Flutter + Riverpod + go_router; Drift on SQLite with FTS5 (native; WASM on web, to be proven); REST cloud layer behind interfaces; `pdf` package for printing; Firebase Emulator Suite for all tests.

## S1b - Browser (Chrome) check of the REST layer (2026-10-13)
Run from a page in Chrome (the in-app browser) against the emulator, from a different origin than the servers: Auth sign-up, send-verification, verify, token refresh all **200**; Firestore commit (with `Authorization` header, so a CORS pre-flight), get and runQuery all **200**; cross-origin responses were readable. **Pass against the emulator.** Not verified: the real production endpoints from a browser (CORS on `firestore.googleapis.com` REST and `identitytoolkit.googleapis.com` is expected to work but needs the real project), and a Flutter web build (needs Developer Mode).

## S4b - Convergence (2026-10-13, `test/s4_convergence_test.dart`)
Two devices work offline (opening stock, 150-167 bills, purchases, adjustments, payments), sync in random order with 20% dropped requests, 20% lost replies and **delayed duplicate re-sends of old batches** (8-19 per run). Final check: both devices derive **identical stock per product, balance per customer, sales total and bill count**; a third fresh device restoring from the cloud gets the same numbers; no invoice number repeats. **3 of 3 seeds pass.**

## Android emulator results (2026-10-13)
Emulator: Android 15 (API 35, Google APIs, x86_64), 2 CPU cores, 1.5 GB RAM, hardware-accelerated by Windows (WHPX), release build. This is **not** a throttled low-end ARM phone (see "Not verified").

**S2 on Android** (same 50,000-bill database, `synchronous=FULL`, 5,000 products, 5,000 customers): product search per keystroke p50 0.29 ms, p95 1.08 ms, max 6.5 ms (budget 16 ms); save bill p50 2.9 ms, p95 5.6 ms, max 25 ms (budget 150 ms); bill list page p95 21.7 ms (budget 300 ms); stock of all products 232 ms; top 20 products 233 ms; customer balances 72 ms; `quick_check` 151 ms; database 116 MB. **Pass**, comfortably, on the emulator. Real phone flash storage and a real low-end CPU will be slower: **Not verified**.

**S1 on Android** (sign-in and sync over the REST layer to the Firebase emulator on the host, `s1_android`): sign up + verify e-mail + token refresh 710 ms; create shop HTTP 200; push 600 bills in batches of 100: 4.4 s, 0 left in the outbox, 600 server writes; a fresh device pulls all 600 in 0.8 s with 601 reads; **both devices identical. Pass.** Real Firebase over a real mobile network: Not verified.
