# ERP 1 → ERP 2.0 import map (Gate 2B)

Source studied (read only, never run or changed): `D:\Senthil Enterprises\ERP-1.0.1` — `desktop/backupFormat.js`, `docs/STORAGE_MIGRATION.md`, `frontend/services/offlineDataProvider.js`, `frontend/utils/settingsSchema.js`, and the screens that create each record (`pos.js`, `products.js`, `customers.js`, `sales_return.js`, `stock_adjustments.js`, `expenses.js`, …).
Everything below that says "learned from the code" was read from ERP 1's source. **Nothing has been checked against the owner's real backup yet** — that is the STOP step of this gate. Where the real file may differ, the importer is tolerant and reports instead of guessing.

## 1. The file we read
An ERP 1 backup is one JSON file, `ERP_Backup_YYYY-MM-DD_HHMMSS_<kind>.json` (folders: `Documents\Senthil ERP\Backups`):
`{ "_metadata": { "format": "senthil_erp_full_backup_v2", "checksum", "keyCount", "recordCount", "timestamp", … }, "data": { "<key>": <records> } }`.
Only keys starting `erp_` or `offline_` are present. Not in a backup by design: sign-in accounts, lockout and tokens (`auth_user`, `erp_auth_lockout`, `erp_token_v1`, `erp_auth_users`). A value that was not valid JSON is wrapped as `{"__rawText": "…"}`.
The importer accepts this file (a COPY). It does not open ERP 1's live data folder.

## 2. Unit conversions (the only place ERP 1 and ERP 2.0 differ in kind)
| ERP 1 | ERP 2.0 | Rule |
|---|---|---|
| rupees as a decimal number (`1234.5`) | integer paise | `round(rupees × 100)` using decimal text, half away from zero. More than 2 decimals is **repaired and listed** ("rounded"). Not a finite number, or beyond ±₹100 crore: **rejected**. |
| quantity as a decimal (`2.5`) | integer milli-units | `round(qty × 1000)`; more than 3 decimals is repaired and listed. |
| GST percent (`18`, `12`) | basis points (`1800`) | `round(percent × 100)`. |
| ISO date/time strings | milliseconds + `YYYY-MM-DD` day | Unparseable date: record **rejected**. ERP 1 dates without a time are taken as 12:00 (noon) India time so the day never shifts. |

## 3. Entity by entity
"Key" is the ERP 1 storage key. Ids: ERP 2.0 ids for imported records are `e1-<kind>-<ERP 1 id>` (stable; the second run produces the same ids and so adds nothing). The original id is also kept in `old_id` (products, customers, dealers) or `old_bill_no` (bills).

| ERP 1 (key) | Fields used | Goes to | Notes |
|---|---|---|---|
| Products (`erp_products`) | `id, name, category, unit, price, buyingPrice (avgCost if 0), taxRate/gst, hsn, barcode/sku, minStock, status/isActive, stock, isDeleted` | `products`, `stock_cache`, `stock_movements` | `price` is the selling price. `stock` becomes an **opening movement** sized so that the stock after import equals ERP 1's stock exactly (see §4). Products with `isDeleted` come in as deleted rows (history stays readable). Duplicate barcodes: second one is blanked and listed. |
| Categories (`erp_categories`) | `name` | `categories` | Also created from products' category text if missing. |
| Customers (`erp_customers`) | `id, name, phone, whatsapp, address, area, pin, gst, creditLimit, outstanding, isDeleted/isActive` | `customers` (`old_id`), opening balance in `ledger_entries` | `area` → `city`. `whatsapp`, `type`, `creditDays`, `notes` have no column yet: **listed, not dropped silently** (kept in the import log). |
| Dealers (`erp_dealers`) | `id, companyName/name, phone, address, gst, outstanding` | `dealers`, ledger (`party_kind=dealer`) | |
| Sales invoices (`erp_sales_invoices`) | `id`/`invoiceNumber`, `date`, `customerId`, `customerName`, `items[]`, `subtotal, discount, taxableAmount, cgstTotal, sgstTotal, igstTotal, roundOff, totalAmount, paymentMode, amountPaid, status/paymentStatus, cancelReason` | `bills`, `bill_lines`, `bill_cancellations`, `stock_movements (sale)` | **Totals are copied, never recomputed**, so every historic bill keeps the amount the customer was given. Bill number → `bills.number` and `bills.old_bill_no` (series `ERP1`, so it never clashes with a computer's own letter). Mode: Cash 0, UPI 1, Card 2, anything with credit 3. Cancelled bills come in cancelled, with their reason, and make no stock movement. A bill whose line totals do not add up to the total is **imported unchanged and listed**. Walk-in bills have no customer. |
| Sales invoice lines | `productId, name, qty, price, taxRate, pricingMode, costPrice, hsnCode, discountPercent, discountAmount, total` | `bill_lines` | Unknown product id: a placeholder product "Unknown item (ERP 1 id …)" is created and listed. |
| Estimations / quotations (`erp_estimations`) | `id, date, customerId/name, items, status` | `estimations` + lines | `Converted` keeps its link only when the bill is found. |
| Purchases (`erp_purchases`) | `id, date, dealerId/name, items[productId, qty, costPrice], totalAmount, amountPaid, status, stockApplied` | `records` kind `purchases`, `stock_movements (purchase)` when `stockApplied`/received, dealer ledger for the unpaid part | **Pending purchases add no stock** (owner decision). |
| Purchase returns (`erp_purchase_returns`) / Sales returns (`erp_sales_returns`) | `date, invoice, customerId/dealerId, product, qty, amount, reason, status, items` | `records` kinds `purchaseReturns` / `salesReturns` | **No stock movement is made** for returns: ERP 1 applied them to the product's stock figure, and that figure is already inside the opening movement. Listed in the report. |
| Stock adjustments (`erp_stock_adjustments`) | `productId, type, qty, reason, date, previousStock, newStock, user` | `stock_movements (adjustment)` with delta `newStock − previousStock` | Rows without both figures are listed and used with their sign by type. |
| Credit payments (`erp_credit_payments`) | `customerId, amount, date, method` | `payments` + negative ledger entries | See §4. A payment for an unknown customer is rejected and listed. |
| Dealer payments (`erp_dealer_payments`) | `dealerId, amount, method, date` | `payments`, dealer ledger | |
| Expenses (`erp_expenses`) | `date, category, amount, method, description` | `records` kind `expenses` | Amount > 0 else rejected. |
| Deliveries, warranties, house projects, staff, notifications | free fields | `records` kinds `delivery`, `warranty`, `projects`, `staff`, `notifications` | Stored as a JSON copy of the ERP 1 record with `amount`-type fields converted to paise. |
| Settings (`erp_settings`) | `shopName, ownerName, address, gstin, phone, email, invoicePrefix, defaultGst, footerMessage, terms` | shop profile in `kv` | The shop's own profile is **not overwritten** if the new database already has one; otherwise filled. Printer name, theme, PIN are this-computer settings and are not imported. |
| System state (`erp_system_state`) | `lastSalesInvoice_<fy>` counters | not imported | ERP 2.0 numbers bills with its own series; the old counters are listed in the report. |
| Product price history (`erp_product_price_history`) | price changes | `audit` rows | Only counted in the report in this version. |
| Daily closings, opening cash, users, drafts, projects | | counted and listed | `erp_opening_cash` and `erp_daily_closings` have no home yet; **listed**. Users/passwords are never imported. |

## 4. Balances: how the numbers are made to agree
ERP 1 keeps **no ledger**: a customer or dealer carries one `outstanding` number that bills and payments adjusted. ERP 2.0 derives balances from entries. So per party the importer writes:
1. one **opening** entry = `outstanding(ERP 1) − Σ(unpaid part of that party's bills not cancelled) + Σ(payments)`;
2. one **bill credit** entry per bill with something unpaid (positive);
3. one **payment** entry per payment (negative).
These add up to ERP 1's `outstanding` exactly. If the opening entry is large (ERP 1 numbers did not explain themselves) the party is **listed in the report** — usually opening balances typed in by the owner, which is correct.
Stock works the same way: opening movement = `stock(ERP 1) − Σ(movements we can reconstruct)`, so `stock_cache` equals ERP 1's figure, and anything unexplained is listed (products where the opening is far from the first purchase).

## 5. Things with no home (listed in every report, never silently dropped)
Customer type/whatsapp/credit days/notes; per-line batch or serial data; order delivery photos; daily closings and opening-cash counts; sign-in accounts (by design); price history detail; per-invoice `projectId`; any key not in the table above (its name and record count are printed).

## 6. Safety rules the tool follows
- Reads one file, never writes to it, never opens ERP 1's live folder.
- **Dry run** by default: parses and validates everything, writes nothing, prints the reconciliation report.
- `--write <new file>` creates a NEW database that must not exist yet; if anything fails the half-built file is deleted. The live `shop.sqlite` is never opened. Swapping it in is a separate step the owner approves.
- Hostile or corrupt input (not JSON, wrong shape, a 5 MB name, `NaN`, negative stock, cyclic ids, absurd dates, 10 million items) is answered with a plain message or a per-record rejection, never a crash and never a partial database.
- Idempotent: the same file imported again into the same import database changes nothing (ids are derived from ERP 1 ids).

## 7. Stock value — the open decision (see the report)
The report prints stock value **three ways** side by side — at selling price, at buying price (ERP 1 `buyingPrice`), at average cost — with the same product count each: priced stock, unpriced stock (cost 0) and inactive products listed separately, and negative-stock products counted at zero or as-is. The importer **does not choose**; the setting key `valuation.rule` stays unset until the owner's father picks one.

## 8. How to run it (and what the owner does)
**Tool:** `dart run tool/import_erp1.dart <backup.json>` is a dry run (reads, checks, prints the report, writes nothing). `--report report.txt` also saves the report. `--write new.sqlite` writes a NEW database and then reads every total back and compares it with the backup. The in-app screen for this is not built yet (it is a thin wrapper over the same code); until then the dry run is run by Claude on the owner's copy.
Code: `lib/import/erp1/` (reading, checking, report), `lib/data/importer/erp1_writer.dart` (the only part that writes SQL), `tool/import_erp1.dart`, synthetic test files from `tool/import/synthetic.dart`.

**What the owner does (exact steps):**
1. In ERP 1, after the day's last bill: Settings → **Create Backup Now**. (Do not change anything else in ERP 1.)
2. In File Explorer open `Documents\Senthil ERP\Backups`. Find the newest file named like `ERP_Backup_2026-10-15_183000_manual.json`.
3. **Copy** it (right-click → Copy; do not move or cut) and paste it into a NEW folder `D:\Senthil Enterprises\ERP1-backup-copy` (create the folder). Tell Claude "the copy is ready".
Nothing is opened, changed or deleted in ERP 1. The tool reads only the copy.

## 9. Not verified (as of this commit)
- Nothing was run on a real ERP 1 backup; every number above is from synthetic files built to ERP 1's record shapes. Field names were taken from ERP 1's source; a real file may use others (the importer lists what it could not use, it does not guess).
- The backup's own checksum (`_metadata.checksum`) is not re-computed yet, so a silently damaged backup is not detected by that route; the validation of each record is.
- How ERP 1 treats `inclusive/exclusive` GST on the invoice header (as against each line) is read from the lines only.
- Returns: ERP 1's effect on stock/balances is assumed to be already inside the product `stock` and customer `outstanding` figures.
