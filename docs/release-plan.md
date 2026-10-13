# Release plan

- **Phase 1 preview:** Windows build + Web build, published as a GitHub Release zip (and Firebase Hosting preview if the owner has made the project). No data, no backend. Owner reviews.
- **CI (GitHub Actions, free for public repos):** analyze, test, build Windows, Android APK, Web, macOS (unsigned); artifacts attached to a Release. macOS runtime: Not verified (no Mac).
- **Windows:** portable zip and an installer (unsigned). Windows SmartScreen will say "Windows protected your PC" because the app is not code-signed (signing costs money). Click "More info" then "Run anyway". Explained in the owner guide.
- **Android:** signed APK. The keystore is created outside the repo; the owner must back it up (USB + a second place), because losing it blocks all future updates of the same app.
- **Web:** Firebase Hosting (free quota 10 GB storage, about 360 MB/day transfer).
- **Updates:** manual in v2.0 ("how to update" guide: close the app, run the new installer; data is outside the app folder and a backup is taken first). New versions refuse to open nothing newer than they understand; migrations are backed up and rolled back on failure.
- **Pilot:** ERP 1.0 keeps running at the shop. ERP 2.0 runs in parallel on one PC with real data imported from an ERP 1.0 backup; the owner decides when it has passed.
- **Docs for people:** `docs/OWNER-GUIDE.md` and a one-page father's guide in simple English and Tamil (Phase 4).
