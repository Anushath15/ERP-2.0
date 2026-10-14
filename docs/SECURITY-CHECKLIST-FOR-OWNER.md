# Security checklist for the owner

Plain English. Nothing here needs coding. The program protects the shop's data with Google's sign-in and strict rules, but **the biggest risk is a person, not the program**: someone who gets into your Gmail or your phone. These steps close that door.

## 1. Do these once (about 30 minutes)

**Turn on two-step verification on every account that matters.** That means: the shop Gmail, your personal Gmail, and your GitHub account. With it, a stolen password alone is useless.
1. Open <https://myaccount.google.com/signinoptions/twosv> (signed in to that Google account) and follow the steps. Choose a **passkey** or the **Google Authenticator app** on your phone, not only text messages.
2. For GitHub: <https://github.com/settings/security>, then Two-factor authentication, then add a **passkey** or an authenticator app.
3. **Print the backup codes** each service gives you. Write the account name on the page and keep the paper somewhere locked (not in the shop's open drawer, not in a photo on the phone). Those codes are how you get back in if the phone is lost.
4. Check that **both** owner Google accounts have it. The Firebase project has two Owners so you can always get back in; that only helps if both are protected.

**Approve releases on GitHub (one click each time).** Settings, Environments, `release`: it already lists you as the person who must approve. Every release stops and waits for your click. Do not approve a release you did not start yourself.

**Free GitHub protections** (already switched on by the setup; just look): Settings, Code security: Secret scanning, Push protection, Dependabot alerts, Private vulnerability reporting.

## 2. Never sign in from a link someone sends you
- Emails, WhatsApp messages and texts that say "your account will be closed", "verify now", "your bill", "Firebase billing" or "someone logged in" are the usual trick. **Do not tap the link.**
- Instead open a new browser tab and type the address yourself: `accounts.google.com`, `console.firebase.google.com`, `github.com`.
- **How to recognise a fake Google sign-in page:** the address bar must say exactly `accounts.google.com` (look at the part just before the first `/`, and watch for look-alikes such as `accounts-google.com`, `google.com.something.com`, `g00gle`). Google never asks you to sign in because of a WhatsApp message, and never asks you to read a code to a stranger on the phone. If a page asks for the 6-digit code **and** you did not just try to sign in yourself, close it.
- The program itself only ever opens Google's own sign-in. It never asks for your password anywhere else.
- Nobody from "Google", "Firebase", "GitHub", "the bank" or "the program" will ever ask you for your password, a code, or a backup code. Not even the person who built this program.

## 3. Who has which role
The program has three roles. Only the Owner can change them.

| Role | What this person can do |
|---|---|
| Cashier | Bill, take payments, add a brand-new customer (credit limit 0), write customer notes, send a reminder. Cannot change prices, products or limits. |
| Manager | Everything a cashier does, plus products, prices, customers, dealers, purchases, stock adjustments and reports. Cannot cancel a bill, write off, change the shop profile, or approve devices. |
| Owner | Everything, including approving devices and cancelling bills. Keep this to you and your second owner. |

Keep a paper list: **name, e-mail, role, date added.** The **Security** card in the program (Settings page) shows the live list.

## 4. A new phone or computer wants to join
1. The new device asks to join. It shows in the program under Settings, Security, as **Waiting for your approval**.
2. Check with the person (a phone call, not a message) that it is really their new device.
3. Press **Approve** only then. If you do not recognise it, do nothing and read section 5.

## 5. How to remove a person or stop a device (3 minutes, in this order)
1. **Stop the device:** Settings, Security, **Stop this device**. Its changes are refused at once.
2. **Disable the sign-in:** Firebase console, Authentication, Users, the person's row, menu, **Disable account**.
3. **Remove the e-mail from the allowed list.** Ask the person who looks after the program to do this: it is one small change and a redeploy of the rules. After this the person is refused even with a new account.
4. If a password was shared, change it.

Steps 1 and 2 work immediately. A phone that was already signed in can still read for up to an hour after step 2 (a Google limit); step 1 stops its changes at once.

## 6. If your phone or your Gmail is stolen or hacked
Do these in order, from a **different** device (a friend's, or the shop PC):
1. Go to <https://myaccount.google.com/security>, **Your devices**, sign out the stolen phone, then change the Google password. Use the printed backup codes if you cannot get a code on the phone.
2. Ask your SIM provider to block the SIM and issue a new one (this stops text-message codes going to the thief).
3. In the Firebase console, Authentication, **disable** the stolen account's user, and in the program press **Stop this device** for the stolen phone. The second owner can do this.
4. Look at **Last sign-ins** in Settings, Security for anything you do not recognise. Also look at your Gmail security alerts.
5. Tell the person who looks after the program, so the rules can be redeployed without that address.
6. Keep the paper backup codes safe, then create new ones once you are back in.

This is why there must **always be two Owners** on the Firebase project: if one account is lost, the other can still lock the thief out.

## 7. Once a month (5 minutes)
- [ ] Settings, Security: every person and every device on the list is someone and something you know. Stop anything you do not.
- [ ] Last sign-ins: nothing strange (odd hour, place, device).
- [ ] The Firebase console shows the **Spark (free)** badge. **Never** press Upgrade and never add a billing account.
- [ ] Firebase console, Usage: the daily numbers are far below the limit. If the program ever shows **"Sync paused: daily limit reached"**, nothing is lost and nothing is charged; it starts again after the next reset. If it happens when the shop is quiet, someone may be misusing an account: follow section 5.
- [ ] Two-step verification is still on for both Google accounts and GitHub.
- [ ] You still have the printed backup codes.
- [ ] Windows updates are installed on the shop PC, and a backup was copied to a pen drive.
