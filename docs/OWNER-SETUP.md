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
3. Firestore database: I create the (default) database, edition **Standard**, location **asia-south1 (Mumbai)**, **production mode**, with deny-all rules first. The location cannot be changed later; the reasoning is in [firebase-setup-notes.md](firebase-setup-notes.md). Rules are deployed only after the emulator tests pass (24 checks today).
4. **Authentication** (click-by-click if the tool cannot do it): Console > **Build > Authentication > Get started** > tab **Sign-in method** > **Email/Password** > turn on **Enable** (leave "Email link" off) > Save. Then **Add new provider > Google** > Enable > **Public-facing name** `Senthil Enterprises`, **Support email** the shop Gmail > Save. Do **not** add Phone.
5. **Password reset email:** Authentication > tab **Templates** > **Password reset** > the pencil: Sender name `Senthil Enterprises`, Subject `Reset your Senthil Enterprises password`, Message in plain English, then Save. I tell you when to test it: on the sign-in screen use "Forgot password" for the shop Gmail; the email must arrive at the shop Gmail (check Spam too).
6. **Second owner:** Console > the gear next to **Project Overview** > **Users and permissions** > **Add member** > `anushath15@gmail.com` > role **Owner**. If it is already listed as Editor, open the role drop-down on its row and choose **Owner**, then Save.
7. Web app: I register it. Keep the config values private; they are never committed.
8. Hosting: I publish the Phase 1 prototype (sample data only) at `project-id.web.app`.
9. Check **Usage and billing** shows **Spark**. Never click Upgrade or add a card.

## 4b. Who may sign in to the shop data
The security rules contain the list of allowed e-mail addresses. The real addresses are **not** in the repository: they live in `firebase/allowed-emails.local.json` on this PC (git-ignored) and `dart run tool/make_rules.dart` builds the rules from it. To add or remove a person: change that file and ask me to redeploy (or run the same two commands yourself).

## 5. Later
- Android phone: allow "install from unknown sources" for the test APK (Phase 4).
- Keep the Android signing key file safe (Phase 4): copy it to a USB drive and one more place. If it is lost, updates to the same app are impossible.
- Windows may warn "Windows protected your PC" for the unsigned installer: click **More info > Run anyway**.
