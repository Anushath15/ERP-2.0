# Progress

_Last updated: 2026-10-13_

## Status: Phase 0 (plan and spikes) - docs and runnable spikes done; some parts Not verified (see below)

## Done
- Environment: Flutter 3.47.7 (Dart 3.13.5) in `D:\dev\flutter`, GitHub CLI, Firebase CLI 15.33, Visual Studio Build Tools 2022 (C++), Chrome, JDK 21.
- ERP 1 archived: `erp-rc7` copied to `D:\Senthil Enterprises\ERP-1.0.1` (robocopy, 11,998 files, git history 244 commits, same head `25c4af5`, same working-tree changes, directory compare shows no differences). The original is untouched.
- Repo skeleton (MIT, SECURITY, README, .gitignore) and plan documents in `docs/`.
- Spikes: S1 (REST auth + Firestore + security rules, 6/6), S2 (SQLite/Drift performance, passed budgets), S3 (PDF, Tamil finding), S4 (sync chaos, 5/5). Details: [spikes.md](spikes.md).

## Doing / blocked
- **GitHub repo not created yet:** `gh` not signed in (owner said he will sign in himself). First step of the next session: `gh auth status`, create the public repo ERP-2.0, push.
- **Windows Developer Mode is off:** Flutter cannot build any project with plugins on this PC (symlinks). Owner: OWNER-SETUP step 1. Because of this the official Firebase SDK check (S1), Android and Web performance (S2) and a real print (S3) are Not verified.
- **Android SDK:** `D:\Android\Sdk` and `D:\AndroidStudio` existed at the start of this session and were gone by the time I checked again. I did not touch them. A fresh SDK is being installed in `D:\dev\android-sdk`.

## Next
Phase 1 (UI/UX first, fake data, no backend) starts after Phase 0 is committed and pushed. Phase 1 ends with "Ready for owner review"; I will not start Phase 2 until the owner says go.

## Decisions taken on my own (change by telling me)
1. Cloud layer = plain REST behind interfaces, not the official Firebase plugins (evidence: S1; reason in spikes.md).
2. Stock movements and ledger rows are derived locally from bills; only bills and non-derivable events are uploaded (keeps first restore under the 50,000 reads/day limit).
3. Pull cursor is (server timestamp, document id).
4. Invoice series is per device (`A-`, `B-`).
5. Start-up check is `quick_check`; full `integrity_check` weekly / on the Health page.
6. Stock valuation default: average cost, unpriced stock = 0.
7. Tamil on printed documents is rendered by Flutter's text engine and placed as an image.
8. Nothing was sent to the HP printer (no test page without the owner's say-so).
9. The folder `D:\Senthil Enterprises\ERP-2.0` did not exist, so I created it.

## Open questions for the owner
- Is ERP-2.0's parent folder meant to stay inside the existing git repository in `D:\Senthil Enterprises`? ERP-2.0 has its own separate git repository (it shows as one untracked folder in the parent).
- Which Google account owns the Firebase project (needed in step 3 of OWNER-SETUP)?
