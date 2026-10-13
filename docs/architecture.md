# Architecture

## Shape
One Flutter app (Windows, macOS, Android, Web). Feature-first folders; three layers per feature:

```
lib/
  core/            money, ids (UUIDv7), clock (HLC), result/error types, l10n, theme tokens
  features/<name>/ domain/ (pure Dart, NO Flutter imports)  data/ (Drift DAOs, repositories)  presentation/ (widgets, Riverpod providers)
  sync/            outbox, engine, quota guard, RemoteStore (REST) interface + implementations
  platform/        printing, scanner, file picker, backup, per-OS paths (behind interfaces)
```
- **State:** Riverpod. **Routing:** go_router with deep links. **DB:** Drift on SQLite, WAL, foreign keys on, indexes for every list and search, FTS5 for products. Native on Windows/macOS/Android, WASM + OPFS/IndexedDB on web (to be proven in Phase 2).
- **Off the UI thread:** sync, import, big reports, PDF building run in isolates. Normal reads/writes are fast enough to run on the main isolate (S2: save p95 under 20 ms); the DB is opened in a background isolate so a slow query can never freeze a frame.
- **Single source of truth:** the local DB. The UI never waits for the network.
- **Domain package:** `packages/erp_domain` (money, GST, stock, ledger, numbering, cancel/return/convert rules) tested alone with property-based tests.

## Why not Firestore alone
Reports, ledgers and 50,000+ bills need fast SQL joins offline (S2 numbers). Firestore is only the backup and multi-device sync copy.

## Cloud
Firebase Spark: Auth (email/password + Google) and Firestore. No Functions, no Storage, no billing account. Cloud access goes through `AuthRepository` and `RemoteStore` interfaces; the implementation is plain REST (spike S1 decision), so no native Firebase plugin is needed.

## Printing and scanning
`pdf` + `printing` for A4, 80 mm, 58 mm, preview and save-as-PDF. Barcodes generated in Dart. Keyboard-wedge scanners on desktop (they type, Enter ends the code); `mobile_scanner` on Android. Direct ESC/POS and Bluetooth printers: after v2.0.

## Import / export
`excel` package for xlsx, CSV, PDF reports. ERP 1.0 importer (see PRD) reads a backup path given by the owner, dry-run first.

## Text
All visible text is English and lives in one file (`tool/strings.txt`, turned into `lib/strings.dart` by `tool/gen_strings.dart`). Names and notes a person types are stored and shown exactly as typed; nothing is translated. Fonts: Inter (default) and Atkinson Hyperlegible, bundled so the app needs no downloads (SIL Open Font License).

## Build and CI
GitHub Actions: analyze, test, build Windows, Android, Web, macOS (unsigned). Config files with Firebase keys come from GitHub secrets, never from the repo.
