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

## Gate 2E - the sync loop (built 2026-10-19)
Code: `lib/data/sync/` (triggers, engine, API interface), `lib/core/cloud/http_sync_api.dart` (Supabase `push_docs` / `pull_docs` over HTTPS), `lib/core/cloud/sync_controller.dart` (timer every 20 s, "Sync now", status for the chip and the Settings card). SQL: `supabase/migrations/0002_sync_names.sql`, tested by `supabase/tests/sync_test.sql`.
- **Capture:** database triggers (made at every open, `sync_triggers.dart`) put every inserted or changed row of 21 tables (plus the shared settings `shop.profile`, `valuation.rule`) into the `outbox`. Collection name = table name. Derived tables (stock, balances, day totals, month totals, party_bills) never travel: after documents arrive the program rebuilds them (`rebuildSummaries`).
- **Push:** batches of 100 in outbox order; a batch the cloud refuses is split until the one bad document is alone and marked "needs attention"; no internet = rows wait. A row edited again while a batch is in flight stays queued.
- **Pull:** from the saved position (`sync_meta.pull_cursor`), one transaction per page of 300 with the new position; rows the cloud sends back that this computer already has change nothing; a document with an unsent local change is left alone.
- **Rules:** never-changing rows (lines, movements, ledger entries, payments, returns, cancellations, reminders, audit) are insert-or-ignore; edited rows (products, customers, dealers, categories, estimations, records, bills, purchases, estimation lines, settings) are last-writer-wins by version stamp (`hlc` column, or `sync_rev` for tables without one).
- **First time:** everything already in the database is queued once (`sync_meta.backfilled`). A second computer starts empty and pulls.
- **Known limits (not hidden):** (1) two computers that both made bill number X offline: the arriving copy keeps the number with a 4-letter computer suffix, nothing is lost; the owner should give each computer its own series letter. (2) Estimation lines removed during an edit are not removed on other computers. (3) Other computers' screens show new data after **Reload** (a banner offers it); the totals are rebuilt at once. (4) A deleted record is not synced (nothing is hard-deleted in this program). (5) Tested against an in-memory cloud and a local Postgres 17, NOT yet against the real Supabase project.

## Counter link over the shop Wi-Fi (built 2026-10-19, schema v10)
Two or more billing counters exchange changes directly, with no internet. Code: `lib/data/sync/lan_link.dart`, `lib/core/lan/` (key + locking, transport, controller), card in Settings > Counter link.
- Each counter listens on port 47321 while "Link my counters" is on. The first counter makes a shop key (64 hex digits); the other counters type that key once, then type the first counter's address (Wi-Fi IP, shown on its card) and press Link. Linking is two-way: the other counter remembers this one too.
- Every message is locked with AES-256-GCM using the key (a computer without it is refused with 401; a changed or old message is refused). It travels over plain HTTP inside the shop network.
- Each linked counter has its own upload queue (`outbox.chan = 'lan-<id>'`, filled by the same triggers; payments wait 10 s). The same engine sends it, in batches, with offline retry. The receiver applies with the same rules as cloud documents (append-only keep, edited rows newest-wins) and rebuilds totals. Cloud and Wi-Fi can run together: a document that arrives by both ways is applied once and the second copy changes nothing.
- A newly linked counter first receives everything the other one has (one-time backfill per counter).
- Limits: addresses are typed by hand (a changed router address must be edited: unlink and link again); Windows may ask to allow the program on the private network; not available in the browser build; tested with two in-memory counters, a pretend Wi-Fi and real loopback sockets, not yet with two real computers.
