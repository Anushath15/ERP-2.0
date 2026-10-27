# Threat model and security rules plan

The repository is public, so assume attackers read the code and rules. Security comes from the rules and Auth, not from secrecy. Firebase web API keys are identifiers, not secrets, but real config is still kept out of the repo.

## Assets
Shop data (customers, bills, prices), the owner's account, backups.

## Threats and answers
| Threat | Answer |
|---|---|
| Stranger reads or writes shop data | Rules deny everything except signed-in members with a **verified** email; tested (S1) |
| One shop reads another | Membership is checked per shop path; cross-shop read and write tests |
| Someone claims to own a shop | Shop creation needs `ownerEmail == token email`; member rows can only be added by the owner (or the bootstrap owner row in the same batch via `getAfter`) |
| Cashier changes history | Append-only collections cannot be updated (except a harmless server re-stamp) or deleted; tampering test passes |
| Oversized or malformed documents | Rules cap field count (60), require `id == docId`, `deviceId`, `updatedAt`, server stamp equals request time |
| Unknown collection abuse | Collection allow-list; others denied |
| Lost/stolen device | Optional PIN; owner marks the device revoked (that device's writes are denied by rules); "Sign out everywhere" = change password (ends refresh tokens); token validity up to 1 h remains for reads. Honest limit: without Cloud Functions a stolen signed-in device can read until its token lapses |
| Staff leaves | Owner removes the email; next request fails |
| Secrets in repo | `.gitignore` for config/keystores/backups; `.example` files; secret scan before every push; CI uses GitHub secrets |
| Local file theft | Database is a normal file in the user's data folder; the PIN only locks the UI. Disk encryption (BitLocker) is the owner's choice. Backups are plain files the owner keeps safe (stated in the guide) |
| Malicious import file | Importer only reads JSON, never executes, validates types and sizes |
| Credential phishing | Only Google's and Firebase's own sign-in endpoints; the app never stores passwords (tokens only) |

## The production rules (`firebase/firestore.allowlist.rules`)
The template holds placeholders; `dart run tool/make_rules.dart` fills them from the private, git-ignored `firebase/allowed-emails.local.json` (owners, managers, cashiers, optional daily caps). The generator refuses anything that is not a plain e-mail address, a person in two roles, no owner, or silly caps (`test/make_rules_test.dart`). Real addresses never enter git.

### Who may do what (finding 5)
| | Cashier | Manager | Owner |
|---|---|---|---|
| Bills, bill payments, ledger entries from a sale or a customer payment, sale stock movements, customer notes, WhatsApp reminder log | yes | yes | yes |
| Add a NEW customer (credit limit must be 0) | yes | yes, any limit | yes |
| Change an existing customer (name, phone, limit) | no | yes (a limit change needs its audit record) | yes |
| Products, prices, costs, categories, dealers, purchases, estimates, returns, stock adjustments, pay a dealer, adjustments and credit by hand | no | yes (a price or cost change needs its audit record) | yes |
| Write off, cancel a bill, shop profile, shared settings | no | no | yes |
| Approve or revoke a device, change the lists of people | no | no | yes (the lists are changed by redeploying the rules) |
| Delete anything | nobody (the rules have no delete anywhere) | | |

Every price, cost and credit-limit change must come in the same batch as an **append-only audit record** (who, when, old value, new value). The rule reads it back with `getAfter` and compares entity, field, old and new values and the signer, so a change without a true audit record is refused. Audit records cannot be edited or deleted. Tests: `rules_roles_test`, `rules_audit_test`, `rules_basics_test`.

### The shape of every record (finding 7)
Each collection lists its exact fields: required and allowed fields only (unknown fields refused), integer paise within a range (no strings, fractions, negatives), string length limits, enums, list length limits, `id` equal to the path, `createdBy` equal to the signed-in e-mail, a plausible date (not older than about 2 years, not more than a day ahead) and the server time stamp. Tests: `rules_fields_test` (-999999 price, string price, 10,000-character name, unknown field, forged creator, wrong id, oversized lists, wrong signs, double party on a payment...). NaN cannot be sent through the REST API's JSON; a double of any kind is refused because every money field must be an integer.

### Device approval (finding 6)
A device is a document `devices/{id}` that **a new device can only create as "pending"** for its own signed-in e-mail. Only the owner can change it to "approved" or "revoked" (in the app's Security card). Every business write is checked by the rules with a `get()` of that device document: it must exist, be approved (not pending or revoked) and belong to the signed-in e-mail. A client that invents or copies a device id gets nothing: a pending or unknown id is refused, and another person's approved id is refused because the e-mail does not match.
**What this cannot stop:** an approved device that is stolen while signed in keeps working until the owner revokes the device (or removes the person from the list, or disables the user in Authentication). All three take effect on the very next request, but nothing detects the theft by itself. A person who is signed in on an approved device can still do everything their role allows.

### Write-spam and quota abuse (finding 9)
Spark stops at its free limits (20,000 writes and 50,000 reads a day) and **cannot charge money**: the project has no billing account, and without one Google refuses requests over the limit. The risk is therefore *denial of service* (a rogue or stolen account uses up the day's free writes, the shop cannot sync until the reset), not a bill.

**The real worst case, and the caps chosen (revised 2026-10-14).** The rules count **commits** per person per day. A commit can hold up to 500 documents (Firestore's limit; the emulator accepted 499 with all checks), so the worst case of a modified program is *cap x 500* writes:

| Role | First cap | Worst case then | Cap now | Worst case now | Share of the 20,000 free writes |
|---|---|---|---|---|---|
| Cashier | 1,500 | 750,000 | **20** | **10,000** | 50% |
| Manager | 3,000 | 1,500,000 | **24** | **12,000** | 60% |
| Owner | 4,000 | 2,000,000 | **24** | **12,000** | 60% |

(The "144 commits x 499" figure was the app's pace; the cap is what an attacker can actually reach.) Each commit also costs one counter write. The caps can be changed per person in the private `allowed-emails.local.json` (`"caps"`), for example for one big import day.

**Normal use must fit.** From the 1,000,000-bill design (`docs/quota-budget.md`): 550 bills a day is about 1,100 documents with payments, reminders and edits (the worst legitimate day is about 2,000 changed documents). The app sends at most **100 documents per commit** and sends only when 100 are waiting, or the oldest change has waited 90 minutes, or the person forces it (Copy now, app closing, internet back) (`lib/domain/sync/batch_plan.dart`, tested). A 12-hour day then needs: 1,100 documents = 11 commits by size (8 by time), plus up to 4 forced = **15 commits** (cashier cap 20); the worst legitimate day of 2,000 documents = 20 + 4 = **24 commits** (manager and owner cap 24). Day numbers are UTC: the counter resets at 5:30 am India time. The counter belongs to the person, not the device. If a very busy day does reach the cap, nothing is lost: the program keeps working, sends the rest after the reset, and the owner can raise that person's cap.

**Honest limit that remains.** The rules cannot see how many documents a commit holds, so they **cannot enforce the app's 100-document limit**. A *modified program* signed in as a cashier can send 20 commits of 500 documents (10,000 writes, 50% of the day), a manager or owner 12,000 (60%); two such accounts together could use the whole free day. What limits this: the account must be a real, listed, verified person on a device the owner approved; the owner can stop the device and the person within two minutes (below); and the damage is a paused sync until the next reset, never a bill and never lost data (the shop's own computer keeps everything).

Layers, best to worst:
1. **Per-person daily commit counter** (above): every business commit must also move the person's counter document `usage/{email}_{day}` up by exactly one, and the rules refuse a number above the role's cap. The counter cannot be reset, edited down or deleted (tests).
2. **The app's own batching limit** (100 documents, few commits). Not enforceable by rules; it keeps honest use far under the cap, which is why the cap can be low.
3. The in-app quota guard (`docs/quota-budget.md`) pauses non-essential sync at 70% and uploads at 90%, and the app shows **"Sync paused: daily limit reached"** (see below).
4. **App Check: not used.** Firebase App Check proves a request comes from the real app. The free providers (reCAPTCHA v3 / Enterprise for web, Play Integrity for Android, App Attest / DeviceCheck for Apple) cover web, Android, iOS and macOS only. There is **no provider for Windows**, and the shop's main computer is Windows, so App Check could not be required without locking that computer out. The app also talks to Firestore over REST, where a token can be copied by anybody who holds it. Decision: not enabled; revisit if Windows gets a provider. It would not stop a person with a valid sign-in in any case.
5. **Emergency procedure**, in plain English in `docs/SECURITY-CHECKLIST-FOR-OWNER.md` ("Emergency: two minutes"): (a) in the app's Security card press **Stop this device** (its changes are refused at once); (b) Firebase console, Authentication, Users, **Disable account**; (c) later, remove the address from the lists and redeploy the rules (`dart run tool/make_rules.dart`, then `firebase deploy --only firestore:rules --config firebase.deploy.json --project ask-erp-2`); (d) change the Google password. (a) and (b) work on the very next request; a token already issued can still read for up to an hour (Firebase limit).

**What the owner sees when the limit is reached.** The sync badge at the top turns amber and says **"Sync paused: daily limit reached"**; Settings explains: everything is safe on this computer, billing continues, copying online starts again tomorrow, nothing is charged. Nothing else stops. If it happens on a quiet day, treat it as a warning and use the emergency steps.

### What the checks cost (findings 6 and 9), measured on the emulator
Per uploaded batch the rules read two extra documents (the device record and the day's counter) and the app writes one extra document (the counter). A repeated mention of the same document in one request is counted once; a batch of 499 documents with the device and counter checks was accepted by the emulator (`rules_devices_usage_test`), so the 20-lookup limit is not reached. An edit of a price, cost or credit limit also reads its audit record once. With the daily commit caps (20 to 24 a day per person) the checks add at most 24 writes and 48 reads a day per person, about 0.1% of the free limits. Real billing of rule lookups was not observed on the real project (see `docs/quota-budget.md`, "Not verified").

### No billing account, ever
The project is on the Spark plan. The owner confirms the "Spark" badge in the Firebase console (a step in `docs/OWNER-SETUP.md`); nothing in the repository can attach billing, there is no Blaze-only feature in use (no Functions, no Storage), and the instructions tell everybody never to upgrade. A test cannot prove the console state; it is a monthly line in the owner's checklist.

## Local settings are preferences, never permissions (finding 2)
`device.json` (Windows, macOS, Linux) and the browser's local storage hold **display preferences only**: theme, accent, text size, billing text size, density, font, animation level, sounds, paper size and print text size. Anybody who can sit at the computer can edit them, so:
- **Nothing security-related may ever be read from this file or from local storage.** There is no "this device is trusted" flag, no role, no "approved", no signed-in marker, no shop data. Permission always comes from Firebase (the rules check the signed-in e-mail, the allow-list, the device approval and the role on every request).
- Everything is validated on read: unknown keys are ignored, wrong types, unknown names, out-of-range and non-finite numbers go back to the defaults, and a missing, damaged, wrong-shaped, binary or oversized (over 64 KB) file means defaults, never a crash. Tests: `test/device_settings_integrity_test.dart`.


## Status of the ten review findings (numbers as in the original review list)
| # | Finding | Status | What was done / what is left |
|---|---|---|---|
| 1 | Reserved file names (`CON`, `NUL.pdf`, trailing dots, control characters) | **Fixed** | One `safeFileName` is used by every save; numbered names instead of overwriting; tests for `CON`, `NUL.pdf`, control characters, long and empty names. |
| 2 | Settings tamper (`device.json` / local storage trusted) | **Fixed** | Preferences only, validated on read, unknown keys ignored; nothing security-related is read from it (section below). |
| 3 | CI tags (mutable action tags, broad permissions) | **Fixed** | Every action pinned to a full commit SHA with a version comment (guard test), read-only permissions, Dependabot for actions, Dart packages and Firebase tools. |
| 4 | Path traversal (and hostile text: CSV formulas, WhatsApp link, hostile import files, SQL, logs) | **Fixed / safe** | `isInside` check on the resolved path; `..\..\Startup\x` and `C:\evil` neutralised; restore and import only read files and never write a name taken from them; `csvCell`, strict WhatsApp link, limited JSON reader, no SQL built from text (guard test), the app logs nothing. |
| 5 | Role collapse (every member could change prices and limits) | **Fixed** | Cashier / manager / owner enforced by the rules; price, cost and credit-limit changes need an audit record in the same batch. |
| 6 | Device revocation (the client's device id was not a control) | **Mitigated** | A new device can only write "pending"; only the owner approves or stops; every business write needs an approved device of the same person. Left: a stolen, already approved device works until the owner stops it. |
| 7 | Field typing (rules accepted any shape of data) | **Fixed** | Exact fields, integer paise, ranges, lengths, enums, id and creator checks; a test for each malformed case. |
| 8 | Phishing and the people (stolen phone or Gmail, no two-step verification) | **Mitigated** | `docs/SECURITY-CHECKLIST-FOR-OWNER.md` and the Security card. The program cannot check two-step verification and says so. Left: the owner must turn it on and print the codes. |
| 9 | Write spam | **Mitigated, with the limit that remains** | Per-person daily commit counter with caps (cashier 20, manager 24, owner 24; worst case 10,000 / 12,000 / 12,000 writes of the 20,000 free), the app sends at most 100 documents per commit, quota guard, "Sync paused" message, two-minute emergency procedure. Left: the rules cannot enforce the batch size, so a modified program could use a whole capped day in big commits; Spark cannot bill; App Check is not possible on Windows. |
| 10 | Release pipeline (who can release; unsigned, unverifiable downloads) | **Mitigated; signing accepted for now** | Release only from a `v*` tag on main after CI, `release` environment needing the owner's approval (admin bypass off), checksums, build attestations, tag and main rulesets, "Verify your download", the honest "Unknown publisher" explanation. Free signing (SignPath Foundation) is researched in `docs/code-signing.md`. Left: the owner approves each release; commits are not signed. |

### Accepted risks
- Commits are not cryptographically signed (one-person project; the main branch cannot be force-pushed or deleted, and every release is built by CI and approved by the owner).
- No Windows code-signing certificate yet (see finding 10).

### What this cannot stop (honest list)
- Someone who already holds the owner's unlocked computer, or the owner's Google account without two-step verification.
- A stolen but already approved device, until the owner stops it. A token already issued can read for up to an hour after a sign-in is disabled (Google's limit).
- A trusted person (cashier, manager) misusing what their role allows. The audit records show who changed a price, cost or limit and bills and payments are append-only, but nothing stops a cashier selling cheap to a friend.
- An owner who approves a malicious device or release.
- Spam inside the daily batch cap, and damage to the free daily quota (denial of service) by someone who is signed in. There is no bill, but sync pauses until the reset.
- Malware on the shop computer, and theft of the database file from the disk (use BitLocker).
- Anyone on the internet who reads this public repository: that is expected; security does not rely on secrecy.

## Security review, October 2026 (attacker's view of the whole program)

Found and fixed (each has a test in `test/security_attacks_test.dart` or next to the code):

| # | Where | What an attacker could do | Fix |
|---|---|---|---|
| S1 | Counter link (shop Wi-Fi) | Record a sealed "link" message and send it again from their own laptop within 10 minutes: the counter would then send its (still encrypted) changes to the laptop instead of the real counter. Record any message and play it back. | Every sealed message is accepted once only (nonce guard), names the address it is for, and every answer names the request it answers; an old answer is refused. |
| S2 | Shop file brought in (restore, Telegram copy, a file handed over) | Hide a SQLite trigger in the file that later changes data (halve bills, empty the ledger), or replace one of the program's own triggers. | On every open, any trigger or view the program did not make is removed, and the program's own ones are compared with their exact text and made again when changed. |
| S3 | Cloud (Supabase) | A cashier or manager (or a changed program with their sign-in) changes a bill that is already saved: lowers its total, removes an item, un-cancels it. | `supabase/migrations/0004_saved_bills_fixed.sql`: only the owner can change a saved bill; resending the same bill still works. Run it once in the SQL Editor. |
| S4 | Products > Excel | A tiny crafted .xlsx (zip bomb) that unpacks to gigabytes freezes the program. | Files over 25 MB and parts that unpack to over 64 MB are refused before unpacking. |
| S5 | Imported ERP 1 records | A record with a field in an unexpected form (text date, true/false) broke whole pages (the grey Notifications page). | Records are read whatever form a field has (`Rec.i`, `Rec.d`, `Rec.date`); a damaged one shows instead of breaking the page. |

Checked and found sound: SQL is always parameterised (and the sync writes only real column names); file names are cleaned and kept inside one folder;
the sign-in and the Telegram token are kept encrypted for the Windows user (DPAPI); the PIN is a salted PBKDF2 hash with growing waits; nothing under the lock
screen can be clicked or typed into; CSV/Excel exports cannot carry formulas; the cloud's own rules refuse non-members, revoked computers, cashier changes to
products and owner-only actions; the UPI link accepts only a valid UPI ID; the WhatsApp message is URL-encoded.

Still true (cannot be fixed inside the program, or a decision for the owner):

* Anyone who can sign in to the shop computer's Windows account can open the shop file directly; the PIN only guards the program's screens. Use a Windows
  password, and BitLocker if the computer may be stolen.
* A removed computer is refused by its computer id; a person with a valid sign-in could make a new id. To shut a person out, turn their membership off
  (Supabase > shop_members, `active = false`), not only the computer.
* Routine backups (`.sqlite`) are not encrypted; the Telegram copies are (`.askbak`). Keep the backup folder on the shop computer or a pen drive you hold.
* The installer is not code-signed, so Windows shows "unknown publisher".

## Thermal printer, direct (ESC/POS), October 2026

* **Text can never become a printer command.** Every piece of text on a thermal bill (product names, the customer, the shop footer) has
  its control bytes removed before it is sent (`printableText` in `lib/features/print/escpos.dart`): a name typed or imported with ESC or
  GS bytes in it cannot open the cash drawer, cut the paper or change the printer's settings. Letters the printer's character table cannot
  show print as `?`. Test: `test/thermal_escpos_test.dart` reads the bytes back and fails on any command that is not the program's own.
* **Bills stay in the shop.** A network printer must have an IPv4 address in the shop's own network (10.x, 172.16-31.x, 192.168.x, 169.254.x,
  or this computer); any other address is refused when typed and again when printing (`parsePrinterAddress`).
* **The cash drawer** opens only for a cash bill right after Save and print, or with the Open drawer button in Settings; never on a reprint.
* The Windows RAW job loads `winspool.drv` by its full System32 path (`systemDll`) and runs on its own thread with a time limit, so a
  printer that does not answer cannot freeze the counter; the bill then prints the normal way and the person is told.

## Developer tools (firebase/package.json), 27 October 2026

Nothing in `firebase/` ships in the program; it only pins the Firebase command-line tool. GitHub's 7 alerts there (undici, fast-uri,
uuid) and npm's body-parser alert are fixed with exact `overrides` on patch versions (uuid 9 to 11: gaxios only calls `v4()`, which
is the same). One moderate item is accepted: `@opentelemetry/core` 1.30.1 (unbounded memory in W3C Baggage parsing) inside
`@google-cloud/pubsub`, which needs version 1 while the fix exists only in version 2. The tool runs on the owner's computer to deploy
rules and never parses Baggage headers from strangers. Look again when firebase-tools moves pubsub to OpenTelemetry 2.
