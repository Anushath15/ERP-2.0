import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/core/link_launcher.dart';
import 'package:erp2/fake/security_store.dart';
import 'helpers.dart';

// The Security card shows who can do what, the devices (approve / revoke) and the last sign-ins. Sample people in Phase 1.
void main() {
  Future<void> open(WidgetTester t, {FakeLauncher? launcher}) async {
    await pumpApp(t, size: desktop1920, location: '/settings', extraOverrides: launcher == null ? const [] : [linkLauncherProvider.overrideWithValue(launcher)]);
    await t.ensureVisible(find.byKey(const ValueKey('securityCard')));
    await t.pump();
  }

  testWidgets('shows roles in plain words, devices with their state and last sign-ins', (t) async {
    await open(t);
    expect(find.text('Security'), findsWidgets);
    expect(find.textContaining('Owner'), findsWidgets);
    expect(find.textContaining('Cashier'), findsWidgets);
    expect(find.text('Waiting for your approval'), findsOneWidget);
    expect(find.text('Approved'), findsWidgets);
    expect(find.textContaining('Last sign-ins'), findsOneWidget);
  });

  testWidgets('approve a waiting device; revoke an approved one only after confirming', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('approve-dev-pending')));
    await t.pumpAndSettle();
    expect(find.text('Waiting for your approval'), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('revoke-dev-counter')));
    await t.tap(find.byKey(const ValueKey('revoke-dev-counter')));
    await t.pumpAndSettle();
    expect(find.textContaining('stop working'), findsOneWidget, reason: 'asks first');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('revoke-dev-counter')), findsOneWidget, reason: 'cancelled: still approved');
    await t.tap(find.byKey(const ValueKey('revoke-dev-counter')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('confirm-revoke')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('revoke-dev-counter')), findsNothing);
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('the two-step verification line says the program cannot check it, and the link opens Google\'s own page', (t) async {
    final fake = FakeLauncher();
    await open(t, launcher: fake);
    expect(find.textContaining('cannot check'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('open2sv')));
    await t.tap(find.byKey(const ValueKey('open2sv')));
    await t.pumpAndSettle();
    expect(fake.opened.single, 'https://myaccount.google.com/signinoptions/twosv');
  });

  test('a stopped device stays stopped: it cannot be approved again by accident, only a new request can', () {
    final d = [const SampleDevice('a', 'PC', 'x@example.com', DeviceState.revoked, 'now')];
    expect(canApprove(d.first), isFalse);
    expect(canApprove(const SampleDevice('b', 'PC', 'x@example.com', DeviceState.pending, 'now')), isTrue);
  });
}
