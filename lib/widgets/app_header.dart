import 'package:flutter/material.dart';

/// The top of the Home screen: the Exposr logo and name, centred.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // A Row lays children out horizontally. mainAxisAlignment.center packs
    // them together in the middle instead of pushing them to the left edge.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The logo is a white-on-transparent PNG, so it sits on any background
        // colour. The name next to it already says "Exposr", so a screen
        // reader doesn't need the image described as well.
        Image.asset(
          'assets/images/exposr_logo.png',
          width: 40,
          height: 40,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 12),
        Semantics(
          header: true,
          child: Text(
            'Exposr',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ),
      ],
    );
  }
}
