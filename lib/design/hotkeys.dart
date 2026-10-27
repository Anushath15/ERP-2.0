/// Keyboard shortcuts shared by the whole program (the usual ERP set, as in Tally, Busy, Zoho and Invoiso):
///  * Enter in a form or a payment box saves it (not in a multi-line note, and not while a button has the focus: then Enter presses that button);
///  * Ctrl+S saves, Ctrl+P prints (on the bill: save and print; on the Print page and in a saved bill: print), Esc closes a box;
///  * F2 new bill, F3 new estimate, F4 all bills, F5 products, F6 customers, F7 credit and dues, F8 reports, Ctrl+Q / Ctrl+N a new bill,
///    Ctrl+Shift+N add a product, Ctrl+F go to the search box, Alt+Left back, Ctrl+plus / minus / 0 text size, F1 this list.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enter saves: attach to a box with `Focus(onKeyEvent: enterSaves(save), child: ...)`. Handled only when the focus is in a single-line text
/// field (or nowhere in particular), so a multi-line note still gets its new line and a focused button is still pressed by Enter.
KeyEventResult Function(FocusNode, KeyEvent) enterSaves(VoidCallback save) => (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.numpadEnter) return KeyEventResult.ignored;
      if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed || HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
      final f = FocusManager.instance.primaryFocus;
      final field = f?.context?.findAncestorWidgetOfExactType<EditableText>();
      final ok = field != null ? field.maxLines == 1 : (f == null || f is FocusScopeNode);
      if (!ok) return KeyEventResult.ignored;
      save();
      return KeyEventResult.handled;
    };

/// The search box of the page that is showing (Ctrl+F goes to it). Pages register their box while they are on screen.
class SearchFocus {
  static final List<FocusNode> _stack = [];
  static void add(FocusNode n) => _stack.add(n);
  static void remove(FocusNode n) => _stack.remove(n);

  /// True when a search box took the focus.
  static bool focus() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final n = _stack[i];
      if (n.context != null && n.canRequestFocus) {
        n.requestFocus();
        return true;
      }
    }
    return false;
  }
}

/// The shortcut list shown by F1: (keys, what it does) under a heading.
const shortcutGroups = <(String, List<(String, String)>)>[
  ('Billing', [
    ('Enter (search box empty)', 'Save the bill'),
    ('Ctrl+S', 'Save the bill'),
    ('Ctrl+P / F9 / Ctrl+Enter', 'Save and print the bill'),
    ('Enter (search box)', 'Add the highlighted product'),
    ('Up / Down', 'Move through the found products'),
    ('Ctrl+F', 'Go to the product search'),
  ]),
  ('Forms and payment boxes', [
    ('Enter', 'Save'),
    ('Ctrl+S', 'Save'),
    ('Esc', 'Close without saving'),
  ]),
  ('Printing', [
    ('Ctrl+P', 'Print (on the Print page, and on a saved bill)'),
  ]),
  ('Go to', [
    ('F2 / Ctrl+Q / Ctrl+N', 'New bill'),
    ('F3', 'New estimate'),
    ('F4', 'All bills'),
    ('F5', 'Products'),
    ('F6', 'Customers'),
    ('F7', 'Credit and dues'),
    ('F8', 'Reports'),
    ('Ctrl+Shift+N', 'Add a product'),
    ('Ctrl+F', 'Go to the search box of the page'),
    ('Alt+Left', 'Back'),
  ]),
  ('Everywhere', [
    ('Ctrl+plus / Ctrl+minus / Ctrl+0', 'Bigger text / smaller text / normal'),
    ('F1', 'This list'),
  ]),
];

Future<void> showShortcutsDialog(BuildContext context, {String title = 'Keyboard shortcuts', String close = 'Close'}) {
  final th = Theme.of(context).textTheme;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(children: [
              Expanded(child: Text(title, style: th.titleLarge)),
              IconButton(tooltip: close, onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('shortcuts-list'),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final g in shortcutGroups) ...[
                  Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(g.$1, style: th.titleSmall)),
                  for (final k in g.$2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 220, child: Text(k.$1, style: th.bodyMedium!.copyWith(fontWeight: FontWeight.w700))),
                        Expanded(child: Text(k.$2, style: th.bodyMedium)),
                      ]),
                    ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    ),
  );
}
