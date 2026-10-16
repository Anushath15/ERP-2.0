# Things only you can do

Do these when you are ready. Nothing waits on them until the step says so. Never give me a password, a code or a key: every sign-in happens in a browser window that you complete. A step that needs a click only you can do says so.

## 1. Windows Developer Mode (needed before Phase 2 builds with plugins, 1 minute)
1. Press the Windows key, type **Developer settings**, press Enter.
2. Switch **Developer Mode** to **On** and click **Yes**.
It lets the app builder create shortcuts that some app parts need. It does not change how your shop PC works.

## 2. GitHub (done)
The repository is <https://github.com/Anushath15/ERP-2.0>. For the command-line tool, run `gh auth login --web --git-protocol https` and enter the code in the browser.

## 3. The Firebase project (made on 2026-10-14, free Spark plan)
- **Project id `ask-erp-2`** (display name "ASK ERP 2"). It belongs to **anushath15@gmail.com**, which is its Owner. Console: <https://console.firebase.google.com/project/ask-erp-2/overview>
- **Done by me:** the project; the Firestore database `(default)` in **asia-south1 (Mumbai)**, edition Standard, production mode (nobody can read or write until the rules say so), delete protection on; the security rules (only the two shop addresses in the rules can sign in); the Web app "ASK ERP 2 Web"; Hosting with the Phase 1 prototype at <https://ask-erp-2.web.app> (sample data only). **No billing account is attached.** Never add one and never click Upgrade.
- The app is **not** connected to this project yet (Phase 2).

## 4. Steps that only you can do (the tool cannot do them without a paid plan or your own sign-in)
**A. Turn on sign-in** (Authentication cannot be set up from the command line on the free plan). In your browser, signed in as anushath15@gmail.com:
1. Open <https://console.firebase.google.com/project/ask-erp-2/authentication> and press **Get started**.
2. Tab **Sign-in method** > **Email/Password** > switch **Enable** on (leave "Email link (passwordless sign-in)" off) > **Save**.
3. **Add new provider** > **Google** > switch **Enable** on > **Public-facing name for project**: `ASK ERP 2.0 / Senthil Enterprises` > **Support email for project**: choose anushath15@gmail.com (or the shop Gmail once it is an Owner) > **Save**.
4. Do **not** add Phone. No SMS sign-in.

**B. The name people see in emails.** Console > the gear next to **Project Overview** > **Project settings** > tab **General** > **Public-facing name**: `ASK ERP 2.0 / Senthil Enterprises` > **Save**.

**C. Password-reset email in plain English.** Authentication > tab **Templates** > **Password reset** > the pencil:
- Sender name: `ASK ERP 2.0 / Senthil Enterprises`
- Subject: `Reset your ASK ERP 2.0 / Senthil Enterprises password`
- Message (replace the whole text):
```
Hello,

You asked to reset the password for ASK ERP 2.0 / Senthil Enterprises (%EMAIL%).

Open this link and choose a new password:
%LINK%

If you did not ask for this, you can ignore this email. Your password stays the same.

Senthil Enterprises
```
Press **Save**. **Test it** when I say so: from the sign-in screen use "Forgot password" for the shop Gmail; the email must arrive there (look in Spam too).

**D. Add the shop Gmail as the second Owner.** (A command cannot do this: Google only makes someone an Owner after they accept an invitation.)
1. Console > the gear next to **Project Overview** > **Users and permissions** > **Add member**.
2. Email: `senthilenterprises.erp@gmail.com`, role **Owner** > **Add member**.
3. Open the invitation email in the shop Gmail and accept it. The shop Gmail then shows the project in <https://console.firebase.google.com>.
**Keep two Owners at all times** (see ACCOUNTS-AND-RECOVERY.md). If you later lower anushath15@gmail.com to Editor, that leaves the shop Gmail as the only Owner, which breaks the rule: first add another Owner you trust, or keep the personal account as Owner.

**E. Check there is no bill.** Console > bottom left of the sidebar shows the plan: it must say **Spark** (no cost). I checked on 2026-10-14 that no billing account is attached (billing enabled: no).

## 4b. Who may sign in to the shop data
The security rules contain the list of allowed e-mail addresses. The real addresses are **not** in the repository: they live in `firebase/allowed-emails.local.json` on this PC (git-ignored) and `dart run tool/make_rules.dart` builds the rules from it (`firebase/deploy/firestore.rules`). Today the list has two addresses: senthilenterprises.erp@gmail.com and anushath15@gmail.com. To add or remove a person: change that file, run `dart run tool/make_rules.dart`, then `firebase deploy --only firestore:rules --config firebase.deploy.json --project ask-erp-2` from the `firebase` folder. Run the rules tests first (see firebase-setup-notes.md).

## 5. Later
- Android phone: allow "install from unknown sources" for the test APK (Phase 4).
- Keep the Android signing key file safe (Phase 4): copy it to a USB drive and one more place. If it is lost, updates to the same app are impossible.
- Windows may warn "Windows protected your PC" for the unsigned installer: click **More info > Run anyway**.

## 6. Supabase (cloud database, free plan)
Do these yourself (I cannot create accounts, organisations or passwords for you):
1. <https://supabase.com/dashboard> > **New organization**: name `Senthil Enterprises`, type Personal, plan **Free**. Do not add a card.
2. **New project**: name `ask-erp-2`, region **Mumbai (ap-south-1)** if offered. Set a **Database password**: let the generator make it and save it in your password manager. Do not paste it in chat.
3. When the project is ready: **Project Settings > API**. Send me only the **Project URL** and the **anon / publishable** key (both are meant to be public). Never send the `service_role` or secret key.
4. **Authentication > Sign In / Providers**: keep **Email** on. Switch **Confirm email** on.
5. **SQL Editor**: I will tell you when `supabase/migrations/0001_sync.sql` has been tested; paste and Run it only then.
6. (Later, before the first sign-in) **Google sign-in**: Google Cloud console > new project `ask-erp-2-login` > APIs & Services > OAuth consent screen (External, app name `ASK ERP 2.0`, your e-mail) > Credentials > Create OAuth client ID (Web). Authorised redirect URI: `https://qksovlwyxpxahszjqdkz.supabase.co/auth/v1/callback`. Then Supabase > Authentication > Sign In / Providers > Google: paste the client ID and secret there (never in chat). I will give the desktop and Android details when Gate 2D starts.
7. Add the same two addresses as members of the organisation (Organization settings > Team) so one person can never lock you out.
Keep-alive: the free plan pauses an unused project after about a week; see docs/supabase-sync-design.md.
