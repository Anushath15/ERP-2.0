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

### The shape of every record (finding 6)
Each collection lists its exact fields: required and allowed fields only (unknown fields refused), integer paise within a range (no strings, fractions, negatives), string length limits, enums, list length limits, `id` equal to the path, `createdBy` equal to the signed-in e-mail, a plausible date (not older than about 2 years, not more than a day ahead) and the server time stamp. Tests: `rules_fields_test` (-999999 price, string price, 10,000-character name, unknown field, forged creator, wrong id, oversized lists, wrong signs, double party on a payment...). NaN cannot be sent through the REST API's JSON; a double of any kind is refused because every money field must be an integer.

### Device approval (finding 7)
A device is a document `devices/{id}` that **a new device can only create as "pending"** for its own signed-in e-mail. Only the owner can change it to "approved" or "revoked" (in the app's Security card). Every business write is checked by the rules with a `get()` of that device document: it must exist, be approved (not pending or revoked) and belong to the signed-in e-mail. A client that invents or copies a device id gets nothing: a pending or unknown id is refused, and another person's approved id is refused because the e-mail does not match.
**What this cannot stop:** an approved device that is stolen while signed in keeps working until the owner revokes the device (or removes the person from the list, or disables the user in Authentication). All three take effect on the very next request, but nothing detects the theft by itself. A person who is signed in on an approved device can still do everything their role allows.

### Write-spam and quota abuse (finding 9)
Spark stops at its free limits (20,000 writes and 50,000 reads a day) and **cannot charge money**: the project has no billing account, and without one Google refuses requests over the limit. The risk is therefore *denial of service* (a rogue or stolen account uses up the day's free writes, the shop cannot sync until the reset), not a bill.
Layers, best to worst:
1. **Per-person daily counter.** Every business batch must also move the person's counter document `usage/{email}_{day}` up by exactly one, and the rules refuse a number above the role's cap (default per day: owner 4,000, manager 3,000, cashier 1,500 batches; the app uploads about 144 batches a day at most, so honest use is far below). A rogue account can therefore do at most its cap of batches a day. **Honest limit:** the rules cannot see how many documents are inside a batch (up to 500), so the cap limits batches, not documents; one account could still use the whole free day with big batches. The cap and the device checks make that visible and stoppable, they do not make it impossible.
2. The in-app quota guard (`docs/quota-budget.md`) pauses non-essential sync at 70% and uploads at 90%, and the app shows **"Sync paused: daily limit reached"** with a calm explanation (everything is safe on this computer, copying restarts tomorrow, nothing is charged).
3. **App Check: not used.** Firebase App Check proves a request comes from the real app. The free providers (reCAPTCHA v3 / Enterprise for web, Play Integrity for Android, App Attest / DeviceCheck for Apple) cover web, Android, iOS and macOS only. There is **no provider for Windows**, and the shop's main computer is Windows, so App Check could not be required without locking that computer out. On top of that the app talks to Firestore over REST, where a token can be copied by anybody who holds it. Decision: not enabled; revisit if Windows gets a provider. It would not stop a person with a valid sign-in in any case.
4. **Emergency procedure** (the owner does this in about 3 minutes; written step by step in `docs/SECURITY-CHECKLIST-FOR-OWNER.md`): (a) in the app's Security card, **revoke** the suspicious device; (b) in Firebase console > Authentication > Users, **disable** the user; (c) remove the address from the lists in `allowed-emails.local.json` and redeploy the rules (`dart run tool/make_rules.dart` then `firebase deploy --only firestore:rules --config firebase.deploy.json --project ask-erp-2`); (d) change the Google password. (a) and (b) take effect at once for new requests; a token already issued still reads for up to one hour (Firebase limit).

### What the checks cost (finding 7 and 9), measured on the emulator
Per uploaded batch the rules read two extra documents (the device record and the day's counter) and the app writes one extra document (the counter). A repeated mention of the same document in one request is counted once; a batch of 499 documents with the device and counter checks was accepted by the emulator (`rules_devices_usage_test`), so the 20-lookup limit is not reached. An edit of a price, cost or credit limit also reads its audit record once. Worst case at the app's pace (one batch every 10 minutes, 144 a day, per device): +144 writes and +288 reads a day for each device, about 0.7% of the daily write limit and 0.6% of the read limit. Real billing of rule lookups was not observed on the real project (see `docs/quota-budget.md`, "Not verified").

### No billing account, ever
The project is on the Spark plan. The owner confirms the "Spark" badge in the Firebase console (a step in `docs/OWNER-SETUP.md`); nothing in the repository can attach billing, there is no Blaze-only feature in use (no Functions, no Storage), and the instructions tell everybody never to upgrade. A test cannot prove the console state; it is a monthly line in the owner's checklist.

## Local settings are preferences, never permissions (finding 2)
`device.json` (Windows, macOS, Linux) and the browser's local storage hold **display preferences only**: theme, accent, text size, billing text size, density, font, animation level, sounds, paper size and print text size. Anybody who can sit at the computer can edit them, so:
- **Nothing security-related may ever be read from this file or from local storage.** There is no "this device is trusted" flag, no role, no "approved", no signed-in marker, no shop data. Permission always comes from Firebase (the rules check the signed-in e-mail, the allow-list, the device approval and the role on every request).
- Everything is validated on read: unknown keys are ignored, wrong types, unknown names, out-of-range and non-finite numbers go back to the defaults, and a missing, damaged, wrong-shaped, binary or oversized (over 64 KB) file means defaults, never a crash. Tests: `test/device_settings_integrity_test.dart`.


## Status of the ten review findings (2026-10-14)
| # | Finding | Status | What was done / what is left |
|---|---|---|---|
| 1 | Text becomes a file name or path (traversal, reserved names) | **Fixed** | One `safeFileName` and `isInside` check used by every save; numbered names, never silently overwrites; tests for `..\..\Startup\x`, `C:\evil`, `CON`, `NUL.pdf`, control characters. Restore and import only read files; no file name taken from them is ever written. |
| 2 | `device.json` / local storage trusted | **Fixed** | Preferences only, validated on read, unknown keys ignored; nothing security-related is read from it (section above). |
| 3 | Release and CI supply chain | **Fixed in code; owner clicks left** | Actions pinned to SHAs, read-only permissions, Dependabot, release only from a `v*` tag on main after CI, `release` environment with the owner as required reviewer (admin bypass off), checksums, build attestations, rulesets for tags and main. Left: the owner approves each release; signed commits are not required (accepted, below). |
| 4 | Injection through text (CSV formulas, WhatsApp link, hostile import, SQL, logs) | **Fixed / safe** | `csvCell` neutralises formulas; WhatsApp link strictly encoded and capped; imports go through a limited reader; no SQL built from text (guard test); the app logs nothing. |
| 5 | No roles: any member could change prices and limits | **Fixed** | Cashier / manager / owner in the rules; price, cost and credit-limit changes need an audit record in the same batch. |
| 6 | Rules accepted any shape of data | **Fixed** | Exact fields, integer paise, ranges, lengths, enums, id and creator checks; a test for each malformed case. |
| 7 | The client's device id was not a control | **Mitigated** | A new device can only write "pending"; only the owner approves; every business write needs an approved device of the same person. Left: a stolen, already approved device works until the owner stops it. |
| 8 | The people (phishing, stolen phone or Gmail, no two-step verification) | **Mitigated** | `docs/SECURITY-CHECKLIST-FOR-OWNER.md` and the Security card. The program cannot check two-step verification and says so. Left: the owner must turn it on and print the codes. |
| 9 | Write-spam / quota exhaustion | **Mitigated** | Per-person daily counter with a cap per role, quota guard, a clear "Sync paused" message, emergency procedure. Left: the cap counts batches, not documents; Spark stops at its limit and cannot bill; App Check is not possible on Windows. |
| 10 | Downloads are unsigned and unverifiable | **Mitigated; signing accepted for now** | SHA-256 checksums, build attestations, "Verify your download", the honest "Unknown publisher" explanation. Free signing (SignPath Foundation) is researched in `docs/code-signing.md`; apply after the first real release. |

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
