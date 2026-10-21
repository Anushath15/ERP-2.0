import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// The pages the owner has been through, so Back returns to the page before (not always the dashboard). Screens open with `go`, which keeps no stack of its own.
class NavHistory extends ChangeNotifier {
  final List<String> _stack = [];
  static const _max = 60;

  /// The page Back would return to, or null at the start.
  String? get previous => _stack.length >= 2 ? _stack[_stack.length - 2] : null;
  bool get canGoBack => previous != null;

  /// Called with every location the router shows.
  void visit(String location) {
    if (_stack.isNotEmpty && _stack.last == location) return;
    if (_stack.length >= 2 && _stack[_stack.length - 2] == location) {
      _stack.removeLast(); // this was Back
    } else {
      _stack.add(location);
      if (_stack.length > _max) _stack.removeAt(0);
    }
    notifyListeners();
  }

  void reset() {
    _stack.clear();
    notifyListeners();
  }

  /// Go to the page before; with nothing before, to the dashboard. The shell's own pop is used first when a page was pushed over another.
  void back(GoRouter router) {
    final p = previous;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(p ?? '/');
    }
  }
}

final NavHistory navHistory = NavHistory();
