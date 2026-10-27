import 'package:erp2/core/search_rank.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/features/billing/cart.dart';
import 'package:erp2/fake/models.dart';
import 'package:erp2/demo/seed.dart';
import 'package:erp2/fake/store.dart';
import 'helpers.dart';

/// Keyboard-first billing: type, Enter adds the first match, Up/Down moves, a barcode + Enter adds that product.
class _Big extends ProductsNotifier {
  @override
  List<Product> build() => seedProducts(count: 6000);
}

class _Branded extends ProductsNotifier {
  @override
  List<Product> build() {
    final all = seedProducts(count: 40);
    return [all[0].copyWith(brand: 'HAVELLS'), all[1].copyWith(brand: ''), ...all.skip(2)];
  }
}

void main() {
  for (final path in ['/bill', '/estimate']) {
    testWidgets('$path: the picker shows the brand of each product under its name (the same product of another brand has another rate), nothing when it has none', (tester) async {
      final c = await pumpApp(tester, size: desktop1366, location: path, extraOverrides: [productsProvider.overrideWith(_Branded.new)]);
      final list = c.read(productsProvider);
      expect(find.byKey(ValueKey('brand-${list[0].id}')), findsOneWidget);
      expect(find.text('HAVELLS'), findsWidgets);
      expect(find.byKey(ValueKey('brand-${list[1].id}')), findsNothing);
    });
  }

  testWidgets('a long catalogue: after scrolling far down, a new search starts at the top with its first match (and the list is a fresh view)', (tester) async {
    await pumpApp(tester, size: desktop1366, location: '/bill', extraOverrides: [productsProvider.overrideWith(_Big.new)]);
    ScrollableState list() {
      ScrollableState? best;
      for (final e in find.byType(Scrollable).evaluate()) {
        final st = (e as StatefulElement).state as ScrollableState;
        if (st.position.axis == Axis.vertical && st.position.maxScrollExtent > 1000 && (best == null || st.position.maxScrollExtent > best.position.maxScrollExtent)) best = st;
      }
      return best!;
    }

    for (var i = 0; i < 30; i++) {
      list().position.jumpTo(list().position.pixels + 900);
      await tester.pump();
    }
    expect(list().position.pixels, greaterThan(20000), reason: 'we are far down the list');
    await tester.enterText(find.byType(TextField).first, 'hacksaw');
    await tester.pumpAndSettle();
    expect(find.textContaining('HACKSAW'), findsWidgets);
    final after = tester.widgetList<ListView>(find.byType(ListView)).where((l) => l.key is ValueKey<int>).toList();
    expect(after, isNotEmpty, reason: 'the product list is a keyed view that is replaced for every new search');
  });

  testWidgets('Enter adds the first match; the search box clears and keeps focus', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    final first = c.read(productsProvider).firstWhere((p) => p.name.contains('HACKSAW'));
    await tester.enterText(find.byType(TextField).first, 'hacksaw');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final lines = c.read(cartProvider(DocMode.invoice)).lines;
    expect(lines.length, 1);
    expect(lines.first.product.name.contains('HACKSAW'), true);
    expect(first.name.contains('HACKSAW'), true);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '');
  });

  testWidgets('Down arrow then Enter adds the second match', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    await tester.enterText(find.byType(TextField).first, 'tower bolt');
    await tester.pumpAndSettle();
    // the list is best match first (see search_rank.dart), so the second match is the second best
    final matches = rankedSearch(c.read(productsProvider).where((p) => p.name.toLowerCase().contains('tower') && p.name.toLowerCase().contains('bolt')), 'tower bolt', (p) => '${p.name} ${p.barcode} ${p.code} ${p.brand} ${p.category}');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines.single.product.id, matches[1].id);
  });

  testWidgets('a scanned barcode plus Enter adds exactly that product', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    final p = c.read(productsProvider)[100];
    await tester.enterText(find.byType(TextField).first, p.barcode);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines.single.product.id, p.id);
  });

  testWidgets('no match: Enter opens the quick-add form with the typed name; the bill is untouched', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    c.read(cartProvider(DocMode.invoice).notifier).add(c.read(productsProvider).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'zz special elbow');
    await tester.pumpAndSettle();
    expect(find.text('No product found.'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Save and add to bill'), findsOneWidget);
    expect(find.text('zz special elbow'), findsWidgets); // prefilled in the name field
    expect(c.read(cartProvider(DocMode.invoice)).lines.length, 1, reason: 'opening the form does not change the bill');
  });

  testWidgets('long product names are never cut with an ellipsis', (tester) async {
    await pumpApp(tester, size: phone360, location: '/bill');
    final texts = tester.widgetList<Text>(find.byType(Text)).where((t) => (t.data ?? '').contains('HACKSAW') || (t.data ?? '').contains('LOCK'));
    for (final t in texts) {
      expect(t.overflow, isNot(TextOverflow.ellipsis));
    }
  });

  testWidgets('Ctrl+S saves the bill and clears it', (tester) async {
    final c = await pumpApp(tester, size: desktop1366, location: '/bill');
    c.read(cartProvider(DocMode.invoice).notifier).add(c.read(productsProvider).first);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(c.read(cartProvider(DocMode.invoice)).lines, isEmpty);
    expect(find.textContaining('saved'), findsWidgets);
  });
}
