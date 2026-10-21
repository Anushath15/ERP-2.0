# Architecture audit of ASK ERP 2.0 (21 Oct 2026)

The 113 ideas the owner listed, checked against the code. "Have" means it is in the program and (where it can be) tested; "Partly" says what is missing; "Not needed" is a choice, not a lack.

**Have 73, Partly 30, Missing 5, Not needed 5.**

## What is worth doing next (for a hardware shop, not for the sake of the list)

1. **Local diagnostics (100, 111).** A log of the program's own events with no customer data in it, and a "Send diagnostics" button on Settings that makes one small file. The printer fault on the shop PC needed someone to dig through the Windows log; this makes it one click.
2. **Exponential backoff for sync, the counter link and Telegram (40, 41).** Today a failing cloud is asked every 20 seconds forever. Waiting longer after each failure saves battery, the free Supabase quota and log noise.
3. **Estimate numbers per computer (69).** Two computers both start estimates at EST-00001. The numbers no longer fail to save, but they can look the same on two papers; give each computer its own letter like bills have.
4. **Removed estimate lines reach the other computer (45).** Editing an estimate and removing a line does not remove it on the other computer.
5. **A sync problems list (47).** Settings > Sync shows the count of documents set aside as "needs attention" but not which ones or why; show them with the reason and a Retry button.

Not recommended now: a re-layout into feature folders (no benefit for the shop, real risk of breaking a working program), multi-branch, plugins, multi-tenant, double-entry books.

| # | Idea | Status | Evidence or what is missing |
|---|---|---|---|
| 1 | Layered Architecture | Have | lib/domain (pure rules), lib/data (database + repositories), lib/features (screens), lib/design (widgets), lib/core (services) |
| 2 | MVC | Not needed | Not used by name; Riverpod notifiers play the controller role |
| 3 | MVVM | Partly | Notifiers (CartNotifier, SyncController...) are the view-models; some screens still hold logic in the widget |
| 4 | Repository Pattern | Have | lib/data/repo/*: BillRepo, CatalogRepo, LedgerRepo... |
| 5 | Service Layer Pattern | Partly | PrinterService, SyncEngine, LanLink, TelegramBackup; billing rules live in the repos |
| 6 | Dependency Injection | Have | Riverpod providers; tests override the printer, saver, cloud, clock |
| 7 | SOLID Principles | Partly | Interfaces for printer, sync API, transport; a few very large widget files |
| 8 | DRY Principle | Partly | Shared widgets and strings; some long screens repeat layout code |
| 9 | Separation of Concerns | Have | Pure domain code has no Flutter or database imports (checked by tests) |
| 10 | State Management | Have | Riverpod |
| 11 | Routing and Navigation | Have | go_router with a sign-in gate |
| 12 | Cursor-Based Pagination | Partly | Bill lists page by keyset; product and customer lists are held in memory |
| 13 | Lazy Loading | Partly | Lists build rows on demand; reports read on demand |
| 14 | Eager Loading | Partly | Bootstrap loads products, customers, accounts before the first screen |
| 15 | Database Indexing | Have | Indexes on every list and lookup in schema.drift |
| 16 | Full-Text Search (FTS5) | Have | product_fts: name, barcode, code, brand, category |
| 17 | Debouncing | Partly | Search boxes; not every input |
| 18 | Caching | Have | stock_cache, party_balance, day_totals, product_month (rebuildable) |
| 19 | Virtualized Lists | Have | ListView.builder on bill lines, product lists |
| 20 | Background Processing | Partly | Import and backup run in an isolate; sync on a timer |
| 21 | Query Optimization | Have | docs/perf-results.md (measured) |
| 22 | Connection Management | Have | WAL, busy timeout, checkpoint policy in app_database.dart |
| 23 | Performance Profiling | Have | docs/perf-results.md, frame guard |
| 24 | Database Normalization | Have | Documents, lines, ledgers, movements in separate tables; summaries are derived |
| 25 | Primary Keys and Foreign Keys | Have | Every table has ids; references declared |
| 26 | ACID Transactions | Have | Bill, stock, ledger, outbox in one transaction; 200 kill tests |
| 27 | Database Constraints | Have | Unique numbers, idempotency keys, NOT NULL, checks |
| 28 | Database Migrations | Have | Numbered steps, schema dumps, migration tests (v1 to v10) |
| 29 | Soft Delete | Have | deleted_at; nothing is hard-deleted |
| 30 | Append-Only Ledger | Have | Ledger entries, stock movements, returns, cancellations |
| 31 | Audit Logging | Have | audit table (price, cost, cancellations...) |
| 32 | Idempotency | Have | idem_key on bills, returns, purchases |
| 33 | Optimistic Concurrency Control | Partly | version + hlc, newest wins; no "someone else changed this" screen |
| 34 | Database Integrity Checks | Have | quick check at start, weekly full check, daily self-check of summaries |
| 35 | Backup and Restore | Have | Daily, on close, locked Telegram copy, restore screen |
| 36 | Data Archiving | Partly | Yearly backup archive; old rows are not moved out of the database |
| 37 | Offline-First Architecture | Have | The shop PC works with no internet |
| 38 | Local-First Architecture | Have | SQLite per computer, cloud is a copy |
| 39 | Transactional Outbox Pattern | Have | outbox rows made by triggers in the same transaction |
| 40 | Exponential Backoff | Missing | Sync retries every 20 seconds, always the same delay |
| 41 | Retry Mechanism | Partly | Retries forever on a timer; a refused document is set aside as "needs attention" |
| 42 | Conflict Resolution | Have | Append-only keep, last-writer-wins by stamp, number suffix |
| 43 | Hybrid Logical Clock (HLC) | Have | lib/data/hlc.dart |
| 44 | Synchronization Cursors | Have | sync_meta.pull_cursor |
| 45 | Tombstones | Partly | Soft-deleted rows sync as edits; a line removed from an edited estimate does not |
| 46 | Quota Management | Partly | Limits documented; the app does not meter Supabase use |
| 47 | Sync Status Tracking | Have | Top-bar badge, Settings > Sync, outbox counts |
| 48 | Device Identity Management | Have | device.id per computer, series letter registry |
| 49 | Data Reconciliation | Have | rebuildSummaries, self-check, import reconciliation |
| 50 | Authentication | Have | Supabase e-mail and password, kept sign-in |
| 51 | Role-Based Access Control (RBAC) | Have | Owner, manager, cashier in the app and in the cloud function |
| 52 | Least Privilege Principle | Have | Cashier cannot change products; only the owner cancels bills (SQL-tested) |
| 53 | Record-Level Authorization | Partly | Per shop (row-level security); not per record |
| 54 | Input Validation | Have | validators.dart, safe JSON, sheet parsing |
| 55 | Secrets Management | Have | DPAPI vault for the sign-in, PIN and Telegram token |
| 56 | Database Security Rules | Have | Row-level security and supabase/tests/sync_test.sql |
| 57 | Session Management | Have | Token refresh, sign out, cancelled sessions |
| 58 | Data Encryption | Partly | Locked backups, encrypted vault, counter link; the database file itself is not encrypted |
| 59 | Supply-Chain Security | Partly | Dependabot, pinned versions; no signing of the installer |
| 60 | Checksums and Build Attestation | Partly | Release workflow attests builds; installers made here are unsigned |
| 61 | Domain-Driven Design (DDD) | Partly | lib/domain holds the rules, but there are no formal aggregates |
| 62 | Integer-Based Money Representation | Have | Paise everywhere |
| 63 | Fixed-Precision Quantities | Have | Thousandths |
| 64 | GST Calculation and Rounding | Have | bill_calc.dart; IGST (other state) is not built |
| 65 | Stock Movement Ledger | Have | stock_movements; the figure is a sum |
| 66 | Customer Ledger | Have | ledger_entries |
| 67 | Dealer Ledger | Have | Same ledger, dealer side |
| 68 | Double-Entry Accounting | Not needed | A single-entry ledger with reversals; a shop does not need debit and credit books |
| 69 | Invoice Numbering and Series Management | Have | Per computer letter, gapless counters; estimates have one shared series (see gaps) |
| 70 | State Machine Pattern | Partly | Purchase pending/received, bill cancelled; not formalised |
| 71 | Reversing Entries | Have | Cancellations, returns, write-offs |
| 72 | Credit Limit Management | Have | credit_limit_paise per customer |
| 73 | Financial Reconciliation | Have | self_check.dart |
| 74 | Property-Based Testing | Partly | Randomised kill and money tests; no property-testing library |
| 75 | Business Rule Validation | Have | Warnings and blocks (stock, credit, margin, MRP) |
| 76 | Component-Based UI | Have | Flutter widgets, lib/design |
| 77 | Responsive UI | Have | Desktop, tablet, phone layouts tested at 80 to 200 percent text |
| 78 | Adaptive UI | Have | Different layouts per width |
| 79 | Design System | Have | tokens.dart, widgets.dart, docs/design-system.md |
| 80 | Keyboard-First Workflow | Have | Billing screen shortcuts |
| 81 | Form Validation | Have | Form sheets with field checks |
| 82 | Loading States | Partly | Splash, spinners; not on every list |
| 83 | Empty States | Have | Empty titles and help on lists |
| 84 | Error States | Have | Banners, plain messages, damaged-file screen |
| 85 | Accessibility | Have | Semantics, contrast tests, text size matrix |
| 86 | Confirmation Dialogs | Have | confirmDialog |
| 87 | PDF Preview and Printing | Have | Print page, direct print with Windows-window fallback |
| 88 | CSV Import and Export | Have | Export page; CSV accepted in the product sheet |
| 89 | Excel Import and Export | Have | Export page; Products > Excel fill-in |
| 90 | Localization and Internationalization | Partly | All text in one generated file, English only |
| 91 | Unit Testing | Have | test/domain, test/data |
| 92 | Integration Testing | Have | Repository tests on real SQLite |
| 93 | Widget Testing | Have | Screens in test/*.dart |
| 94 | End-to-End Testing | Partly | Browser user-journey runs were done by hand; not in CI |
| 95 | Regression Testing | Have | 929 tests, golden images |
| 96 | Concurrency Testing | Partly | Two-computer sync and LAN tests; no stress test of simultaneous saves |
| 97 | Crash and Interrupted-Write Testing | Have | tool/kill_test (200 kills) |
| 98 | Performance Benchmarking | Have | docs/perf-results.md |
| 99 | CI/CD | Have | .github/workflows ci.yml, release.yml |
| 100 | Structured Logging | Missing | The app writes no log at all (a test forbids print, to protect customer data) |
| 101 | Backup Verification | Have | Restore is checked before it replaces data |
| 102 | Disaster Recovery | Partly | Restore, cloud copy, docs/failure-modes.md; never rehearsed on a second computer |
| 103 | Feature Flags | Missing | Settings switches only |
| 104 | Background Scheduling | Have | Sync timer, daily backup, evening Telegram send |
| 105 | Advanced Analytics | Partly | Reports page; no trends or forecasting |
| 106 | Event-Driven Notifications | Partly | In-app banners and toasts; no push |
| 107 | Multi-Branch Inventory Management | Not needed | One shop |
| 108 | Plugin Architecture | Not needed | Not needed |
| 109 | API Versioning | Partly | Counter link /lan/v1; cloud functions unversioned |
| 110 | Database Compaction and Archiving | Partly | WAL checkpoint; no vacuum schedule, no archive |
| 111 | Observability | Missing | No metrics, no diagnostics bundle |
| 112 | Differential Backups | Missing | Every backup is a full copy (a shop file is a few MB) |
| 113 | Multi-Tenant SaaS Architecture | Not needed | shop_id exists in the cloud, but this is one shop |
