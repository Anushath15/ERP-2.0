# Test plan

| Layer | What | Tool | When |
|---|---|---|---|
| Domain | money, GST, stock, ledger, numbering, cancel, return, convert estimation; property-based tests for money and GST (1-paise edges, decimal quantities, 0% and 28%, mixed carts) | `test` + `glados`/own generators | Phase 2 first |
| Data | DAOs and repositories on in-memory SQLite; migrations on a copy; backup/restore verify | `test`, Drift | Phase 2 |
| Sync | outbox, push, pull, chaos, clocks, quota guard; security rules | Firebase Emulator Suite | Phase 0 (done for S1/S4), Phase 2-3 |
| UI | widget tests; golden tests for key screens (billing, estimations, product picker, dashboard) in EN/TA, dark/light, desktop/phone widths | `flutter test` | Phase 1 on |
| Integration | Windows: billing flow, estimation edit, backup/restore, offline/online switch | `integration_test` | Phase 2-3 |
| Performance budgets (as tests) | cold start, 100 ms action cap, search 16 ms at 5,000 products, save 150 ms, lists 300 ms at 50,000 bills, flat memory in soak | custom harness; baseline from S2 | Phase 3 |
| Failure table | every row of failure-modes.md as a real test (crash at every step, kill -9 loops, disk full, corruption, clock) | | Phase 3 |
| Soak | 8 simulated hours of billing, navigation and sync, memory sampled | | Phase 3 |
| Accessibility | contrast over tokens, semantics labels, 125/150% scaling goldens | | Phase 1 and 3 |

Definition of done for a feature: code, tests, both languages, both themes, phone and desktop layouts, plain-words errors, docs.
Reporting rule: only what was actually run; the rest is listed under "Not verified".
