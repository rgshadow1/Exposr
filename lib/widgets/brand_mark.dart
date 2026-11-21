import 'package:flutter/material.dart';

/// The Exposr logo, with or without the name beside it.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.showName = true});

  final double size;
  final bool showName;

  static const String logoAsset = 'assets/images/exposr_logo.png';

  @override
  Widget build(BuildContext context) {
    // The logo is a white-on-transparent PNG, so it sits on any dark surface.
    final logo = Image.asset(
      logoAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      // The name next to it already says "Exposr"; without the name, the
      // image carries the label itself.
      excludeFromSemantics: showName,
      semanticLabel: showName ? null : 'Exposr',
    );

    if (!showName) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        // The name shrinks to fit rather than overflowing or being cut off
        // when the text size is very large and the space is narrow.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Exposr',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: -0.2),
            ),
          ),
        ),
      ],
    );
  }
}
