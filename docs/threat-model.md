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

## Rules plan
`firebase/firestore.rules` (draft passes the emulator tests). Open items for Phase 2: per-role limits (cashier cannot edit prices, cannot delete products), per-collection field validation, a rules test for each role. Deploy with `firebase deploy --only firestore:rules` after the owner's `firebase login`.


## Local settings are preferences, never permissions (finding 2)
`device.json` (Windows, macOS, Linux) and the browser's local storage hold **display preferences only**: theme, accent, text size, billing text size, density, font, animation level, sounds, paper size and print text size. Anybody who can sit at the computer can edit them, so:
- **Nothing security-related may ever be read from this file or from local storage.** There is no "this device is trusted" flag, no role, no "approved", no signed-in marker, no shop data. Permission always comes from Firebase (the rules check the signed-in e-mail, the allow-list, the device approval and the role on every request).
- Everything is validated on read: unknown keys are ignored, wrong types, unknown names, out-of-range and non-finite numbers go back to the defaults, and a missing, damaged, wrong-shaped, binary or oversized (over 64 KB) file means defaults, never a crash. Tests: `test/device_settings_integrity_test.dart`.
