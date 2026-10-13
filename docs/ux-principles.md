# UX principles

Plain words, short labels, icon + text, one main action per screen. Say "Money to collect", not "Receivables"; "Stock left", not "Inventory balance".
- Empty states teach ("No bills today. Press F2 to make the first bill").
- First-run wizard: shop name, GST number, address, logo, printer, opening stock.
- Undo for simple actions; destructive actions confirm with the name or amount ("Delete bill A-000123 for Rs. 4,520.00?").
- Never show stack traces, codes or raw exceptions. Every failure: what happened, what is safe ("Your bill is saved"), what to do.
- Dark theme by default, light option; both at contrast 4.5:1 or better (checked by a test over the token pairs).
- Text-size setting; honour system scaling (tested at 125% and 150% Windows scaling); semantics labels for screen readers.
- Keyboard first on desktop: F-keys, Ctrl+S, Ctrl+Shift+N, Esc, arrows + Enter in tables. Big touch targets (48 dp) on Android; lists and bottom sheets on phones.
- Billing screen: pinned totals and actions, inner scrolling, no blank gap, from 1920x1080 down to phone width.
- Sync status is always visible and honest (Synced / Syncing / Offline - saved on this PC / Needs attention).
- English only. Names and notes a person types stay exactly as typed.
- A small design system (colour, spacing, type, component tokens) is written in `docs/design-system.md` in Phase 1.
