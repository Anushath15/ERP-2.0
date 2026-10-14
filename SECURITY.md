# Security policy

ASK ERP 2.0 is a billing and stock program for one small shop. It is open source so that anybody can read how it works; that is also why security problems matter.

## Report a vulnerability
**Please do not open a public issue for a security problem.** Use GitHub's private reporting instead:

1. Open the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe what you found and how to repeat it. Do not include real customer data, passwords or keys.

You will get an answer within 7 days. This is a one-person project, so there is no bug bounty, but every report will be read, fixed if it is real, and credited if you wish.

If you cannot use the Security tab, open an issue that says only "I have a security report, please contact me" and no details.

## Supported versions
| Version | Supported |
|---|---|
| Latest pre-release (`v2.0.0-proto.*`) | Yes: fixes go into the next pre-release |
| Older pre-releases | No: update to the latest |
| ASK ERP 1.x | Not part of this repository |

There is no stable 2.0 release yet. Until there is, treat every download as a prototype with sample data only.

## What is and is not in scope
In scope: the Flutter app, the Firestore rules in `firebase/`, the build and release files in `.github/`, and the documents in `docs/`.
Out of scope: attacks that need the owner's computer, phone or Google account to be already taken over (see `docs/threat-model.md`, "What this cannot stop").

## Verifying a download
Every release comes with `SHA256SUMS.txt` and a signed build-provenance attestation. See "Verify your download" in the README.
