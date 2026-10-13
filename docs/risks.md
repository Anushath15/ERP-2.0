# Risks

| Risk | Likelihood | Impact | Mitigation / status |
|---|---|---|---|
| Windows Developer Mode off blocks plugin builds on this PC | Certain now | Blocks Flutter builds with plugins locally | Owner turns it on (OWNER-SETUP step 1); CI is unaffected |
| Tamil shaping in PDFs | Found | Garbled Tamil on prints | Rasterise Tamil runs (spike S3) |
| Whole-table reports are 1-2 s | Found | Slow report screens | Cache tables, isolate, progress bar |
| Web (WASM) Drift speed / OPFS support unproven | Medium | Slow web app | Spike in Phase 2 before wiring; web may be reports-only if slow |
| Google sign-in over REST on desktop | Medium | Only email+password on some platforms | Baseline is email+password; try Google on the real project |
| Cannot hard-revoke a stolen device without Functions | Certain | Read access until token expiry | Documented limit; revoke list + password change |
| Quota estimates are estimates | Medium | Surprise at scale | Quota guard; weekly check in Firebase console during pilot |
| No real printer / scanner / Mac / shop PC tested | Certain | Field bugs | Listed under "Not verified"; pilot |
| Android SDK on this PC disappeared mid-session | Happened | Android builds blocked here | Fresh SDK being installed in `D:\dev\android-sdk`; CI builds APK |
| Owner away when questions arise | Certain | Slow decisions | Take the most reasonable reading, record it in PROGRESS.md decisions |
| Public repo leaks shop data | Low | Severe | `.gitignore`, secret scan before every push, synthetic data only |
| Stolen device keeps read access up to 1 hour (no Functions to revoke tokens) | Low | Medium | End access fast: change the account password, remove the e-mail from the allowed list; optional PIN. See failure-modes #27 and OWNER-GUIDE (Phase 4) |
