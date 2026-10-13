# Free-plan budget (Firebase Spark)

Limits checked against the official page <https://firebase.google.com/docs/firestore/quotas> on 2026-10-13:

| Resource | Free limit | Note |
|---|---|---|
| Stored data | 1 GiB | |
| Document reads | 50,000 / day | resets about midnight Pacific time (about 12:30 pm India time) |
| Document writes | 20,000 / day | |
| Document deletes | 20,000 / day | we never hard-delete (soft delete = a write) |
| Outbound transfer | 10 GiB / month | |
| Document size | 1 MiB | our documents are 1-4 KB |
| Rules `get()/exists()` | 20 per batched write, 10 per single request | cached paths do not count again |

Auth: email/password and Google are free. Phone/SMS is not free and is never used. Hosting, Cloud Functions, Storage: not used (Hosting only if the owner wants the web app online).

## What is stored in the cloud (this decides the budget)
One document per business record. Bill lines and bill payments are **embedded in the bill document**. Stock movements and ledger entries that follow from a bill are **not uploaded**; every device derives them from the bill. Only events that cannot be derived are separate documents (stock adjustments, opening stock, later payments, expenses, purchases with embedded lines).

## Daily budget for a shop with about 150 bills a day
| Activity | Writes | Reads |
|---|---|---|
| 150 bills (1 doc each, some edited/cancelled: +15) | 165 | 0 |
| 40 later payments, 20 purchases, 20 expenses, 30 adjustments | 110 | 0 |
| Master data edits (products, customers) | 150 | 0 |
| **Normal day total** | **about 425** | |
| **Worst day: 2,000 changed rows** | **2,000** | |
| Rules lookups (about 2 per upload batch; 1 upload every 10 min) | | about 300 |
| Second device pulling the same changes | | 425 normal / 2,000 worst |
| Third device (phone) | | same again |
| **Reads, 3 devices, worst day** | | **about 6,300** |

Normal use is about 2% of the write limit and under 5% of the read limit. Sync is batched (up to 500 writes per commit) every 10 minutes, so rules lookups stay small.

## First-time restore on a new device
Measured in spike S4: restoring 2,500 documents cost 2,506 reads (1.002 reads per document).
- 757 products + about 5,000 customers + 200 dealers + 12,600 bills (each with embedded lines) + about 3,000 other records is about **22,000 reads: about 44% of one day**. Fine in one go.
- Restoring 50,000 bills would need about 60,000 reads, more than one day. The restore is **resumable**: the cursor is saved, the quota guard pauses at 70% (35,000 reads) and continues after the daily reset. The app works locally the whole time.
- If the movements were uploaded as documents the restore would be about 75,000 reads and fail on day one. That is why they are derived.

## Storage growth
A 5-line bill document is about 2 KB; with the automatic index entries about 3.5 KB. 150 bills x 300 days x 3.5 KB = about 160 MB a year. Plus other records, about 200 MB a year, so the free 1 GiB lasts about **5 years**. Ways to extend: archive old years to a file the owner downloads, then stop syncing that year (a setting, off by default). A warning shows at 70% storage.

## Cost of retries
Spike S4 with very harsh chaos (15% lost requests, 15% lost replies, 5% crashes) uploaded 3,100 writes for 2,500 records: **24% extra writes**. Realistic internet is far better. A re-sent append-only record is accepted by the rules as a "re-stamp" (it still counts one write).

## In-app quota guard
- Counts reads and writes the app itself makes, per Pacific-time day, stored locally (not synced).
- At 70% of any limit: pause non-essential sync (pulls of old history, resumable restore) and show a calm message. Uploading new bills continues until 90%, then also pauses. At 100% everything stays local; uploads resume after reset.
- The count is an estimate (other devices share the same project quota). When the server answers "quota exceeded" the guard pauses until the next reset.
- A rejected request costs nothing and cannot cause a bill: the free plan has no billing account attached. Never add one.

## To confirm with the real project (Not verified)
Real per-request billing of rules lookups, and the real daily counters, can only be observed on the real project over several weeks. The owner checks Firebase console > Usage once a week during the pilot.
