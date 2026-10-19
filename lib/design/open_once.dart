import 'dart:async';
import 'package:flutter/widgets.dart';

/// Runs [run] once, right after the page first appears (used to open a popup again when the person comes back to the page).
class OpenOnce extends StatefulWidget {
  const OpenOnce({super.key, required this.run, required this.child});
  final FutureOr<void> Function()? run;
  final Widget child;

  @override
  State<OpenOnce> createState() => _OpenOnceState();
}

class _OpenOnceState extends State<OpenOnce> {
  @override
  void initState() {
    super.initState();
    final run = widget.run;
    if (run != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(Future.sync(run));
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
