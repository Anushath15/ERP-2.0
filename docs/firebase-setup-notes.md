# Firebase setup notes (decisions and reasons)

## Region of the Firestore database: asia-south1 (Mumbai)
- The shop is in India: Mumbai gives the lowest delay for every device, and keeps the shop data in India.
- Firestore's free daily allowance (1 GiB stored, 50,000 reads, 20,000 writes, 20,000 deletes per day on the Spark plan) is a per-project allowance of the (default) database. Google lists Mumbai among the normal Firestore locations with that allowance. A web search on 2026-10-13 did not find a statement that excludes Mumbai from the free allowance; **this is confirmed again in the console when the database is created** (the wizard shows the location and the plan; see the Step C record below).
- **The location cannot be changed later.** The alternative with the most history of "free" is a multi-region such as nam5, but it is far from India and slower, so it was not chosen.

## Rules design that is deployed
Design (b), the allow-list in the rules file (zero extra reads; see quota-budget.md). The e-mail addresses are not in git (`firebase/allowed-emails.local.json`, built by `tool/make_rules.dart`). Tests: 24 checks on the emulator (6 membership-design rules checks, 1 + 9 allow-list checks, 5 chaos and 3 convergence runs that sync under the rules).

## Collections the rules know today
bills, billCancellations, payments, stockMovements, ledgerEntries, audit, history, salesReturns, purchaseReturns, reminders (append-only); products, customers, dealers, categories, estimations, purchases, expenses, settingsShared (editable). Everything else is denied. Phase 2 adds collections here and extends the tests in the same commit.

## Spark plan
No billing account is ever attached. After creating the project the console's plan badge and `Usage and billing` must say Spark.
