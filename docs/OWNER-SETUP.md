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
6. (Decided: there is NO Google sign-in. The program signs in with e-mail and password only.)
6b. **Sign-in in the program (built, e-mail and password).** What is needed from you, once:
   - **Build with the cloud address:** `flutter build windows --release --no-tree-shake-icons --dart-define-from-file=supabase/config.local.json`. Keep `--no-tree-shake-icons`: without it the build dropped 7 of the icons the program uses (they showed blank). Without it the program opens as before, with no sign-in (local only).
   - **First sign-in:** make the account with e-mail and password (**First time? Make the shop account**) and open the link it sends. The program will say "this account has no access to the shop yet" until you run `supabase/seed_shop.example.sql` once with the two shop e-mails. After that: sign in once per computer; opening the program never asks again; only **Sign out** (Shop profile) asks again.
7. Add the same two addresses as members of the organisation (Organization settings > Team) so one person can never lock you out.
Keep-alive: the free plan pauses an unused project after about a week; see docs/supabase-sync-design.md.

## 7. Locked backup copy in Telegram (free)
Backups > **Backup to Telegram** sends a locked (AES-256) copy of the shop data to your own private channel every evening (from 8 PM, or when the program closes). It is an extra copy: keep the pen-drive / folder backups too.
1. In Telegram open **@BotFather**, send `/newbot`, choose a name, and copy the **token** it gives you. Never post the token anywhere.
2. Make a **private channel**. Channel settings > Administrators > Add your bot, and let it **post messages**.
3. Post any message in the channel (for example "hello").
4. In the program: Backups > Backup to Telegram > **Set up**. Paste the token, leave the channel empty (it is found by itself), and press **Make a password for me** (or type your own, at least 10 characters). **Write the password on paper and keep it safe: without it the backups cannot be opened, and nobody can recover it.** Press Connect: a test message arrives in the channel.
5. **To restore from Telegram:** download the `.askbak` file from the channel, then Backups > Restore > **Open a locked backup (from Telegram)**, choose the file and type the password. It is checked and restored like any other backup.
Files up to 50 MB can be sent (a shop file compresses to a few MB). Telegram is not a backup service: if the channel or the account is deleted the copies go with it.

## 8. Cloud sync (Gate 2E)
In Supabase > SQL Editor run, in this order, once: `supabase/migrations/0001_sync.sql`, `supabase/migrations/0002_sync_names.sql`, `supabase/migrations/0003_owner_only_actions.sql`, `supabase/migrations/0004_saved_bills_fixed.sql`, then `supabase/seed_shop.example.sql` with the shop e-mails (see section 6b). Build with the cloud address (`--dart-define-from-file=supabase/config.local.json`), sign in, and the status badge changes from the preview to the real state; Settings > Sync shows what is waiting and has **Sync now**. The first sync uploads everything already in the program. On a second computer, install the program, sign in, and let it finish the first sync before billing.

## 9. Thermal receipt printer, direct (optional, 2 minutes at the counter)

1. Settings > Printing: choose the paper **80 mm** (or **58 mm**) and pick the receipt printer as the bill printer.
2. Settings > Thermal printer, direct: choose **Bill printer** (USB or shared printer that Windows knows) or **Network** and type its
   address, like `192.168.1.50` (port 9100 is used when none is typed).
3. Press **Print a test slip**. The row of numbers must fill exactly one line. If it is cut off on an 80 mm printer, pick **42** letters
   per line and print the test slip again.
4. With a cash drawer plugged into the printer: switch on **Open the cash drawer for cash bills** and press **Open drawer** once to check.
5. If the printer is off or the cable is out, bills still print the normal way and the program says so.

## 10. Updates

The program looks for a newer version on the GitHub page about 25 seconds after it starts (About page: **Check for updates**). It finds
one only after a release is published there with the Setup .exe attached, for example:
`gh release create v2.1.0 ASK-ERP-2.0-Setup.exe --title "ASK ERP 2.1.0" --notes "..."`. The repository is public, so the release is public.

## 11. The phone app (Android)

**Install** (no Play Store needed):
1. Copy `ASK-ERP-2.0.apk` to the phone: by USB cable, from the pen drive with an OTG adapter, or send it to yourself on WhatsApp or Google Drive.
2. On the phone, tap the file. Android asks to allow installing apps from this source (Files, WhatsApp or Drive): allow it once, then tap
   **Install**. If Play Protect warns that the app is unknown, choose **Install anyway** (the app is the shop's own, not from the Play Store).
3. Open **ASK ERP 2.0**. A new phone first asks the 7 set-up questions (shop name, GST, bill numbers, logo, printer, stock), then shows **Sign in**.
   In the question "The letter of THIS computer" the letter **A is not offered on a phone**: it belongs to the shop's main computer. Choose another letter
   (for example **B**) and never give two devices the same letter, or they could make the same bill number.
4. Sign in with the shop account, and on the shop computer approve the phone (Settings > Security > Devices). The phone then fills itself from the cloud copy.

**On the phone**: Download PDF / Excel saves into the phone's Downloads/ASK ERP 2.0 folder (the Files app shows it). Send on WhatsApp opens
the customer's chat with the PDF and the message already attached: check and press Send. Print opens the phone's own print window (a Wi-Fi
printer, or Save as PDF). The thermal printer works only by its network address on a phone.

**Back button**: Back (or the back swipe) goes to the page before, then to Home; on Home press it twice to close the program. The Bill page has its own back arrow.
A bill that is not saved yet is kept on the phone and comes back when you open the Bill page again.

**Backups on a phone**: the backup file is kept inside the program, and every backup is also copied to the phone's Downloads/ASK ERP 2.0 folder (one file, replaced each time).
On Backups use **Save a copy in Downloads** or **Send a copy...** (Google Drive, WhatsApp, e-mail). Do this before you remove the program or change the phone:
the copy inside the program disappears with it.

**Updates**: install the new APK over the old one; the data stays. Android installs an update only when it is signed with the SAME key:
`android/ask-erp-release.jks` with `android/key.properties` (both kept out of git). Keep a safe copy of these two files; without them an update
cannot be installed over the old app (it would have to be removed first, and the phone would sign in and fill itself again).
Every new APK also needs a higher build number than the one on the phone, or Android refuses to install it as an update: build with
`flutter build apk --release --no-tree-shake-icons --build-number=N` (N higher than before; the first APK was 1, this one is 2). The number is given on the
command line so `pubspec.yaml` (which the Windows program reads too) stays as it is.
