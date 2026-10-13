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
