# Test plan

| Layer | What | Tool | When |
|---|---|---|---|
| Domain | money, GST, stock, ledger, numbering, cancel, return, convert estimation; property-based tests for money and GST (1-paise edges, decimal quantities, 0% and 28%, mixed carts) | `test` + `glados`/own generators | Phase 2 first |
| Data | DAOs and repositories on in-memory SQLite; migrations on a copy; backup/restore verify | `test`, Drift | Phase 2 |
| Sync | outbox, push, pull, chaos, clocks, quota guard; security rules | Firebase Emulator Suite | Phase 0 (done for S1/S4), Phase 2-3 |
| UI | widget tests; golden tests for key screens (billing, estimations, product picker, dashboard) in dark and light, at text sizes 80% to 200%, desktop and phone widths | `flutter test` | Phase 1 on |
| Integration | Windows: billing flow, estimation edit, backup/restore, offline/online switch | `integration_test` | Phase 2-3 |
| Performance budgets (as tests) | cold start, 100 ms action cap, search 16 ms at 5,000 products, save 150 ms, lists 300 ms at 50,000 bills, flat memory in soak | custom harness; baseline from S2 | Phase 3 |
| Failure table | every row of failure-modes.md as a real test (crash at every step, kill -9 loops, disk full, corruption, clock) | | Phase 3 |
| Soak | 8 simulated hours of billing, navigation and sync, memory sampled | | Phase 3 |
| Accessibility | contrast over every theme x accent x high-contrast combination (40 tests, 4.5:1 / 7:1), semantics labels, text size 80-200% | | Phase 1 and 3 |
| Text-size matrix | every screen (37) x text 80/100/125/150/200% x desktop, tablet, phone widths x dark/light: no layout error; billing footer pinned with 1/10/100 lines at every size | `flutter test` | Phase 1 (done) |
| Motion | Off / Gentle / Full behaviour, system reduce-motion, no added delay for scan/save/typing, skeleton after 150 ms, sync pulse only while syncing, auto-protect guard | `flutter test` + profile-build frame timing (`tool/perf`) | Phase 1 (done) |

Definition of done for a feature: code, tests, both themes, text sizes up to 200%, phone and desktop layouts, plain-words errors, docs.
Reporting rule: only what was actually run; the rest is listed under "Not verified".
