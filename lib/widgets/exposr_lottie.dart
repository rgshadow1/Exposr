import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Plays one of the app's Lottie animations.
///
/// Lottie is a format for vector animations exported from design tools. The
/// `lottie` package draws them and gives us an [AnimationController] to steer.
///
/// Two things this wrapper adds:
///  * [loop] animations repeat; the others play once and hold their last frame.
///  * If the person has turned animations off in system settings, nothing
///    moves: the animation jumps straight to its final frame.
///
/// If the file can't be loaded, an empty box of the same size is shown, so a
/// missing animation never breaks a screen.
class ExposrLottie extends StatefulWidget {
  const ExposrLottie({
    super.key,
    required this.asset,
    this.size = 96,
    this.loop = false,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final bool loop;

  /// Read by screen readers. Leave null when the animation is decoration and
  /// the words next to it already say the same thing.
  final String? semanticLabel;

  @override
  State<ExposrLottie> createState() => _ExposrLottieState();
}

class _ExposrLottieState extends State<ExposrLottie> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition, {required bool reduceMotion}) {
    _controller.duration = composition.duration;
    if (reduceMotion) {
      _controller.value = 1.0; // the finished picture, standing still
    } else if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final animation = Lottie.asset(
      widget.asset,
      controller: _controller,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      onLoaded: (composition) => _onLoaded(composition, reduceMotion: reduceMotion),
      errorBuilder: (context, error, stackTrace) => SizedBox.square(dimension: widget.size),
    );

    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: animation);
    return Semantics(label: label, image: true, excludeSemantics: true, child: animation);
  }
}
