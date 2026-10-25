# Calculation rules (every rupee, one place)

All money is whole **paise** (integers). Quantities are thousandths. No floating point is used for money. Rounding is always **half-up to the paisa**
(`divRound`, `lineAmount`). These rules follow what Tally, Zoho Books/Inventory and ERPNext document for the same situations (written from their documented
behaviour, not from live pages: no internet is available to the build machine).

| Area | Rule | Where | Checked by |
|---|---|---|---|
| Line amount | rate x quantity, rounded once to the paisa | `lineAmount` | `bill_math_properties_test` |
| Price WITH GST | taxable = amount x 100 / (100 + rate), tax = amount - taxable (the customer pays exactly what was typed) | `calcLineIn` | `gst_hand_checks_test` |
| Price WITHOUT GST | tax = taxable x rate, total = taxable + tax | `calcLineIn` | same |
| Item discount | taken off the line amount BEFORE GST | `calcLineIn` | same |
| Whole-bill discount | shared among the lines in proportion (largest remainders), each line's GST comes down with it, never more than the bill | `allocateByWeight` | properties |
| CGST / SGST | GST of the WHOLE bill split in two once (an odd paisa goes to SGST), so they never drift apart | `calcBillIn` | properties, `whole_shop_random_test` |
| Round-off | the grand total rounds to the nearest rupee (setting); the difference is shown | `calcBillIn` | properties |
| GST summary on the print | one row for each GST rate, split once per rate | `bill_template.dart` | `print_layout_test` |
| Sales return (credit note) | each line's share of what was paid, the LAST part takes what is left (so partial returns add up to the bill exactly); the bill's round-off goes back with the last item; GST is the share minus its taxable part | `ReturnRepo.share` | `whole_shop_random_test` |
| Purchase typed WITH GST | the line is worked from the exact money typed (quantity x typed rate), not from a rate rounded without GST: 10 x 3.13 = 31.30 | `PurchaseLineInput.grossPaise` | `purchase_inclusive_test` |
| Purchase typed WITHOUT GST | taxable = rate x quantity, GST on that | `PurchaseLineInput` | same |
| Purchase return | the same share rule as a sales return; stock must be there | `PurchaseReturnRepo` | `whole_shop_random_test` |
| Average cost | moving weighted average: (stock x cost + arrival x rate) / (stock + arrival); nil or negative stock carries no value; selling does not change it | `movingAverage` | `average_cost_and_cashbook_test` |
| Buying price | the latest rate without GST; the selling price follows by the same ratio (margin kept) | `_applyCost`, `sellingPriceKeepingMargin` | purchase tests |
| Stock value | average cost (or the rule the shop chose) x stock, integer maths | `StockValuation` | `stock_value_test` |
| Customer / dealer account | the sum of the ledger; a payment settles the OLDEST bill first; the remainder is an advance | `allocatePayment` | property test in `domain/credit` |
| Cash book (day closing) | opening + cash sales (after cash refunds) + cash received from customers + cash refunded by dealers - cash paid to dealers - expenses; reversed payments and UPI/card money do not count | `ReportRepo.cashBook` | `average_cost_and_cashbook_test` |
| Profit | value before tax minus the buying cost of what was sold; if no item sold has a buying price it is shown as unknown (nothing is guessed) | `reports_screens.dart` | review |
| Summaries | the day totals, stock cache and party balances always equal the raw rows; `selfCheck(deep)` and `rebuildSummaries` prove it | `rebuild.dart`, `self_check.dart` | `whole_shop_random_test` |

## What `whole_shop_random_test` does

Five random shops (seeds 1 to 5), 160 random operations each: sales (with/without GST in the price, item and bill discounts, round-off, part payment),
partial returns, purchases (typed with or without GST), purchase returns and payments. Then it checks, to the paisa: every bill and purchase adds up from
its lines; taxable + GST = lines; CGST and SGST differ by at most a paisa; a return never gives back more than was sold; the unpaid part is between nothing and
the total; the average cost lies between the cheapest and dearest rate paid; day totals and party balances equal a full rebuild; `selfCheck(deep)` is empty.

## Known gaps (not mistakes, not yet built)

* **IGST**: the maths is there (`interState`) but no screen sets it; every bill is CGST + SGST (right for a local shop).
* **GSTR-1 / GSTR-3B / HSN-wise summary**: only the bill-wise tax export exists.
* **Dealer invoice round-off / adjustment**: a purchase total is exact to the paisa; a dealer's printed invoice usually rounds to the rupee (Zoho Books has an
  "Adjustment" field for it).
* **Cost of goods sold** uses the latest buying price recorded on the bill line; Tally/Zoho use the average (or FIFO). The average is now kept up to date, so the
  profit basis can be switched later.
* **Opening cash** is one setting, not yesterday's counted cash carried forward.
* **Product GST rates imported from ERP 1**: 835 of 836 are 18 % (probably ERP 1's default): check HSN and rate item by item.

## GST returns (Export page > GST returns)

| Part | Rule |
|---|---|
| GSTR-1 B2B | invoices to customers whose GSTIN has the right shape, one row for each GST rate of the invoice; cancelled bills are left out |
| GSTR-1 B2C | all other sales by rate (inter-state bills show IGST) after taking off credit notes |
| Credit notes | sales returns; to a registered customer they are listed (against the invoice), to others they are taken off B2C |
| HSN summary | sales less returns by HSN, rate and unit (UQC); products with no HSN show as (not set) |
| GSTR-3B 3.1 | outward supplies = all sales less all credit notes (rate 0 goes to 3.1(c)) |
| GSTR-3B 4 | input tax credit = GST of purchases received in the month from dealers WITH a GSTIN, less purchase returns; other dealers' tax is shown as not claimable; a dealer in another state gives IGST |
| GSTR-3B 6.1 | tax to pay = output tax less credit, head by head; leftover credit is shown to carry forward |

CGST and SGST are split once for each invoice and rate (an odd paisa goes to SGST), exactly as the printed invoice's GST summary does. Round-off is never part of a
taxable value. `test/data/gst_return_test.dart` proves, for random months, that B2B + B2C - credit notes, the HSN summary and GSTR-3B all equal the saved bills and
returns to the paisa. The figures are for the accountant to check and file; the program does not file anything.

## Other rules added with the orders and statements

* A statement of account carries a UPI QR code for the whole amount due (the customer scans, confirms).
* A purchase records how it was paid (cash, UPI, card, bank); the day's cash book counts only the cash.
* An order to a dealer holds items and quantities only (no rates); "Make purchase" fills a purchase from it with the latest buying prices, and everything can be changed before saving.
