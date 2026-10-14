# Sync design

Proven by spikes S1 and S4 (see [spikes.md](spikes.md)). Prototype code: `spikes/s1_rest_sync`.

## Principles
1. The local SQLite database is the only thing the UI reads and writes. The UI never waits for the network.
2. Every local change and its **outbox entry are written in the same transaction**. Editing the same record again before it is uploaded replaces the pending entry (coalescing; tested: 100 products edited 1,200 times = 100 uploads).
3. Uploads are idempotent: ids are client-made UUIDv7, so a duplicate or re-ordered delivery changes nothing.
4. The cursor for downloads is saved in the same transaction as the downloaded rows.

## Push
- When: app start, network back, every 10 min (setting), app close, "Sync now".
- Reachability: a real request to the project (a tiny read of the shop document), not just "wifi connected". Offline = no calls.
- Batches of up to **100** documents in one atomic commit, oldest first (changed from 500 by the security hardening: the rules count commits per person per day; see `lib/domain/sync/batch_plan.dart` and docs/threat-model.md finding 9). A batch is sent when 100 are waiting, when the oldest change has waited 90 minutes, or when forced (Copy now, app closing, internet back), not on a fixed 10-minute tick. After a successful commit, outbox rows are removed only if the record was not edited meanwhile (compared by stamp).
- Failure kinds:
  - Network / 429 / 5xx: rows stay pending, `attempts+1`, exponential backoff with jitter (1 s doubling to 5 min). The same batch is retried.
  - Permanent rejection (rules deny, document too big): the atomic batch is **split in halves recursively** until the single bad record is found; it goes to **Needs attention** with a plain-words reason; the other 499 are delivered. Tested: S4-2.
  - A 5xx that repeats twice for a multi-record batch is treated like a rejection and split (the Firestore emulator answers 500 for a rejected batch; found by test).
- Crash after the server accepted a batch but before the local ack: on restart the batch is sent again; the rules accept an append-only re-send as "only the server stamp changes". Tested with kills (S4-1).

## Pull
- Per collection, query `orderBy(serverAt, __name__)`, `startAfter(cursor)`, page 300. **The cursor is the pair (serverAt, id)**: a batch of 500 documents shares one timestamp and a timestamp-only cursor skips documents (bug found by test S1, fixed).
- `serverAt` is a server timestamp stamped by the commit (`REQUEST_TIME` transform), so the device clock is never used for the cursor.
- No always-on listeners: pull on the same triggers as push. (A listener would be a convenience for the owner's phone; off by default, optional later.)
- Applying a page: append-only records are inserted if missing and never changed. Editable records are merged by last-writer-wins (below).

## Clocks and conflicts
- Each edit gets a hybrid logical clock stamp `physicalMs-counter-deviceId`. Receiving a newer stamp moves the local clock forward, so the next local stamp is always later than anything seen.
- Append-only (bills, payments, adjustments, ledger, audit): cannot conflict. Invoice numbers are per-device series (`A-000123`), so two devices never create the same number.
- Editable master data (products, customers, dealers, categories, shared settings, estimations): last writer wins by stamp. The losing version is stored in `history` and shown in the audit view. Tested: S4-4 (two devices, one with a clock two days ahead; both converge; loser kept).
- Wrong clock: after every commit the server's commit time is compared to the device clock. More than 5 minutes apart shows a calm warning "This computer's date or time looks wrong". A device with a clock far ahead would win edit conflicts on master data until fixed, which is why the warning exists (and master-data conflicts are rare in one shop). Future refinement: correct stamps with the learned server offset.

## Status shown to the user (always visible)
Synced (green) / Syncing / Offline - saved on this PC / Needs attention (n), plus "last synced at 4:35 pm".

## Not synced, ever
Per-device settings: printer, paper size, theme, font size, window state, start page, app-lock PIN, quota counters, sync cursors. They live in a local-only table and are never part of backup-restore of shop data.

## Device removal
No Cloud Functions means no server-side revoke of one device. Options, in order: (1) owner marks a device "revoked" in the shop (a document the rules check on every write: that device can no longer write); (2) "Sign out everywhere": owner changes the account password, which ends all refresh tokens; (3) owner removes a staff member's email. Reading by a revoked device whose token is still valid continues until the token expires (up to 1 hour) and the refresh then fails. See threat-model.md.
