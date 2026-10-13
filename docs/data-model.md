# Data model

## Rules for every table
`id` (UUIDv7 text), `created_at`, `updated_at` (ms), `deleted_at` (soft delete, null = live), `device_id`, `version` (int, +1 per edit), `hlc` (hybrid clock stamp, editable tables). Money = integer **paise**. Quantity = integer **thousandths** (milli-units) so 25.5 pieces is 25500. Percent rates = integer basis points (18% = 1800). Dates = UTC ms; bill date is also stored as a local `YYYY-MM-DD` text for reports.

## Tables (local SQLite; cloud collections in brackets)
| Group | Table | Kind | Notes |
|---|---|---|---|
| Shop | `shop` [shops] | editable | name, address, GSTIN, state code, logo (local file) |
| | `members` [shops/members] | editable | email, role (owner/manager/cashier) |
| | `device_settings` | LOCAL ONLY | printer, paper, theme, font size, window, start page, PIN, quota counters, cursors |
| Catalogue | `categories`, `products` [same] | editable | product: name (as typed), HSN, GST rate bp, unit, sell price paise, cost paise (nullable), barcode, min stock, active; FTS5 `product_fts` |
| | `customers`, `dealers` [same] | editable | name, phone, address, GSTIN, credit limit |
| Documents | `bills` [bills] | append-only | number, series, date, customer, totals, round-off, mode, status (`active`/`cancelled` is a separate cancellation record), `idem_key` unique; **lines and payments embedded in the cloud document**, separate rows locally (`bill_lines`, `bill_payments`) |
| | `bill_cancellations` [bills-cancel] | append-only | bill id, reason, by, at |
| | `estimations` [estimations] | editable | own number and date, `converted_bill_id`, lines embedded; edit-in-place keeps number and date |
| | `purchases`, `purchase_returns`, `sales_returns` | append-only | lines embedded |
| Money | `payments` [payments] | append-only | customer/dealer payments after billing |
| | `expenses` [expenses] | append-only (+ cancel) | |
| Stock | `stock_movements` | append-only, **derived locally** from bills/purchases/returns; only `adjustment` and `opening` are uploaded [stockMovements] | kind, product, qty_milli (signed), unit cost |
| | `stock_cache` | cache | product -> qty, rebuilt by nightly self-check |
| Ledger | `ledger_entries` | append-only, derived locally from bills/payments/returns/opening | party, amount paise (signed) |
| | `balance_cache` | cache | party -> balance |
| System | `outbox`, `sync_meta`, `history` (lost edit versions), `audit` [audit], `series_counters` | | audit: who, what, when, old and new value for sensitive actions |
| Other | `warranties`, `house_projects`, `staff`, `notifications`, `daily_closings` | editable/append-only as named | |

## Invariants (each has a test)
- Stock of a product = sum of its movements; customer/dealer balance = sum of its ledger entries; caches equal that sum (nightly self-check, and a "Rebuild" button on the Health page).
- A bill and its movements, ledger entry, payment and outbox row are saved in one transaction. `idem_key` is unique, so a retry returns the same bill.
- Invoice numbers are gapless per series; the series is per device (`A-`, `B-`, ...). The counter row is incremented inside the save transaction.
- Cancelling a bill (owner only, reason required) writes a cancellation record plus reversing movements and ledger entries. The bill stays. Cannot be undone.
- Estimations never create movements. Converting sets `converted_bill_id` in the same transaction as the new bill; a second conversion is refused.
- Selling at stock 0 or below warns and never blocks (owner decision carried from ERP 1).

## GST and rounding (domain package, property-tested)
- Line: taxable value in paise from price x qty (milli) with round-half-up to paise **once per line**, after the per-item discount (percent or amount). Inclusive price: taxable = round(gross x 10000 / (10000 + rate_bp)); tax = gross - taxable. Exclusive: tax = round(taxable x rate_bp / 10000).
- Intra-state: CGST = tax / 2 rounded half-up, SGST = tax - CGST (so the two always add to the tax exactly). Inter-state: IGST = tax.
- Totals are sums of line values (never recomputed from totals). Round-off line = nearest whole rupee of the grand total, shown separately, stored in paise (range -50..+50).
- Slabs tested: 0, 5, 12, 18, 28%; 1-paise edges; fractional quantities; mixed carts; discount bigger than line is refused.
- Stock valuation (setting, default **average cost**; unpriced stock valued 0). One shared function `valueStock(rule, product, movements)` is used by every screen.

## Migrations
Versioned Drift migrations. Before any migration: automatic backup, run on a temporary copy first, on failure restore the backup and tell the owner. A newer database than the app understands is never opened.

## Customer credit and WhatsApp reminders (Phase 1 screens + tested rules; Phase 2 wiring)
Rules live in pure Dart under `lib/domain/credit/` (83 unit and property tests in `test/domain/`). The Phase 1 screens use fake in-memory data (`lib/fake/credit_store.dart`). Money is integer paise everywhere.

**Bill fields added** (`bills`, append-only, embedded in the cloud document): `customer_id` (null = walk-in), `received_paise`, `pay_mode` (cash / upi / card_other; "credit" is gone: it is `received = 0`), and derived-and-stored `balance_paise`, `change_paise`, `advance_kept_paise`. Invariants (property-tested in `splitPayment`): `settled + balance = total`, `received = settled + change`, only one of balance and change is above zero. A bill with `balance > 0` must have a `customer_id`; the save refuses otherwise. Saving stays ONE transaction: bill, lines, stock movements, the ledger entries below, payment row, outbox.

**Credit ledger (`credit_ledger`, append-only, local view; amounts signed: positive = customer owes us).** Kinds: `opening`, `bill_credit` (= `balance_paise` of a bill), `payment`, `advance` (extra money kept on account, from a bill or a payment), `return_credit`, `adjustment` (reason), `write_off` (owner only, reason, never more than owed), `bill_cancel` (reverses the bill's credit). Balance = sum of entries; positive is "Money to collect", negative is an "Advance". A cached `customer_balance` can be rebuilt from the ledger and is checked nightly (same rule as stock).
- Derived locally from synced records, NOT uploaded one by one (keeps the first restore small, see quota-budget.md): `bill_credit`, `advance` and `bill_cancel` come from bill and cancellation documents; `payment` and its `advance` part come from `payments` documents.
- Uploaded as their own small documents (they cannot be derived): `opening`, `return_credit`, `adjustment`, `write_off`.

**Payments** (`payments`, append-only): `customer_id`, `amount_paise`, `mode`, `date`, `note`, `allocations: [{bill_no, paise}]`, `advance_paise`, receipt number from a per-device series (`R-`). Applied to the OLDEST unpaid bills first (date, then bill number) or only to the bills the person chose (`allocatePayment`); `applied + advance = amount`. Bill-wise outstanding = bill total - received at the counter - allocations; a cache table `bill_due` is rebuilt from that. Ageing buckets (0-30, 31-60, 61-90, 90+ days) and "overdue" (older than 30 days) are computed from `bill_due` (`ageing`, `overdueAmount`). Cancelling a bill (owner, reason) writes a cancellation record; its credit is reversed by one `bill_cancel` entry; money the customer paid later towards that bill stays and becomes an advance.

**Credit limit:** `customers.credit_limit_paise` (optional) and a shop setting `credit_limit_mode` = off / warn / block.

**Reminders** (`reminders`, append-only events, one small document each, about 1.7 KB with the message): `customer_id`, `at`, `amount_due_paise`, `message` (at most 1,500 characters), `by`, `device_id`. A record means "Open WhatsApp was pressed", NOT "the message was sent": the app cannot see that, and the screens, tooltips and docs say "Reminders opened in WhatsApp". The count shown on the customer is the number of records (cached, rebuildable). **Undo:** the "Not sent? Undo" action is available for 8 seconds; the sync engine holds reminder records back for 10 seconds, so an undo removes the record before it is ever uploaded (no update or delete of a synced document is needed). The 24-hour guard reads the latest record of that customer (`ReminderLog.recent`), with the hours set in Settings. Nothing is sent automatically and there is no bulk sending (no WhatsApp Business API, which is paid).

**Shop settings that sync** (`settingsShared`): reminder tone, the two message templates, shop phone, UPI id, guard hours, default country code, credit-limit mode. Per-device settings stay out (see sync-design.md).

**Links:** `buildWhatsappLinks` makes `whatsapp://send?phone=<digits>&text=<encoded>` (tried first on Windows and Android) and `https://wa.me/<digits>?text=<encoded>` (everywhere else, and the fallback). Phone numbers are normalised to country code + digits (`normalizePhone`, default +91, accepts 10 digits, a leading 0, +91, 0091, spaces/dashes/brackets). Opening a link goes through one small `LinkLauncher` class: Phase 1 uses built-in code (Windows protocol handler, macOS `open`, Linux `xdg-open`, browser `window.open`) so the prototype needs no plugin; Phase 2 swaps it for `url_launcher` (needed for Android) once Windows Developer Mode is on or on CI.


## Built for 1,000,000 bills (tested: see perf-results.md)
Rules that every query and screen follows. They are what kept every page under 300 ms in the 1,000,000-bill test.
1. **Never load everything.** Lists use **cursor (keyset) paging**: `WHERE (billed_at, id) < (?, ?) ORDER BY billed_at DESC, id DESC LIMIT 50`. Never `OFFSET` (it reads and throws away every earlier row).
2. **Indexes that exist** (and nothing is searched without one): bills by `(billed_at DESC, id DESC)`, by `(customer_id, billed_at DESC, id DESC)`, unique `number`, unique `idem_key`, a partial one for cancelled bills; lines by `bill_id` and by `(product_id, bill_id)`; movements by `(product_id, at)`; ledger by `(customer_id, at DESC, id DESC)`; unpaid bills by `(customer_id, billed_at)` where due > 0; products and customers by name (NOCASE) plus FTS5 with prefix.
3. **Summary tables, written in the same transaction as the bill, never rebuilt by scanning:** `customer_balance` (balance, last bill, last payment), `stock_cache` (stock per product), `day_totals` (bills, sales, tax, cash, UPI, card, credit per day), `product_month` (quantity and amount per product per month), `counters` (invoice numbers: no `COUNT(*)`). `ledger.running_paise` stores the balance after each entry (entries are append-only), so a page of a customer's ledger needs no running sum. The nightly self-check recomputes each summary from the raw rows and compares.
4. **Reports** read the summary tables (a year of sales by day: 0.2 ms; top 20 products in a year: 90 ms). A question the summaries cannot answer (for example one product over five years) runs on the indexes in a background isolate with a progress bar and a Cancel button. A full scan of all lines (26 seconds in the test) is never run from a screen.
5. **Start-up opens the database and shows the first screen at once (20 ms).** The integrity check (`quick_check`, 42 s on a 3.6 GB file) runs in the background after the screen is up, weekly or from the Health page; the full `integrity_check` only from the Health page.
6. **Years.** Bills, lines and stock movements of a finished year live in their **own file** (`bills-2023.sqlite`, created when the year ends by copying in order; attached only when somebody looks that far back). The live database keeps masters, summaries, the ledger, the outbox and the current and previous year. Archiving a year by deleting rows inside the live file was tested and rejected: 1.6 s per 300 bills with the write lock held, which breaks the 100 ms save budget. Copying a year into its own file takes about a minute and the live database is only read. A page that crosses the live file and a year file is a `UNION ALL` of two keyset queries (0.2 ms).
7. **Disk space.** About 3.8 KB per bill in the live file (bill, 5 lines, 5 movements, ledger, every index; 3.0 KB per bill in a year file). 1,000,000 bills is about 3.6 GB. Before a backup, an archive or a compact the app checks the free space (needs 1.2 times the file) and says so in plain words if there is not enough. Backups use `VACUUM INTO` (79 s for 3.6 GB, compacts and verifies) or a file copy after a checkpoint (11 s).
8. **Where the files live.** Windows: `%LOCALAPPDATA%\ASK ERP 2.0\data` (local, not the roaming profile that can sync to a server) with backups in the Documents folder the owner chooses. Android: the app's private database folder; backups through the system file picker. Web: the browser's own storage; see perf-results.md for the honest limits.
