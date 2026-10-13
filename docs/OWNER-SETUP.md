# Things only you can do

Do these when you are ready. Nothing waits on them until the step says so. Never give me a password, a code or a key: every sign-in happens in a browser window that you complete. Accounts and recovery: [ACCOUNTS-AND-RECOVERY.md](ACCOUNTS-AND-RECOVERY.md).

## 1. Windows Developer Mode (needed before Phase 2 builds with plugins, 1 minute)
1. Press the Windows key, type **Developer settings**, press Enter.
2. Switch **Developer Mode** to **On** and click **Yes**.
It lets the app builder create shortcuts that some app parts need. It does not change how your shop PC works.

## 2. GitHub (done)
The repository is <https://github.com/Anushath15/ERP-2.0>. For the command-line tool, run `gh auth login --web --git-protocol https` and enter the code in the browser.

## 3. The shop Gmail (you do this first)
1. Create a new Gmail for the shop (for example `senthilenterprises.erp@gmail.com`). Add a recovery phone and a recovery email. Turn on 2-step verification and print the backup codes.
2. Save its password in your password manager and on paper. Tell me **only the address**.

## 4. Firebase project (free Spark plan; I do most of it, you click only where marked)
1. Terminal: `firebase login`, then **sign in with the shop Gmail** in the browser window and press Allow. (If another Gmail is already signed in, run `firebase logout` first.)
2. I create the project (id such as `senthil-erp-2`) with Analytics OFF and check that **no billing account** is attached.
3. Firestore database: I create the (default) database in **production mode** with deny-all rules in **asia-south1 (Mumbai)**. The location cannot be changed later; the reasoning is in [architecture.md](architecture.md) / PROGRESS.
4. **Authentication** (click-by-click if the tool cannot): Console > Build > Authentication > Get started > Sign-in method > turn on **Email/Password**, then **Google** (support email = the shop Gmail) > Save. Do **not** turn on Phone.
5. **Password reset email:** Authentication > Templates > Password reset > the pencil: sender name `Senthil Enterprises`, subject `Reset your Senthil Enterprises password`, then Save. I tell you when to test it: use "Forgot password" for the shop Gmail; the email must arrive at the shop Gmail (check Spam too).
6. **Second owner:** Console > gear > Project settings > **Users and permissions** > Add member > your personal Gmail > role **Owner**.
7. Web app: I register it. Keep the config values private; they are never committed.
8. Hosting: I publish the Phase 1 prototype (sample data only) at `project-id.web.app`.
9. Check **Usage and billing** shows **Spark**. Never click Upgrade or add a card.

## 5. Later
- Android phone: allow "install from unknown sources" for the test APK (Phase 4).
- Keep the Android signing key file safe (Phase 4): copy it to a USB drive and one more place. If it is lost, updates to the same app are impossible.
- Windows may warn "Windows protected your PC" for the unsigned installer: click **More info > Run anyway**.
