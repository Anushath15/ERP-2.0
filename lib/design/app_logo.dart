import 'package:flutter/material.dart';

/// The ASK logo (the same picture as ERP 1.0, see assets/branding/).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/ask-logo-256.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        semanticLabel: 'ASK ERP 2.0',
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      );
}
