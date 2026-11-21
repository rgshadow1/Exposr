import 'package:breach_checker/core/lottie_assets.dart';
import 'package:breach_checker/widgets/exposr_lottie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// Tests how animations behave: when they play, when they rest, and when they
/// stop. The pictures themselves are checked by eye.
void main() {
  /// Lets the animation files load. Reading an asset is real I/O, which the
  /// fake clock of a widget test doesn't wait for.
  Future<void> load(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
  }

  AnimationController controllerOf(WidgetTester tester) {
    return tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller! as AnimationController;
  }

  /// A page with the animation at the top and plenty of room below it, so it
  /// can be scrolled out of view.
  Widget page(ExposrLottie animation, {ScrollController? controller}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: Column(children: [animation, const SizedBox(height: 3000)]),
        ),
      ),
    );
  }

  group('playing', () {
    testWidgets('plays once and holds its last frame', (tester) async {
      await tester.pumpWidget(page(const ExposrLottie(asset: LottieAssets.success)));
      await load(tester);

      final controller = controllerOf(tester);
      expect(controller.isAnimating, isTrue);

      await tester.pump(const Duration(seconds: 5));

      expect(controller.isAnimating, isFalse);
      expect(controller.value, 1);
    });

    testWidgets('a fixed number of sweeps, then it rests on the frame it was given', (tester) async {
      await tester.pumpWidget(
        page(const ExposrLottie(asset: LottieAssets.scan, repeat: 2, restAt: 0)),
      );
      await load(tester);

      final controller = controllerOf(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isAnimating, isTrue);

      // The file is 3 seconds long: two sweeps are done by about 6.
      await tester.pump(const Duration(seconds: 7));

      expect(controller.isAnimating, isFalse);
      expect(controller.value, 0);
    });

    testWidgets('slower, when asked to be', (tester) async {
      await tester.pumpWidget(page(const ExposrLottie(asset: LottieAssets.success, speed: 0.5)));
      await load(tester);

      // At normal speed it is done after 2.5s. At half speed it is not.
      await tester.pump(const Duration(milliseconds: 2800));
      expect(controllerOf(tester).isAnimating, isTrue);

      await tester.pump(const Duration(seconds: 3));
      expect(controllerOf(tester).isAnimating, isFalse);
    });

    testWidgets('a loop keeps going for as long as it is shown', (tester) async {
      await tester.pumpWidget(page(const ExposrLottie(asset: LottieAssets.scan, loop: true)));
      await load(tester);

      await tester.pump(const Duration(seconds: 20));

      expect(controllerOf(tester).isAnimating, isTrue);
    });

    testWidgets('changing from a few sweeps to a loop restarts it in the same widget', (
      tester,
    ) async {
      const key = ValueKey('mark');
      await tester.pumpWidget(
        page(const ExposrLottie(key: key, asset: LottieAssets.scan, repeat: 1, restAt: 0)),
      );
      await load(tester);
      final controller = controllerOf(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(controller.isAnimating, isFalse); // the one sweep is over

      await tester.pumpWidget(
        page(const ExposrLottie(key: key, asset: LottieAssets.scan, loop: true)),
      );

      expect(controllerOf(tester), same(controller));
      expect(controller.isAnimating, isTrue);
    });
  });

  group('reduced motion', () {
    testWidgets('nothing moves: it sits on the frame it rests on', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(
        page(const ExposrLottie(asset: LottieAssets.scan, loop: true, restAt: 0.25)),
      );
      await load(tester);

      final controller = controllerOf(tester);
      expect(controller.isAnimating, isFalse);
      expect(controller.value, 0.25);

      await tester.pump(const Duration(seconds: 10));
      expect(controller.value, 0.25);
    });

    testWidgets('a one-shot result shows its finished picture straight away', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(page(const ExposrLottie(asset: LottieAssets.alert)));
      await load(tester);

      expect(controllerOf(tester).isAnimating, isFalse);
      expect(controllerOf(tester).value, 1);
    });

    testWidgets('switching it on while the animation runs stops it', (tester) async {
      await tester.pumpWidget(page(const ExposrLottie(asset: LottieAssets.scan, loop: true)));
      await load(tester);
      expect(controllerOf(tester).isAnimating, isTrue);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();

      expect(controllerOf(tester).isAnimating, isFalse);
    });
  });

  group('offscreen', () {
    testWidgets('stops when scrolled out of view and carries on when it comes back', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(const ExposrLottie(asset: LottieAssets.scan, loop: true), controller: scroll),
      );
      await load(tester);
      expect(controllerOf(tester).isAnimating, isTrue);

      scroll.jumpTo(1500);
      await tester.pump();
      expect(controllerOf(tester).isAnimating, isFalse);

      // No frames are spent while it is away.
      final parked = controllerOf(tester).value;
      await tester.pump(const Duration(seconds: 5));
      expect(controllerOf(tester).value, parked);

      scroll.jumpTo(0);
      await tester.pump();
      expect(controllerOf(tester).isAnimating, isTrue);
    });

    testWidgets('one that starts offscreen waits until it is seen', (tester) async {
      final scroll = ScrollController(initialScrollOffset: 1500);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(const ExposrLottie(asset: LottieAssets.scan, loop: true), controller: scroll),
      );
      await load(tester);
      // Not in view: the first check happens on the first scroll.
      scroll.jumpTo(1501);
      await tester.pump();
      expect(controllerOf(tester).isAnimating, isFalse);

      scroll.jumpTo(0);
      await tester.pump();

      expect(controllerOf(tester).isAnimating, isTrue);
    });

    testWidgets('a finished one-shot is not started again by scrolling', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(const ExposrLottie(asset: LottieAssets.success), controller: scroll),
      );
      await load(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(controllerOf(tester).value, 1);

      scroll.jumpTo(1500);
      await tester.pump();
      scroll.jumpTo(0);
      await tester.pump();

      expect(controllerOf(tester).isAnimating, isFalse);
      expect(controllerOf(tester).value, 1);
    });

    testWidgets('a hidden tab stops it too (its tickers are muted)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: false,
              child: ExposrLottie(asset: LottieAssets.scan, loop: true),
            ),
          ),
        ),
      );
      await load(tester);

      // Nothing is scheduled to draw while the tab is hidden, so a settle
      // finishes at once instead of waiting forever on a looping animation.
      await tester.pumpAndSettle();
    });
  });

  group('when the file can not be loaded', () {
    testWidgets('a still stand-in is shown, in the same space', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExposrLottie(
              asset: 'assets/lottie/does_not_exist.json',
              size: 80,
              fallback: Icon(Icons.radar, key: Key('fallback')),
            ),
          ),
        ),
      );
      await load(tester);

      expect(find.byKey(const Key('fallback')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty box of the same size, if no stand-in was given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: ExposrLottie(asset: 'assets/lottie/does_not_exist.json', size: 80)),
          ),
        ),
      );
      await load(tester);

      expect(tester.getSize(find.byType(ExposrLottie)), const Size(80, 80));
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    testWidgets('takes only the room it is given, however large it is drawn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ExposrLottie(asset: LottieAssets.shield, size: 96, overscan: 1.5),
            ),
          ),
        ),
      );
      await load(tester);

      expect(tester.getSize(find.byType(ExposrLottie)), const Size(96, 96));
    });

    testWidgets('is hidden from screen readers unless given a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExposrLottie(asset: LottieAssets.shield),
                ExposrLottie(asset: LottieAssets.shield, semanticLabel: 'Exposr logo'),
              ],
            ),
          ),
        ),
      );
      await load(tester);

      expect(find.bySemanticsLabel('Exposr logo'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('.')), findsOneWidget);

      handle.dispose();
    });
  });
}
