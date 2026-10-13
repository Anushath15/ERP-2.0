# Things only you can do

Do these when you are ready. Nothing waits on them until the step says so.

## 1. Turn on Windows Developer Mode (needed now, 1 minute)
1. Press the Windows key, type **Developer settings**, press Enter.
2. Switch **Developer Mode** to **On** and click **Yes**.
This lets the app builder create the shortcuts that app parts need. It does not change how your shop PC works.

## 2. Sign in to GitHub (needed to publish the code, 2 minutes)
1. Open **Windows Terminal** (or PowerShell).
2. Type `gh auth login` and press Enter.
3. Choose **GitHub.com**, **HTTPS**, **Login with a web browser**. Copy the 8-letter code, press Enter, paste it in the browser page and approve (account **Anushath15**).
After this I create the public repository **ERP-2.0** and push.

## 3. Create the Firebase project (needed before Phase 2 real sync)
Never add a billing account. Stay on the free **Spark** plan.
1. Go to <https://console.firebase.google.com> and sign in with your Gmail.
2. Click **Create a project**. Name: `senthil-erp`. Turn **Google Analytics OFF**. Click **Create project**.
3. Left menu **Build > Authentication > Get started**. Under **Sign-in method** turn on **Email/Password** and **Google** (choose your Gmail as support email).
4. Left menu **Build > Firestore Database > Create database**. Choose a location near you (**asia-south1 Mumbai**). Choose **Start in production mode**. (Locations cannot be changed later.)
5. Click the gear > **Project settings > Your apps**. Add apps: **Web**, **Android** (package name `in.senthil.erp2`), **Windows**, **macOS**. For each, copy the config values into the files I tell you (they stay on your PC and are never put on GitHub).
6. In a terminal run `firebase login`, then tell me. I publish the security rules with `firebase deploy --only firestore:rules`.
7. Check **Usage and billing** shows the **Spark** plan. Once a week during the pilot, look at **Firestore > Usage**.

## 4. Later
- Android phone: allow "install from unknown sources" for the test APK (Phase 4).
- Keep the Android signing key file safe (Phase 4): copy it to a USB drive and one more place. If it is lost, updates to the same app are impossible.
- Windows may warn "Windows protected your PC" for the unsigned installer: click **More info > Run anyway**.
