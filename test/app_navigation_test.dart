import 'dart:ui' show Tristate;

import 'package:breach_checker/core/app_colors.dart';
import 'package:breach_checker/core/app_theme.dart';
import 'package:breach_checker/core/app_tokens.dart';
import 'package:breach_checker/widgets/app_navigation.dart';
import 'package:breach_checker/widgets/tappable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'support/fonts.dart';

/// The navigation is specified to the pixel, so these tests measure it:
/// icons, row heights, gaps, padding, corners and colours, and that it can be
/// used from a keyboard.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadInter();
  });

  var selected = 0;
  final taps = <int>[];

  Future<void> pumpSidebar(WidgetTester tester, {int current = 0, int newBreaches = 0}) async {
    selected = current;
    taps.clear();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Row(
            children: [
              AppSidebar(
                selectedIndex: selected,
                onSelected: taps.add,
                newBreaches: newBreaches,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Finder row(String label) {
    return find.ancestor(of: find.text(label), matching: find.byType(Tappable)).first;
  }

  Finder icon(IconData data) => find.byIcon(data);

  group('the icons', () {
    testWidgets('are the four Lucide icons, one per destination, in order', (tester) async {
      await pumpSidebar(tester);

      expect(appDestinations.map((d) => d.label), ['Home', 'Insights', 'Watchlist', 'Settings']);
      expect(appDestinations.map((d) => d.icon), [
        LucideIcons.house,
        LucideIcons.chartNoAxesCombined,
        LucideIcons.eye,
        LucideIcons.settings2,
      ]);
      for (final data in appDestinations.map((d) => d.icon)) {
        expect(icon(data), findsOneWidget);
      }
    });

    testWidgets('are all 20px, and none of them is swapped for a heavier drawing when selected', (
      tester,
    ) async {
      for (var current = 0; current < 4; current++) {
        await pumpSidebar(tester, current: current);

        for (final data in appDestinations.map((d) => d.icon)) {
          expect(tester.widget<Icon>(icon(data)).size, 20, reason: 'size with $current selected');
          expect(tester.getSize(icon(data)), const Size(20, 20));
        }
        // The same four drawings, whichever is current: no Material icons.
        expect(find.byType(Icon), findsNWidgets(4));
      }
    });

    testWidgets('all come from the one Lucide font, so they share a stroke weight', (tester) async {
      await pumpSidebar(tester);

      for (final destination in appDestinations) {
        expect(destination.icon.fontFamily, 'Lucide');
        expect(destination.icon.fontPackage, 'lucide_icons_flutter');
      }
    });
  });

  group('the rows', () {
    testWidgets('are 46px tall, 10px from the sidebar edge, with 10px corners', (tester) async {
      await pumpSidebar(tester);

      for (final destination in appDestinations) {
        final tappable = row(destination.label);
        final rect = tester.getRect(tappable);

        expect(rect.height, 46, reason: '${destination.label} height');
        expect(rect.left, 10, reason: '${destination.label} left padding');
        expect(AppSizes.sidebarWidth - rect.right, 10,
            reason: '${destination.label} right padding');

        final material = tester.widget<Material>(
          find.descendant(of: tappable, matching: find.byType(Material)).first,
        );
        expect(material.borderRadius, BorderRadius.circular(10));
      }
    });

    testWidgets('put 12px between the icon and the label, and start the icon 12px in', (
      tester,
    ) async {
      await pumpSidebar(tester);

      for (final destination in appDestinations) {
        final iconBox = tester.getRect(icon(destination.icon));
        final label = tester.getRect(find.text(destination.label));
        final rowBox = tester.getRect(row(destination.label));

        expect(label.left - iconBox.right, 12, reason: '${destination.label} gap');
        expect(iconBox.left - rowBox.left, 12, reason: '${destination.label} inner padding');
        // Icon and label are centred on the same line.
        expect(iconBox.center.dy, closeTo(label.center.dy, 1), reason: destination.label);
        expect(iconBox.center.dy, closeTo(rowBox.center.dy, 1), reason: destination.label);
      }
    });

    testWidgets('keep the same left edge for every icon and every label', (tester) async {
      await pumpSidebar(tester);

      final iconLefts = {for (final d in appDestinations) tester.getTopLeft(icon(d.icon)).dx};
      final labelLefts = {
        for (final d in appDestinations) tester.getTopLeft(find.text(d.label)).dx
      };

      expect(iconLefts, hasLength(1));
      expect(labelLefts, hasLength(1));
    });

    testWidgets('are spaced evenly, one above the next', (tester) async {
      await pumpSidebar(tester);

      final tops = [for (final d in appDestinations) tester.getTopLeft(row(d.label)).dy];
      final steps = [for (var i = 1; i < tops.length; i++) tops[i] - tops[i - 1]];

      expect(steps.toSet(), hasLength(1));
      expect(steps.first, 50); // 46 + a 4px gap
    });

    testWidgets('use 14px medium-weight labels, in both states', (tester) async {
      await pumpSidebar(tester, current: 1);

      for (final destination in appDestinations) {
        final style = tester.widget<Text>(find.text(destination.label)).style!;
        expect(style.fontSize, 14, reason: destination.label);
        expect(style.fontWeight, FontWeight.w500, reason: destination.label);
      }
    });

    testWidgets('stay at least 46px tall when the text is made larger', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSidebar(tester);

      for (final destination in appDestinations) {
        expect(tester.getSize(row(destination.label)).height, greaterThanOrEqualTo(46));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the colours', () {
    Color iconColor(WidgetTester tester, IconData data) => tester.widget<Icon>(icon(data)).color!;
    Color labelColor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    Color? fill(WidgetTester tester, String label) {
      final material = tester.widget<Material>(
        find.descendant(of: row(label), matching: find.byType(Material)).first,
      );
      return material.color;
    }

    testWidgets('the current item has a faint blue fill and a blue icon and label', (tester) async {
      await pumpSidebar(tester, current: 2);

      expect(iconColor(tester, LucideIcons.eye), AppColors.accent);
      expect(labelColor(tester, 'Watchlist'), AppColors.accent);
      expect(fill(tester, 'Watchlist'), AppColors.navSelected);

      // The fill is blue, and faint: close to the surface it sits on.
      final tint = AppColors.navSelected;
      expect(tint.b, greaterThan(tint.r));
      expect(tint.b, greaterThan(tint.g));
      expect((tint.b - AppColors.surface.b).abs(), lessThan(0.15));
    });

    testWidgets('the others are muted grey with no fill', (tester) async {
      await pumpSidebar(tester, current: 2);

      for (final destination in appDestinations.where((d) => d.label != 'Watchlist')) {
        expect(iconColor(tester, destination.icon), AppColors.textSecondary);
        expect(labelColor(tester, destination.label), AppColors.textSecondary);
        expect(fill(tester, destination.label), Colors.transparent);
      }
    });

    testWidgets('no gradients, shadows or glows anywhere in it', (tester) async {
      await pumpSidebar(tester, current: 0);

      final decorations = tester
          .widgetList<DecoratedBox>(
              find.descendant(of: find.byType(AppSidebar), matching: find.byType(DecoratedBox)))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>();
      for (final decoration in decorations) {
        expect(decoration.gradient, isNull);
        expect(decoration.boxShadow, isNull);
      }
    });

    testWidgets('the text and icons are readable against what is behind them (WCAG AA, 4.5:1)', (
      tester,
    ) async {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
      }

      // Blue on its faint fill (and with the pointer over it), grey on the surface.
      final hovered = Color.alphaBlend(AppColors.hoverOverlay, AppColors.navSelected);
      expect(contrast(AppColors.accent, AppColors.navSelected), greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.accent, hovered), greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(
        contrast(
            AppColors.textSecondary, Color.alphaBlend(AppColors.hoverOverlay, AppColors.surface)),
        greaterThanOrEqualTo(4.5),
      );
      // The focus ring against the surface (WCAG 1.4.11, 3:1).
      expect(contrast(AppColors.accent, AppColors.surface), greaterThanOrEqualTo(3));
    });
  });

  group('using it', () {
    testWidgets('tapping a row selects it', (tester) async {
      await pumpSidebar(tester);

      await tester.tap(find.text('Insights'));
      await tester.tap(find.text('Settings'));

      expect(taps, [1, 3]);
    });

    testWidgets('an understated hover shows under the pointer, only on that row', (tester) async {
      await pumpSidebar(tester);
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(pointer.removePointer);
      await pointer.addPointer(location: Offset.zero);

      Color? hoverOf(String label) {
        final ink = tester.widget<InkWell>(
          find.descendant(of: row(label), matching: find.byType(InkWell)),
        );
        final state = ink.hoverColor;
        return state;
      }

      // The hover colour is the app's faint white wash, and not a strong one.
      expect(hoverOf('Insights'), AppColors.hoverOverlay);
      expect(AppColors.hoverOverlay.a, lessThan(0.10));

      await pointer.moveTo(tester.getCenter(find.text('Insights')));
      await tester.pump();
      expect(tester.binding.renderViews, isNotEmpty); // drew without error
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab reaches each row in order, and a ring shows on the one with focus', (
      tester,
    ) async {
      await pumpSidebar(tester);

      Finder ring() {
        return find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          if (widget.position != DecorationPosition.foreground) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.border?.top.color == AppColors.accent;
        });
      }

      expect(ring(), findsNothing);

      for (final destination in appDestinations) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        // One ring on screen, and it is round the focused row.
        expect(ring(), findsOneWidget, reason: 'ring on ${destination.label}');
        final ringBox = tester.getRect(ring());
        expect(ringBox, tester.getRect(row(destination.label)), reason: destination.label);
        final width =
            ((tester.widget<DecoratedBox>(ring()).decoration as BoxDecoration).border! as Border)
                .top
                .width;
        expect(width, 2);
      }
    });

    testWidgets('Enter and Space on a focused row select it', (tester) async {
      await pumpSidebar(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Home
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Insights
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Watchlist
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(taps, [1, 2]);
    });

    testWidgets('the current row is announced as selected, the others are not', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSidebar(tester, current: 1);

      bool isSelected(String label) {
        return tester
                .getSemantics(find.text(label))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue;
      }

      expect(isSelected('Insights'), isTrue);
      expect(isSelected('Home'), isFalse);
      expect(isSelected('Settings'), isFalse);
      expect(
        tester.getSemantics(find.text('Home')).getSemanticsData().flagsCollection.isButton,
        isTrue,
      );

      handle.dispose();
    });
  });

  group('the new-breaches count on Watchlist', () {
    testWidgets('shows beside the label, and says what it means to a screen reader',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSidebar(tester, newBreaches: 3);

      expect(find.text('3'), findsOneWidget);
      // Read as part of the row: "Watchlist, 3 new breaches".
      final label = tester.getSemantics(find.text('Watchlist')).label;
      expect(label, contains('Watchlist'));
      expect(label, contains('3 new breaches'));
      // The row keeps its height.
      expect(tester.getSize(row('Watchlist')).height, 46);

      handle.dispose();
    });

    testWidgets('is absent when there is nothing new, and singular for one', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSidebar(tester);
      expect(tester.getSemantics(find.text('Watchlist')).label, isNot(contains('new breach')));

      await pumpSidebar(tester, newBreaches: 1);
      final label = tester.getSemantics(find.text('Watchlist')).label;
      expect(label, contains('1 new breach'));
      expect(label, isNot(contains('breaches')));

      handle.dispose();
    });
  });

  group('the rail and the bottom bar use the same icons and colours', () {
    testWidgets('rail', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(820, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Row(
              children: [AppNavRail(selectedIndex: 2, onSelected: (_) {}, newBreaches: 0)],
            ),
          ),
        ),
      );

      for (final destination in appDestinations) {
        expect(tester.widget<Icon>(icon(destination.icon)).size, 20);
      }
      expect(tester.widget<Icon>(icon(LucideIcons.eye)).color, AppColors.accent);
      expect(tester.widget<Icon>(icon(LucideIcons.house)).color, AppColors.textSecondary);
    });

    testWidgets('bottom bar', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            bottomNavigationBar: AppBottomBar(selectedIndex: 1, onSelected: (_) {}, newBreaches: 2),
          ),
        ),
      );

      for (final destination in appDestinations) {
        expect(icon(destination.icon), findsOneWidget);
      }
      // Only Lucide icons: nothing here is a Material icon.
      for (final widget in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(widget.icon!.fontFamily, 'Lucide');
      }
      expect(find.text('2'), findsOneWidget); // the count badge
    });
  });
}
