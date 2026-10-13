# ASK ERP 2.0 - Senthil Enterprises

A fast shop-management app (billing, estimations, stock, purchases, customers,
dealers, credit, expenses, reports) for a hardware / electrical / plumbing shop in India.

One app for Windows, Mac, Android and the web. It works fully offline. When the internet
is available it quietly copies your data to a free online backup. It costs nothing to run.

[![CI](https://github.com/Anushath15/ERP-2.0/actions/workflows/ci.yml/badge.svg)](https://github.com/Anushath15/ERP-2.0/actions/workflows/ci.yml)

**Status:** Phase 1 prototype (all screens with made-up sample data) is ready for owner review. Nothing is saved, sent or printed yet. See [docs/PROGRESS.md](docs/PROGRESS.md).

## Try it (no coding needed)
1. Open the newest **pre-release** on the [Releases page](https://github.com/Anushath15/ERP-2.0/releases).
2. Download the **Windows zip**, unzip it and double-click `ASK_ERP_2.exe` (or use the **web zip**).
3. Follow the 15-minute walkthrough in [docs/REVIEW-GUIDE.md](docs/REVIEW-GUIDE.md).

Pictures of the main screens: [docs/ui-review](docs/ui-review/index.md) (the full set is attached to each release).

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
