# Firebase setup notes (decisions and reasons)

## Region of the Firestore database: asia-south1 (Mumbai)
- The shop is in India: Mumbai gives the lowest delay for every device, and keeps the shop data in India.
- Firestore's free daily allowance (1 GiB stored, 50,000 reads, 20,000 writes, 20,000 deletes per day on the Spark plan) is a per-project allowance of the (default) database. Google lists Mumbai among the normal Firestore locations with that allowance. A web search on 2026-10-13 did not find a statement that excludes Mumbai from the free allowance; **this is confirmed again in the console when the database is created** (the wizard shows the location and the plan; see the Step C record below).
- **The location cannot be changed later.** The alternative with the most history of "free" is a multi-region such as nam5, but it is far from India and slower, so it was not chosen.

## Record of what was created (2026-10-14)
- Project `ask-erp-2` ("ASK ERP 2"; a display name cannot contain a dot), owner anushath15@gmail.com. Billing: none (checked through the Cloud Billing API: billing enabled = no, no billing account name).
- **Region: asia-south1 (Mumbai).** Checked on 2026-10-14: Google's Firestore quotas page lists the free daily amounts (50,000 reads, 20,000 writes, 20,000 deletes, 1 GiB stored) with **no region restriction**, and says one database per project is free; the locations page lists Mumbai as a supported location and says the location **cannot be changed** after the database exists. Mumbai is the closest region to the shop. (The pages do not use the word "Spark"; the real daily counters are watched in the console once the app is connected: Not verified.)
- Database `(default)`: Firestore Native, edition Standard, production mode (closed rules at the start), delete protection ON, point-in-time recovery off (it needs billing).
- Rules deployed only after the emulator tests passed (1 + 9 allow-list checks and 6 membership checks run again that day). Unauthenticated read and write to the real database both answer 403.
- Authentication could **not** be enabled from the command line: the Identity Platform call answers BILLING_NOT_ENABLED. The console's own "Get started" works on the free plan, so those clicks are the owner's (OWNER-SETUP 4A to 4C).
- Making the shop Gmail an Owner needs an invitation that the shop Gmail accepts: Google refuses it as a command (OWNER-SETUP 4D).
- Web app "ASK ERP 2 Web" registered; its configuration is saved only in `firebase/deploy/` (git-ignored); the repository has `firebase/web-config.example.json` with placeholders. `firebase/.firebaserc` names the project id (not a secret): the default stays the emulator project `demo-erp2` so that nothing is deployed to the real project by accident; the real one is the alias `prod`. A real deploy always names the project and the deploy config: `firebase deploy --only firestore:rules --config firebase.deploy.json --project ask-erp-2`.
- Hosting: `firebase/firebase.deploy.json` (single-page rewrite, no-cache for the page and the app script, one week for pictures and fonts). Live: <https://ask-erp-2.web.app> (the v2.0.0-proto.2 web build, sample data only).

## Rules design that is deployed
Design (b), the allow-list in the rules file (zero extra reads; see quota-budget.md). The e-mail addresses are not in git (`firebase/allowed-emails.local.json`, built by `tool/make_rules.dart`). Tests: 24 checks on the emulator (6 membership-design rules checks, 1 + 9 allow-list checks, 5 chaos and 3 convergence runs that sync under the rules).

## Collections the rules know today
bills, billCancellations, payments, stockMovements, ledgerEntries, audit, history, salesReturns, purchaseReturns, reminders (append-only); products, customers, dealers, categories, estimations, purchases, expenses, settingsShared (editable). Everything else is denied. Phase 2 adds collections here and extends the tests in the same commit.

## Spark plan
No billing account is ever attached. After creating the project the console's plan badge and `Usage and billing` must say Spark.
