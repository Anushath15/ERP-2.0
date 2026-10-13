# Motion guide

Rule number one: **motion never delays work.** Every animation starts after the action has already happened (the bill line is already in the bill, the bill is already saved, the page is already the new page). A tap, key press, scan, save or print never waits for an animation. Durations are 90-250 ms with ease-out or ease-in-out curves. Only cheap effects are used: opacity, move, scale, colour. No blur, no `BackdropFilter`, no animated shadows, no looping animations (one tiny exception: the sync icon while syncing). Nothing animates while you type in a search box or while search results update. Big lists and the billing table sit inside a `RepaintBoundary`.

Code: `lib/design/motion.dart` (the rules), `lib/design/effects.dart` (the effects), `lib/design/frame_guard.dart` (auto-protect), `lib/core/sound.dart` (optional sounds).

## The three levels (Settings > Animations, per device, never synced)
| Level | What moves |
|---|---|
| **Full** | everything below |
| **Gentle** (default) | page, window and tab transitions, menu fold, press and focus effects, ripple; no billing effects |
| **Off** | nothing moves (instant) |

"Follow my computer reduce-motion setting" (default on): if Windows, macOS, Android or the browser asks for reduced motion, the level is treated as Off, whatever was chosen. Switch it off to ignore the system.

**Auto-protect:** the app watches how long frames take (only in profile and release builds, only while something is moving). If the average is below 45 frames per second for about 3 seconds (at least 40 frames), it drops one level for this device (Full -> Gentle -> Off), waits 8 seconds before it may drop again, and Settings shows a calm one-line note with a "Turn animations back on" button. An idle app makes no frames, so it cannot trigger by itself. Tested with synthetic frame times in `test/motion_test.dart`.

## Every animation
| Animation | Trigger | Duration, curve | Level needed | Turned off by |
|---|---|---|---|---|
| Page change: soft fade with a short slide (1.5% of the width) | go to another screen | 180 ms in / 120 ms out, ease-out / ease-in | Gentle, Full | Off, system reduce-motion |
| Dialog and bottom sheet: scale / slide in | open a form, detail, confirm, customer list | 170 ms in / 120 ms out, ease-out / ease-in | Gentle, Full | Off |
| Menu fold / unfold (left menu width) | menu button in the top bar | 200 ms, ease-out; labels appear only when there is room | Gentle, Full | Off |
| Sliding selection in segmented controls (payment mode, Products/Bill tab, settings choices) | tap a choice | 180 ms, ease-out | Gentle, Full | Off |
| Ripple on taps | tap a button or row | Flutter ink ripple | Gentle, Full | Off |
| Press: button shrinks 3% while pressed | pointer down on Save, Save and print, Preview, the Home quick buttons | 90 ms, ease-out | Gentle, Full | Off |
| Keyboard focus ring (thick outline) | Tab / arrow focus | instant (not animated) | always | never (accessibility) |
| Row highlight on hover and keyboard selection | mouse over a table row, Up/Down in the product table | instant | always | never |
| Hover lift of stat cards (moves up 2.5%) | mouse over a card | 140 ms, ease-out | Full | Gentle, Off |
| New bill line slides in from the right and flashes briefly | a product is added | 220 ms, ease-out; flash fades with it | Full | Gentle, Off |
| Quantity pulse (one small grow and return) | change a line quantity | 180 ms | Full | Gentle, Off |
| Totals count to the new value | the bill changes | 180 ms, ease-out; the real total is already in the state | Full | Gentle, Off |
| Small check mark on the product row that was added | product added from the table | fades in 150 ms, stays 0.9 s | Full | Gentle, Off |
| Success check (big green tick) | Save or Save and print | 750 ms total, pops in 190 ms, fades last 225 ms; ignores taps | Full | Gentle, Off |
| One calm shake | invalid input in a form or sign-in (the message is shown beside the field at the same time) | 260 ms, one short shake | Full | Gentle, Off |
| Skeleton placeholder (soft moving highlight) | something loads for more than 150 ms (demo: reading an ERP 1 backup) | loops while loading | Full (Gentle and Off show a plain spinner) | Gentle, Off |
| Empty-state fade and rise | an empty list is shown | 250 ms | Full | Gentle, Off |
| Toasts slide in and out | any confirmation | Flutter's floating snack bar | Gentle, Full | Off (instant) |
| Sync icon pulse | only while the state is "Syncing" | 900 ms loop, opacity only | Gentle, Full | Off |

Nothing else moves. In particular nothing animates in the product search, the barcode scan path or the bill-line list while you work, other than the single new line and the number count-up listed above.

## Optional sounds (Settings > Sounds, per device)
Default: **scan beep ON**, save tone OFF, error tone OFF, volume 70%. In this prototype the sounds use the computer's own beep (no audio plugin yet), so the volume control is stored but only takes effect when real audio is added in Phase 2. Sounds are fire-and-forget: they never delay a scan, save or print. Sounds are independent of the animation level.

## How it is proven
- `test/motion_test.dart`: Off has no transition; Gentle and Full fade pages in and finish by 310 ms; the system reduce-motion setting forces Off (and is ignored when switched off); Full-only effects play only in Full; after a scan or Save the state is already updated in the very next frame with effects on and off; the skeleton appears only after 150 ms; the sync pulse runs only while syncing; the frame guard reduces once after a slow stretch and never for 60 fps or idle; sounds obey their switches.
- `docs/perf-results.md`: frame times of the billing flow with Full animations (Windows profile build).
