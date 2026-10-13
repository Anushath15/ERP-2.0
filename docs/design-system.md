# Design system

Code: `lib/design/`. Everything on screen is built from these tokens and components, so screens look the same and a change in one place changes everywhere.

## Colour tokens (`tokens.dart`)
Dark is the default, light is an option. Both are checked by `test/design_contrast_test.dart`: every text/background pair is at least **4.5:1** (WCAG AA), and borders are at least **3:1** against surfaces.

| Token | Dark | Light | Used for |
|---|---|---|---|
| `bg` | `#0E1318` | `#F2F5F8` | page background |
| `surface` / `surfaceAlt` | `#161D25` / `#1E2833` | `#FFFFFF` / `#E9EEF3` | cards, panels / inputs, table headers |
| `text` / `textMuted` | `#EAF0F6` / `#A8B5C2` | `#111B26` / `#45525F` | main text / hints |
| `primary` / `onPrimary` | `#5BADFF` / `#031A30` | `#0A58B0` / `#FFFFFF` | main buttons, selected items, Grand total |
| `success` `warning` `danger` `info` | green, amber, red, blue | darker versions | badges, status; always with a word, never colour alone |
| `border` | `#708195` | `#8795A3` | input outlines; dividers use it at 60% |
| `paper` / `onPaper` | white / near-black | same | print preview (paper is white in both themes) |

## Type
Noto Sans, bundled so the app needs no downloads (Inter and Atkinson Hyperlegible arrive with the display settings). Sizes: body 14, large body 16, titles 16-24, grand total 28 bold. Text scale setting: 90%, 100%, 115%, 130% (on top of the system font scale). Product names are 16 bold, wrap to as many lines as needed, never an ellipsis.

## Spacing, shape, size
Gap 4 / 8 / 12 / 16 / 24 / 32. Corner radius 6 / 10 / 14. Minimum touch target **48 px**. Table row minimum height 44 px. Breakpoints: phone under 700 px, tablet 700-1099 px, desktop 1100 px and up.

## Components
| Component | File | Notes |
|---|---|---|
| `StatusBadge` | `widgets.dart` | icon + word + colour (success, warning, danger, info, neutral) |
| `EmptyState` | `widgets.dart` | icon, one sentence, one action; teaches what to do |
| `SectionCard`, `StatCard`, `KeyValue`, `SearchField`, `PageFrame` | `widgets.dart` | page title row, actions, padded body |
| `confirmDialog`, `toast` | `widgets.dart` | confirm shows the name or amount; destructive buttons are red |
| `DataListScreen<T>` | `data_list.dart` | search, filter chips, sort; table on wide screens, cards on phones; rows are built lazily so 20,000 rows stay smooth |
| `showFormSheet` | `form_sheet.dart` | dialog on desktop and tablet, bottom sheet on phone; Ctrl+S saves, Esc cancels |
| `showDetail` | `detail_sheet.dart` | read-only detail with actions |
| `ProductPicker`, `BillLines`, `BillFooter` | `features/billing/` | the billing building blocks (see below) |

## The billing layout rule
The product table and the bill lines scroll **inside themselves**. The footer (Grand total, payment mode, Save, Save and print, Preview) is outside every scroll view, so it never moves and never leaves the window. `test/billing_layout_test.dart` proves it at 1920x1080, 1366x768, 1280x720, tablet landscape and portrait, and two phone sizes, with 1, 10 and 100 lines, for bills and estimates.

## Motion
None that costs time: no page transitions, no ripple, no splash delay.

## Words
Short, plain, no jargon. See `docs/ux-principles.md`. All visible text (English only) is in `tool/strings.txt`; `tool/gen_strings.dart` turns it into `lib/strings.dart`. `tool/check_keys.dart` lists missing strings.
