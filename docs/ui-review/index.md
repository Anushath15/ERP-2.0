# UI review screenshots (key set)

Sample data only. These 11 pictures are the main screens. **The full set (about 320 pictures: every screen at phone, tablet and desktop, dark and light, and the text sizes) is attached to each GitHub pre-release as `ERP2-ui-review-screenshots-<date>-<commit>.zip`** to keep the repository small. You can regenerate everything yourself:

```
UI_REVIEW=1 flutter test test/ui_review/generate_test.dart
```

(the full list is then written to `docs/ui-review/index-full.md`, which git ignores).

| Screen | Picture |
|---|---|
| Home (desktop, dark) | ![](desktop/dark/dashboard.jpg) |
| New bill | ![](desktop/dark/billing.jpg) |
| Part payment: balance goes to credit | ![](desktop/dark/pos-part-paid.jpg) |
| Money to collect | ![](desktop/dark/credit.jpg) |
| Customer page (ageing, ledger, reminders) | ![](desktop/dark/customer-detail.jpg) |
| WhatsApp reminder preview | ![](desktop/dark/dlg-reminder.jpg) |
| Settings > Reminders | ![](desktop/dark/settings-reminders.jpg) |
| A4 invoice with Received and Balance (light) | ![](desktop/light/print-a4.jpg) |
| Phone: New bill | ![](phone/dark/billing.jpg) |
| Phone: Money to collect | ![](phone/dark/credit.jpg) |
| New bill at 200% text | ![](text-sizes/desktop/dark/pos_200.jpg) |

## Name and logo
The app is **ASK ERP 2.0**, with the same logo as ERP 1.0 (`assets/branding/ask-logo.png`; every icon is built from it by `dart run tool/make_icons.dart`).

![Taskbar with the ASK icon](brand-taskbar.png)
![Title bar: ASK ERP 2.0](brand-titlebar.png)
