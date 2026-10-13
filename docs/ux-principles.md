# UX principles

Plain words, short labels, icon + text, one main action per screen. Say "Money to collect", not "Receivables"; "Stock left", not "Inventory balance".
- Empty states teach ("No bills today. Press F2 to make the first bill").
- First-run wizard: shop name, GST number, address, logo, printer, opening stock.
- Undo for simple actions; destructive actions confirm with the name or amount ("Delete bill A-000123 for Rs. 4,520.00?").
- Never show stack traces, codes or raw exceptions. Every failure: what happened, what is safe ("Your bill is saved"), what to do.
- Dark theme by default, light option; both at contrast 4.5:1 or better (checked by a test over the token pairs).
- Text size 80% to 200% with presets, a live preview, Reset to normal, Ctrl+Plus / Ctrl+Minus / Ctrl+0 and A- / A+ in the top bar; applied on top of the system text size. A separate billing text size so product names can be very large without enlarging the whole app. Everything must still work at 200% (no overflow, nothing cut off, pinned billing footer always visible, dialogs scroll).
- Display choices per device, remembered, never synced: Dark / Light / Match my computer, five accent colours, High contrast, row density (Comfortable / Normal / Compact), letter style (Inter or Atkinson Hyperlegible).
- Motion that helps and never waits: short fades, slides and press effects; billing details (new line, count-up totals, success tick) only at Full; Gentle by default; Off; follows the computer's reduce-motion setting; auto-reduces on a slow computer. Optional sounds (scan beep on by default). See `docs/motion-guide.md`.
- Keyboard first on desktop: F-keys, Ctrl+S, Ctrl+Shift+N, Esc, arrows + Enter in tables. Big touch targets (48 dp) on Android; lists and bottom sheets on phones.
- Billing screen: pinned totals and actions, inner scrolling, no blank gap, from 1920x1080 down to phone width.
- Sync status is always visible and honest (Synced / Syncing / Offline - saved on this PC / Needs attention).
- English only. Names and notes a person types stay exactly as typed.
- A small design system (colour, spacing, type, component tokens) is in `docs/design-system.md`.
