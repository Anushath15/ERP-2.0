# Review guide: try the prototype in 15 minutes

**Everything you see is made-up sample data. Nothing is saved when you close the program, and nothing is ever sent: no WhatsApp message, no print, no cloud.** You cannot damage anything. Close and reopen to start fresh.

## 1. Open it
- **Windows:** unzip the `ASK-ERP-2.0-windows-...zip` from the `dist` folder and double-click `ASK_ERP_2.exe`. (If Windows shows a blue "protected your PC" box, press More info, then Run anyway: the program is not signed yet.)
- **Web:** unzip the `ASK-ERP-2.0-web-...zip`, open `index.html` through a local web server (the guide in `PROGRESS.md` shows how), or just use the Windows one.

## 2. A ₹150 bill where the customer gives ₹100
1. Press **New bill** on the left.
2. Click any product to add it. In the bill list, change its **Rate** to 150 and keep the quantity at 1. The **Grand total** at the bottom right is the amount to use (it may differ by a few paise because of tax rounding; use what it shows).
3. Press **Choose customer** (top right of the bill) and pick any customer.
4. In **Amount received**, type 100. You should see: *"Balance ₹50 will be added to <customer>'s credit"*. The **Cash / UPI / Card or other** buttons choose how they paid.
5. Press **Save bill**. Check the message at the bottom.

## 3. See the ₹50 in Money to collect
1. Press **Money to collect** on the left. The list shows who owes what, how old, and who was already reminded.
2. Find your customer (use the search box). Their balance includes the ₹50.
3. Tap the customer's name: you get their page with the balance, credit limit, ageing (0-30 / 31-60 / 61-90 / 90+ days), the list of unpaid bills, the full ledger, and reminder history.
4. Press **Receive payment**. The money is applied to the oldest bill first. Try typing more than they owe: the extra becomes an **advance**.
5. Press **Statement** to see the printable statement, and **Save as PDF** to make a real PDF file (it goes to your Downloads folder; in the web version it downloads).

## 4. A WhatsApp reminder, and Undo
1. On Money to collect (or the customer page) press **Remind on WhatsApp** for a customer who owes money.
2. Read the message. Switch **Friendly / Firm**. You can type in the message box to change it.
3. Press **Open WhatsApp**. On a PC with WhatsApp it opens a chat with the message ready; **you** press Send. The program never sends anything.
4. A bar appears for 8 seconds: **Not sent? Undo**. Press it and the "reminded" count goes back down.
5. Press Remind again within 24 hours: it asks "Send again?" first.
6. In the top bar, the cloud chip shows "Synced". Click the sync state in **Settings** (Preview only: try each state) and choose **Offline**: the reminder button now says it needs internet and offers **Copy message** instead.
7. Reminder wording, your shop phone and UPI ID live in **Settings > Reminders**.

## 5. A walk-in with a balance
1. **New bill**, add a product, leave the customer as **Walk-in customer**.
2. Type a smaller number in **Amount received** than the total. The footer says a customer is needed.
3. Press **Save bill**: it asks you to choose or add a customer (name and phone). The bill is not saved until you do.

## 6. Big text (200%)
- Press **A+** in the top bar several times, or use **Settings > Appearance > Text size** and pick 200%. Walk through New bill, Money to collect and a customer page. Nothing should be cut off, and the bill total and buttons stay at the bottom.
- Reset with **Ctrl 0**.

## 7. A bill with 100 lines
- On **New bill**, press **Ctrl + Shift + L**. It fills the bill with 100 sample lines (preview only; "Clear" empties it). Scroll the list: the **Grand total, Amount received, balance line and Save buttons stay exactly where they are** while the lines scroll above them.
- Try it with big text and with the window made smaller too.

## What to tell me
Anything that is confusing, ugly, too small, too slow, or in the wrong place, and any wording that you would not say to a customer. A list is perfect. **I do not start Phase 2 (the real database and syncing) until you say "go".**

## Things this prototype cannot show yet
Real printing, a real WhatsApp send, saving anything, syncing between devices, a barcode scanner. These come in later phases and are not tested yet.
