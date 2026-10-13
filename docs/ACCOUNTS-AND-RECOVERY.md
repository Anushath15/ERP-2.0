# Accounts and recovery

**No passwords, codes or keys are written in this file.** Keep them in a password manager and on paper (see below).

## Accounts that exist
| Account | What it is for | Owner | Notes |
|---|---|---|---|
| GitHub **Anushath15** | The code (public repository ERP-2.0), automatic builds (Actions), downloads (Releases) | Anushath | Turn on two-step sign-in. Keep the GitHub recovery codes safe. |
| **Shop Gmail** (the new Senthil Enterprises Gmail) | Owns the Firebase project (free Spark plan) and receives password-reset test emails | The shop | Do not use it for anything else. Add a recovery phone and a recovery email. Turn on 2-step verification. |
| **Personal Gmail** | Second **Owner** of the Firebase project, so a lost shop Gmail does not lock the shop out | Anushath | Added in the Firebase console under Project settings > Users and permissions. |
| Firebase project (Spark, no billing) | Online backup and sync (from Phase 2); the prototype web page (Hosting) | Both Gmails | **No billing account is ever attached.** |

## Where secrets are kept
1. **Password manager** (one entry per account above): password, recovery codes, the date 2-step verification was set up.
2. **Paper**, in the shop safe or at home, not in the shop counter drawer: each Gmail address, the Google recovery codes (print them from myaccount.google.com > Security > 2-Step Verification > Backup codes), and the GitHub recovery codes.
3. **Never** in the repository, in chat, in screenshots or in email. If a secret was ever pasted anywhere public, change it at once.
4. Later (Phase 2+): app configuration files with project keys stay on the PCs and are ignored by git; only `*.example` files are in the repository.

## If the shop Gmail is lost or hacked
1. Sign in with the **personal Gmail** (second Owner) at <https://console.firebase.google.com>.
2. Project settings > Users and permissions: add a new shop Gmail as **Owner**, then remove the old one.
3. Try to recover the old Gmail at <https://accounts.google.com/signin/recovery> with the recovery phone and codes; if it was hacked, also change its password and sign out all devices.
4. Nothing in the shop's data is lost: every PC keeps its own full copy (the app is offline-first). The Firebase copy is a backup and the way devices share data.
5. If **both** Gmails are lost: the data on each shop PC is still there. Make a backup file from Settings, create a new Firebase project (OWNER-SETUP step 3), and I reconnect the app to it.

## Add or remove an owner
Console > Project settings (gear) > **Users and permissions** > **Add member** (enter the Gmail, role **Owner**). To remove: the three dots next to the name > **Remove access**. Always keep at least two Owners.

## See the free-tier usage
Console > **Firestore Database > Usage** tab (reads, writes, deletes, storage per day against the free limits: 50,000 reads, 20,000 writes, 1 GiB stored). Console > **Hosting** shows downloads. Console > bottom-left shows the plan: it must say **Spark (no cost)**. Look weekly during the pilot. See [quota-budget.md](quota-budget.md).

## Shut the project down
1. Make a full backup from the app (Settings > Backup).
2. Console > Project settings > General > **Delete project** (it is kept for 30 days and can be restored in that time). Turn off the Hosting site first if you only want the website gone: Hosting > the three dots > **Disable site**.
3. The code on GitHub is separate; deleting the Firebase project does not touch it.
