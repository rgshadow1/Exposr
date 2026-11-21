import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';

import '../core/app_colors.dart';

/// Plays one of the app's bundled Lottie animations.
///
/// Lottie is a format for vector animations exported from design tools. The
/// `lottie` package draws them and gives us an [AnimationController] to steer.
/// All four files in `assets/lottie` are original to Exposr: they are made by
/// `tool/generate_lottie.py`, so there is no third-party artwork or licence to
/// carry.
///
/// What this wrapper adds on top of the package:
///
///  * **Playback modes.** By default an animation plays once and holds its last
///    frame. [loop] repeats it for as long as it is shown. [repeat] plays it a
///    fixed number of times and then rests on [restAt].
///  * **Reduced motion.** If the person has turned animations off in system
///    settings, nothing moves: the animation sits on [restAt], a finished
///    still picture.
///  * **Stops when it can't be seen.** The animation pauses while it is
///    scrolled out of view, and while its tab is hidden (a hidden tab mutes
///    its tickers), and carries on from where it was when it comes back.
///  * **A static fallback.** If the file can't be loaded, [fallback] is shown
///    (an empty box of the same size by default), so a missing animation never
///    breaks a screen.
class ExposrLottie extends StatefulWidget {
  const ExposrLottie({
    super.key,
    required this.asset,
    this.size = 96,
    this.loop = false,
    this.repeat,
    this.speed = 1,
    this.restAt = 1,
    this.overscan = 1,
    this.fallback,
    this.semanticLabel,
  });

  final String asset;

  /// The space the animation takes up in the layout.
  final double size;

  /// Repeat for as long as it is on screen.
  final bool loop;

  /// Play this many times, then rest. Ignored when [loop] is true.
  final int? repeat;

  /// 1 is the speed the file was made at; 0.5 is half as fast.
  final double speed;

  /// Where in the animation (0 is the start, 1 the end) to sit when it isn't
  /// moving: after a [repeat] run, and when motion is reduced.
  final double restAt;

  /// Draw the animation this many times larger than [size], without taking
  /// any more room. The files have a margin around the artwork; this trades
  /// the margin for a bigger drawing in the same space.
  final double overscan;

  /// Shown instead of the animation if its file can't be loaded.
  final Widget? fallback;

  /// Read by screen readers. Leave null when the animation is decoration and
  /// the words next to it already say the same thing.
  final String? semanticLabel;

  @override
  State<ExposrLottie> createState() => _ExposrLottieState();
}

class _ExposrLottieState extends State<ExposrLottie> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  LottieComposition? _composition;
  ScrollPosition? _position;
  bool _reduceMotion = false;
  bool _inView = true;

  /// True when the animation has more to play but is waiting, because it is
  /// out of view.
  bool _waiting = false;

  /// Bumped on every (re)start, so a run that has been replaced can't change
  /// the controller when it ends.
  int _run = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_checkInView);
      _position = position?..addListener(_checkInView);
    }

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _start();
    }
  }

  @override
  void didUpdateWidget(ExposrLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      // A different file: wait for it to load, which restarts everything.
      _composition = null;
    } else if (oldWidget.loop != widget.loop ||
        oldWidget.repeat != widget.repeat ||
        oldWidget.speed != widget.speed ||
        oldWidget.restAt != widget.restAt) {
      _start();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkInView);
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _composition = composition;
    _start();
  }

  Duration _cycle(LottieComposition composition) {
    return Duration(microseconds: (composition.duration.inMicroseconds / widget.speed).round());
  }

  /// (Re)starts from the beginning, in whatever mode the widget is now in.
  void _start() {
    final composition = _composition;
    if (composition == null) return;

    _run++;
    _waiting = false;
    _controller
      ..stop()
      ..duration = _cycle(composition);

    if (_reduceMotion) {
      _controller.value = widget.restAt;
      return;
    }
    _controller.value = 0;
    _play();
  }

  void _play() {
    // Out of view: don't spend frames. It starts when it scrolls back.
    if (!_inView) {
      _waiting = true;
      return;
    }

    final run = _run;
    if (widget.loop) {
      _controller.repeat();
    } else if (widget.repeat != null) {
      _controller.repeat(count: widget.repeat).whenComplete(() => _settle(run));
    } else {
      _controller.forward().whenComplete(() => _settle(run));
    }
  }

  /// A run came to its end: sit on the resting frame.
  void _settle(int run) {
    if (!mounted || run != _run || _waiting) return;
    if (_controller.status != AnimationStatus.completed) return;
    _controller.value = widget.restAt;
  }

  /// Picks up where a paused animation left off.
  void _resume() {
    final run = _run;
    if (widget.loop) {
      _controller.repeat();
    } else {
      // Finish the cycle it was in, then rest.
      _controller.forward().whenComplete(() => _settle(run));
    }
  }

  void _checkInView() {
    final visible = _isInView();
    if (visible == _inView) return;
    _inView = visible;

    if (!visible) {
      if (_controller.isAnimating) {
        _waiting = true;
        _controller.stop();
      }
    } else if (_waiting && !_reduceMotion) {
      _waiting = false;
      if (_controller.value == 0 && !_controller.isAnimating) {
        _play();
      } else {
        _resume();
      }
    }
  }

  /// Whether any part of this widget is inside the scrollable that holds it.
  bool _isInView() {
    final position = _position;
    final box = context.findRenderObject();
    if (position == null || !position.hasPixels || box is! RenderBox || !box.attached) {
      return true;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return true;

    // The scroll offset at which this widget's top edge meets the viewport's.
    final top = viewport.getOffsetToReveal(box, 0).offset;
    return position.pixels < top + box.size.height &&
        position.pixels + position.viewportDimension > top;
  }

  @override
  Widget build(BuildContext context) {
    final canvas = widget.size * widget.overscan;

    final animation = Lottie.asset(
      widget.asset,
      controller: _controller,
      width: canvas,
      height: canvas,
      fit: BoxFit.contain,
      onLoaded: _onLoaded,
      errorBuilder: (context, error, stackTrace) {
        return widget.fallback ?? SizedBox.square(dimension: widget.size);
      },
    );

    // The artwork is drawn larger than its slot, so only the slot is laid out.
    final slot = SizedBox.square(
      dimension: widget.size,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: canvas,
        maxHeight: canvas,
        child: animation,
      ),
    );

    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: slot);
    return Semantics(label: label, image: true, excludeSemantics: true, child: slot);
  }
}

/// A still stand-in for a mark: an icon inside a thin ring, drawn in the same
/// line style as the animations. Used when an animation can't load and for
/// states that have no animation of their own (a check that failed).
class StaticMark extends StatelessWidget {
  const StaticMark({super.key, required this.icon, required this.color, this.size = 96});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = size * 0.62;

    return SizedBox.square(
      dimension: size,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color, width: 3),
          ),
          child: SizedBox.square(
            dimension: ring,
            child: Icon(icon, size: ring * 0.5, color: color),
          ),
        ),
      ),
    );
  }
}

/// The ring-and-icon used when nothing else is available, in the default
/// accent. Exists so the call sites stay short.
Widget accentStaticMark(IconData icon, double size) {
  return StaticMark(icon: icon, color: AppColors.accent, size: size);
}
