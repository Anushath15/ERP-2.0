import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

// SECURITY / QUOTA: when the free daily limit is reached the program keeps working on this computer and tells the owner plainly.
void main() {
  testWidgets('the sync badge says "Sync paused: daily limit reached" and the settings page explains it calmly', (tester) async {
    final c = await pumpApp(tester, size: desktop1920, location: '/settings');
    final before = find.text('Sync paused: daily limit reached').evaluate().length; // only the demo chip
    expect(find.textContaining('Nothing is charged'), findsNothing);
    c.read(settingsProvider.notifier).set((s) => s.copyWith(sync: SyncState.paused));
    await tester.pump();
    expect(find.text('Sync paused: daily limit reached').evaluate().length, greaterThan(before), reason: 'the status badge now says it');
    expect(find.textContaining('safe on this computer'), findsOneWidget);
    expect(find.textContaining('Nothing is charged'), findsOneWidget);
  });

  testWidgets('the dashboard shows the paused status without errors', (tester) async {
    final c = await pumpApp(tester, size: desktop1920, location: '/');
    c.read(settingsProvider.notifier).set((s) => s.copyWith(sync: SyncState.paused));
    await tester.pump();
    expect(find.text('Sync paused: daily limit reached'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
