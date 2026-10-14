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

## Do security-rule lookups count as reads? (checked 2026-10-13)
Yes. Official billing page: "You are charged for reads that are necessary to evaluate your Cloud Firestore Security Rules", one read per dependent document per request however many times the rules mention it, and they are billed even when the request is rejected (rules-conditions page). The docs do not say how a batched write of N documents is billed; the emulator cannot show billing. We therefore assume the cautious case: one lookup per distinct document per request.

### Design (a): membership documents (`firebase/firestore.rules`)
Each write request reads the member row (1) and the revoked-device row (1 per distinct device id): about 2 reads per upload batch. Each pull query reads the member row: 1 per query. A device pulling 6 collections every 10 minutes: 6 x 144 = about 860 reads a day, plus uploads about 300. About **1,200 reads/day per device, 3,600 for three devices (7% of the limit)**. Adding staff is instant (the owner adds an e-mail in the app). Per-device revoke works.

### Design (b): allowed e-mails inside the rules file (`firebase/firestore.allowlist.rules`)
Zero extra reads. Tested on the emulator (`allowlist_test.dart`: allowed e-mail reads/writes, duplicate re-send accepted, other user denied, tampering denied). Adding or removing a person = edit three lists and redeploy rules (`firebase deploy --only firestore:rules`). No per-device revoke list (ending a device = change the password).

### Recommendation
**Use (b) for one shop with 0-3 staff.** It saves about 1,200 reads/day per device and removes a moving part (a rule that reads data), and "remove the person's e-mail from the list" is a clear way to end access. Cost: a rules redeploy per staff change; the app's Staff screen shows the exact lines to change and I do the deploy (or the owner runs one script). Keep (a) as the documented option for when the shop has more than a few staff or wants to add people without a deploy: it is already written and tested, and the app's `RemoteStore` does not care which rules file is deployed.

## Added: part payments, customer payments and WhatsApp reminders
- A part-paid bill is still ONE bill document (the received amount and balance are fields), so credit sales cost no extra writes. Credit ledger entries that follow from bills and payments are derived on each device, not uploaded.
- Later customer payments are one small `payments` document each (already counted in the normal day: "40 later payments"). Write-offs, adjustments and credit notes are rare (a few a week).
- **Reminders: one small write per reminder opened.** A busy shop might open about 20 a day: **20 writes a day (0.1% of the limit)**, and each device that pulls them reads 20 more. Over a year about 7,000 reminder documents (about 12 MB, 1% of storage). A first restore reads reminder history last and only the most recent 90 days first, so it adds about 1,800 reads, not 7,000.
- Reminder records are held back 10 seconds before upload so "Not sent? Undo" can remove them; this adds no writes.


## A shop with 1,000,000 bills: what goes to Firebase and what stays on the PC
The free plan allows 1 GiB stored, 50,000 reads and 20,000 writes a day. One million bills do not fit, so **we never upload "everything"**. The rule (a decision for the owner, see PROGRESS.md):

| What | Where | Why |
|---|---|---|
| Bills, payments, reminders of the **last 24 months** | Firebase, one small document each (about 1.5 KB) | 24 months at 550 bills a day is about 400,000 documents, about 600 MB: inside 1 GiB with room for the rest |
| **Summaries**: one document per day (`day_totals`), per customer (balance), per product (stock), per product and month | Firebase, always | 365 daily documents a year; this is all the Home page and the reports need, on any device |
| Bills **older than 24 months** | Only on the shop PC, in a yearly file (`bills-2023.sqlite`), and in a yearly **backup file** the owner keeps on his own drive | A new phone does not need five-year-old bills; the PC has them and the owner has the file |
| Master data (products, customers, dealers, shop profile) | Firebase | small, edited |

- **Writes:** one bill = one write. At 550 bills a day that is 550 writes, 3% of 20,000. Summaries are updated on the device and uploaded as small replacements (a handful a day).
- **First restore of a new device:** reads the summaries and the last 24 months only: about 400,000 reads, spread over 8 days by the quota guard (50,000 a day) unless the owner restores from his backup file, which costs no reads. **A new device is usable on day 1** (masters + summaries + the newest bills first); older bills fill in over the following days.
- **Removing old bills from the cloud** (to stay under 1 GiB): one device deletes bills older than 24 months, at most 2,000 a day (the free plan allows 20,000 deletes a day), and only **after** that year has been saved as a yearly backup file on the PC. Nothing is deleted from a device.
- The in-app quota guard is unchanged: when the daily limit is near it pauses uploads; reading and billing on the PC never stop.
- Real quota use on the real project over several weeks is **Not verified**.


## DECIDED by the owner (2026-10-14): how long bills stay in Firebase
1. **Firebase keeps the last 24 months of bills** (bills, payments, reminders) **plus all summaries and balances** (day totals, customer balances, stock, product-month totals) and the master data. **Older years stay on the shop PC**, one database file per finished year (`bills-2023.sqlite`).
2. A new phone or PC is usable on the first day: masters, summaries and the newest bills first; the rest of the last 24 months fills in over the next days (50,000 reads a day).
3. **Phase 2 plan, added because of this decision:**
   - **Yearly backup reminder.** When a year is finished (and every January until it is done) the app asks, in plain words: "Last year's bills are saved on this computer only. Copy them to a pen drive or Google Drive now?" The year file is closed, checked and copied to the place the owner chooses; the app records the date and the file size. The reminder repeats every month until a copy exists, and a bill older than 24 months is **never** removed from Firebase before that copy exists.
   - **Restore an old year.** A button "Restore an old year" (Settings > Backup): the owner picks a year file from the pen drive or Google Drive; the app checks that it is a real year file of this shop (shop id, year, bill count, check value), then attaches it read-only so those bills show in the sales register, customer profiles and reports. It is also how an old year is put on a new PC. Nothing is uploaded to Firebase.
   - Removing old bills from the cloud runs on one device, at most 2,000 deletes a day, only after the year's backup copy exists.
4. Costs and limits for this are in "A shop with 1,000,000 bills" above; real use over weeks is **Not verified**.
