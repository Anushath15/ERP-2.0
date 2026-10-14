# ASK ERP 2.0 - Senthil Enterprises

A fast shop-management app (billing, estimations, stock, purchases, customers,
dealers, credit, expenses, reports) for a hardware / electrical / plumbing shop in India.

One app for Windows, Mac, Android and the web. It works fully offline. When the internet
is available it quietly copies your data to a free online backup. It costs nothing to run.

[![CI](https://github.com/Anushath15/ERP-2.0/actions/workflows/ci.yml/badge.svg)](https://github.com/Anushath15/ERP-2.0/actions/workflows/ci.yml)

**Status:** Phase 1 prototype (all screens with made-up sample data) is ready for owner review. Nothing is saved, sent or printed yet. See [docs/PROGRESS.md](docs/PROGRESS.md).

## Try it (no coding needed)
1. Open the newest **pre-release** on the [Releases page](https://github.com/Anushath15/ERP-2.0/releases).
2. Download the **Windows zip** **and `SHA256SUMS.txt`** (or the web zip), check them as shown in [Verify your download](#verify-your-download), then unzip and double-click `ASK_ERP_2.exe`.
3. Follow the 15-minute walkthrough in [docs/REVIEW-GUIDE.md](docs/REVIEW-GUIDE.md).

Pictures of the main screens: [docs/ui-review](docs/ui-review/index.md) (the full set is attached to each release).

## Verify your download
Every release is built by GitHub from the code you can read here, after the owner pressed Approve. Before you open a download, check that it is the real one. Two minutes, no tools to install on Windows.

**Step 1: check the checksum (everybody).** Download the zip and `SHA256SUMS.txt` from the same release, put them in one folder, open PowerShell in that folder and run:
```powershell
Get-FileHash .\ASK-ERP-2.0-windows-v2.0.0-proto.3.zip -Algorithm SHA256
```
(use your file's real name). The long code it prints must be identical to the line for that file in `SHA256SUMS.txt`. If even one character differs, **delete the file and do not open it**.

**Step 2: check who built it (optional, stronger).** Install the GitHub command line (`gh`) once, then:
```powershell
gh attestation verify .\ASK-ERP-2.0-windows-v2.0.0-proto.3.zip --repo Anushath15/ERP-2.0
```
It must say the file was built by the `release.yml` workflow of `Anushath15/ERP-2.0` from a `v...` tag. A file that was changed after the build, or built anywhere else, fails.

**Why Windows says "Unknown publisher" or "protected your PC".** Windows only stops warning for programs signed with a paid certificate that proves the publisher's identity. This prototype is not signed yet (see [docs/code-signing.md](docs/code-signing.md)), so Windows cannot know who made it. That warning is **not** a sign of a virus, and its absence would not be a sign of safety. The checks above are what tell you the file is genuine. Only press More info, then Run anyway, for a file that passed Step 1.

Found something wrong? See [SECURITY.md](SECURITY.md).

## Run it from the source (developers)
```
flutter pub get
flutter run -d windows      # or: -d chrome
flutter analyze && flutter test
```
Needs Flutter 3.47 (see `pubspec.yaml`). The prototype needs no Firebase account and no secrets.

## Read more
- [Progress](docs/PROGRESS.md) - what is done, doing, next
- [Product requirements](docs/PRD.md)
- [Architecture](docs/architecture.md), [Data model](docs/data-model.md), [Sync design](docs/sync-design.md)
- [Free-plan budget](docs/quota-budget.md), [What can go wrong](docs/failure-modes.md)
- [Owner setup steps](docs/OWNER-SETUP.md)
- [Design system](docs/design-system.md), [Motion guide](docs/motion-guide.md), [Frame timing](docs/perf-results.md)

This repository contains no real shop data. Demo data is synthetic.
