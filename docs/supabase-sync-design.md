# Supabase sync design (replaces Firestore for sync; owner decision 2026-10-16)

Aim: maximum free software. Every shop PC keeps the full database locally (SQLite, works offline); Supabase is the free shared cloud copy. Firebase is used only for Hosting. Everything in [sync-design.md](sync-design.md) about the outbox, coalescing, idempotent UUIDv7 ids, hybrid logical clocks, append-only versus last-writer-wins and the status line still holds. Only the transport changes.

## Mapping
| Firestore plan | Supabase plan |
|---|---|
| Document in a collection | Row in `sync_docs (shop_id, coll, id, data jsonb, hlc, deleted, seq)` |
| Security rules | Row-level security (read) plus `push_docs` checks (role, revoked device, append-only, 100 per batch) |
| Atomic commit of 100 docs | One call to `push_docs` (a single transaction) |
| Cursor (serverAt, id) | Cursor = `seq`; pushes take a per-shop lock so seq order equals commit order and nothing is skipped |
| Daily commit caps, read quota | Not needed: no per-read billing; the limits are 500 MB, 5 GB egress a month and 2 projects |
| Device revoke document | `devices.revoked` (checked on every push; the owner switches it) |

Files: `supabase/migrations/0001_sync.sql` (tested on a throwaway local PostgreSQL 17 with `supabase/tests/sync_test.sql`: 14 checks pass plus 8 must-fail checks; not yet run on the real Supabase project).

## Free-plan facts to design around (verify on the Supabase pricing page when creating the project)
- **A free project pauses after about 7 days without activity.** The app calls `ping()` on every sync, and `.github/workflows/supabase-keepalive.yml` pings twice a week as a net. A paused project is restored from the dashboard; no data is lost.
- **No automatic backups on the free plan.** The Gate 2C local backups are the real safety net, and the app should also be able to export a full SQL/JSON dump to a pen drive.
- **500 MB database.** One real shop with 2 bills a day is far below this; a table of rows per synced collection is stored once (no derived stock or ledger rows, per decision 2 in PROGRESS.md).
- **Row-level security stays on for every table.** The public anon key is allowed to call only `ping()`.

## Scope (owner decision 2026-10-17)
For now **only the owner's father's shop**. One shop row, two Owners, no public sign-up, no premium plan. Selling to other shops is a later decision (the tables already carry `shop_id`, so it stays possible).

## Sign-in (Gate 2D): e-mail and password, once, stays signed in
- Supabase Auth with **e-mail and password** (no Google sign-in: decided). The owner signs in one time on each computer.
- The session (refresh token) is kept encrypted for this Windows user (DPAPI) in this computer's own folder and renewed quietly. **Opening the program never asks for sign-in again**; with no internet the kept sign-in is trusted. It asks only after **Sign out**, or if the cloud cancels the session.
- Only the shop's member addresses get access: a new account has no `shop_members` row, so the program signs it straight out and row-level security shows it nothing.

## Open before Gate 2E
1. Run the migration on a throwaway local Postgres and write the SQL tests (cashier blocked, revoked device blocked, re-send is a no-op, older hlc loses, 101 docs refused).
2. Match `coll` names to the app's outbox names.
3. REST client in Dart (plain HTTP to `/rest/v1/rpc/push_docs`, no plugin, as before).
