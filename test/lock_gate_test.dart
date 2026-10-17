import 'dart:async';

import 'package:breach_checker/core/app_theme.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/settings_controller.dart';
import 'package:breach_checker/widgets/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late SettingsController settings;
  late FakeAppLockService lock;

  /// Builds a [LockGate] around a stand-in app. The fake lock is set up
  /// *before* the first frame, because the lock screen asks for the prompt as
  /// soon as it appears.
  Future<void> pumpGate(
    WidgetTester tester, {
    required bool lockOn,
    bool succeeds = true,
    bool available = true,
    bool holdPrompt = false,
  }) async {
    final store = MemoryKeyValueStore();
    if (lockOn) await store.setBool('settings.appLock', true);
    settings = SettingsController(store);
    addTearDown(settings.dispose);

    lock = FakeAppLockService(available: available, succeeds: succeeds);
    if (holdPrompt) lock.pending = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LockGate(
          settings: settings,
          lock: lock,
          child: const Scaffold(body: Center(child: Text('Secret contents'))),
        ),
      ),
    );
  }

  testWidgets('with the lock off, the app is simply shown', (tester) async {
    await pumpGate(tester, lockOn: false);

    expect(find.text('Secret contents'), findsOneWidget);
    expect(find.text('Exposr is locked'), findsNothing);
    expect(lock.reasons, isEmpty);
  });

  testWidgets('with the lock on, the lock screen covers the app and asks at once', (tester) async {
    await pumpGate(tester, lockOn: true, holdPrompt: true); // the prompt stays open
    await tester.pump();

    expect(find.text('Exposr is locked'), findsOneWidget);
    expect(find.text('Secret contents'), findsNothing); // hidden, not just covered
    expect(lock.reasons, ['Unlock Exposr']);
  });

  testWidgets('passing the prompt reveals the app', (tester) async {
    await pumpGate(tester, lockOn: true);
    await tester.pumpAndSettle();

    expect(find.text('Secret contents'), findsOneWidget);
    expect(find.text('Exposr is locked'), findsNothing);
  });

  testWidgets('failing the prompt keeps the app locked and says so', (tester) async {
    await pumpGate(tester, lockOn: true, succeeds: false);
    await tester.pumpAndSettle();

    expect(find.text('Exposr is locked'), findsOneWidget);
    expect(find.textContaining('That didn’t work'), findsOneWidget);
    expect(find.text('Secret contents'), findsNothing);
  });

  testWidgets('the Unlock button tries again', (tester) async {
    await pumpGate(tester, lockOn: true, succeeds: false);
    await tester.pumpAndSettle();
    expect(find.text('Secret contents'), findsNothing);

    lock.succeeds = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Secret contents'), findsOneWidget);
  });

  testWidgets('if the phone no longer has a screen lock, the lock switches itself off', (tester) async {
    await pumpGate(tester, lockOn: true, available: false);
    await tester.pumpAndSettle();

    expect(find.text('Secret contents'), findsOneWidget);
    expect(settings.lockEnabled, isFalse);
  });

  testWidgets('going to the background locks the app again', (tester) async {
    await pumpGate(tester, lockOn: true);
    await tester.pumpAndSettle();
    expect(find.text('Secret contents'), findsOneWidget);

    // From now on the prompt stays open, so we can look at the locked screen.
    lock.pending = Completer<bool>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Exposr is locked'), findsOneWidget);
    expect(find.text('Secret contents'), findsNothing);
  });

  testWidgets('turning the lock on does not lock you out of the app you are using', (tester) async {
    await pumpGate(tester, lockOn: false);

    await settings.setLockEnabled(true);
    await tester.pumpAndSettle();

    expect(find.text('Secret contents'), findsOneWidget);
    expect(find.text('Exposr is locked'), findsNothing);
  });
}
