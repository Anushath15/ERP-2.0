# Design system

Code: `lib/design/`. Everything on screen is built from these tokens and components, so screens look the same and a change in one place changes everywhere. Display choices (colours, text size, density, font, motion, sounds) are **per device**: they are remembered on this device only and are never synced or overwritten by a restore (`lib/core/device_store.dart`).

## Colour tokens (`tokens.dart`, `AppColors.build(brightness, accent, highContrast)`)
Dark is the default; Light and "Match my computer" are options. Every text/background pair, for every theme x accent x contrast combination, is checked by `test/design_contrast_test.dart`: at least **4.5:1** (WCAG AA), **7:1** in High contrast, and borders at least **3:1** against surfaces (40 combinations, all pass).

| Token | Dark | Light | Used for |
|---|---|---|---|
| `bg` | `#0E1318` | `#F2F5F8` | page background |
| `surface` / `surfaceAlt` | `#161D25` / `#1E2833` | `#FFFFFF` / `#E9EEF3` | cards, panels / inputs, table headers |
| `text` / `textMuted` | `#EAF0F6` / `#A8B5C2` | `#111B26` / `#45525F` | main text / hints |
| `primary` / `onPrimary` | accent colour (below) | accent colour | main buttons, selected items, Grand total |
| `success` `warning` `danger` `info` | green, amber, red, accent | darker versions | badges and status; always with a word, never colour alone |
| `border` | `#708195` | `#6B7A89` | input outlines; dividers use it at 60% |
| `rowSelected` | accent mixed 16% into surface | 10% | selected / hovered table row |
| `paper` / `onPaper` | white / near-black | same | print preview (paper is white in both themes) |

**Accent colours** (Settings > Appearance): Blue (default), Teal, Green, Orange, Violet. Dark uses a light version, Light a deep version, chosen so white or near-black text on them passes 4.5:1. **High contrast** switches to pure black/white backgrounds and text, stronger borders and pushes every colour to 7:1.

## Type
Fonts are bundled, nothing is downloaded: **Inter** (default, clean) and **Atkinson Hyperlegible Next** (made for easy reading), both SIL OFL, both contain the rupee sign (checked by test). Sizes: body 14, large body 16, titles 16-24, grand total 28 bold. Product names are 16 bold, wrap to as many lines as needed, never an ellipsis.

- **Text size:** 80% to 200% (slider with 5% steps, presets Small 90 / Normal 100 / Large 125 / Extra large 150 / Huge 200, live preview, Reset to normal; Ctrl+Plus, Ctrl+Minus, Ctrl+0; A- / A+ in the top bar). It is multiplied with the operating system's own text size, never replacing it.
- **Billing screen text size:** a separate 80% to 250% slider for the product table and the bill lines only.
- **Density:** Comfortable / Normal / Compact change row heights and paddings (`AppMetrics`).

## Layout at big text
Width is judged as the text sees it: window width divided by the text size (`context.effectiveWidth`). So 1280 px at 200% counts as 640 px and the app uses its roomier phone layout (cards, bottom bar, one pinned footer) instead of squeezing a table. Segmented choices (`SlideSegments`) shrink their labels to fit rather than overflow. Dialogs scroll when taller than the window. Print previews do not scale (paper is paper). Proven by `test/text_size_matrix_test.dart` (37 screens x text 80-200% x desktop/tablet/phone x both themes, no layout errors) and `test/billing_layout_test.dart`.

## Spacing, shape, size
Gap 4 / 8 / 12 / 16 / 24 / 32. Corner radius 6 / 10 / 14. Minimum touch target **48 px**. Table row minimum height 44 px at Normal density (35 Compact, 53 Comfortable). Breakpoints: phone under 700 px, tablet 700-1099 px, desktop 1100 px and up (effective width).

## Components
| Component | File | Notes |
|---|---|---|
| `StatusBadge`, `EmptyState`, `SectionCard`, `StatCard`, `KeyValue`, `SearchField`, `PageFrame` | `widgets.dart` | icon + word + colour badges; empty states teach what to do |
| `confirmDialog`, `toast` | `widgets.dart` | confirm shows the name or amount; destructive buttons are red |
| `DataListScreen<T>` | `data_list.dart` | search, filter chips, sort; table on wide screens, cards on narrow; rows built lazily (20,000 rows stay smooth) |
| `showFormSheet`, `showDetail` | `form_sheet.dart`, `detail_sheet.dart` | dialog on wide screens, bottom sheet on narrow; Ctrl+S saves, Esc cancels; scroll when tall |
| `SlideSegments` | `segments.dart` | segmented control with a sliding indicator, shrinks labels to fit |
| `ProductPicker`, `BillLines`, `BillFooter` | `features/billing/` | the billing building blocks |
| effects | `effects.dart` | see [motion-guide.md](motion-guide.md) |

## The billing layout rule
The product table and the bill lines scroll **inside themselves**. The footer (Grand total, payment mode, Save, Save and print, Preview) is outside every scroll view and keeps a fixed height, so it never moves and never leaves the window, at any text size. With very large text the GST detail collapses to one short line and the buttons stack, but Grand total and all three buttons stay fully visible.

## Motion
Short, optional, never in the way: see [motion-guide.md](motion-guide.md).

## Words
Short, plain, no jargon. See `docs/ux-principles.md`. All visible text (English only) is in `tool/strings.txt`; `tool/gen_strings.dart` turns it into `lib/strings.dart`. `tool/check_keys.dart` lists missing strings.
