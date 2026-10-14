// Saves bills as fast as it can until the program that started it kills it. Used by the power-cut test (test/data/kill_test.dart,
// tool/kill_test/run.dart): the database must always open afterwards and every bill must be complete or absent.
// Usage: writer <database file> <random seed>
import 'dart:io';
import 'dart:math';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/data/repo/bill_repo.dart';
import 'package:erp2/domain/credit/account.dart';
import 'package:erp2/domain/models.dart';

Future<void> main(List<String> args) async {
  final path = args[0];
  final r = Random(int.parse(args[1]));
  final db = await openShopDatabase(path);
  final d = AppData(DataContext(db: db, deviceId: 'dev-kill'));
  d.bills.series = 'K';
  if (await d.catalog.productCount() == 0) {
    for (var i = 0; i < 30; i++) {
      await d.catalog.saveProduct(Product(id: 'p$i', name: 'ITEM $i', category: 'Hardware', unit: 'pcs', pricePaise: 1000 + 137 * i, costPaise: 800, stockMilli: 100000, gstBp: i % 3 == 0 ? 1200 : 1800, barcode: ''), create: true);
    }
    for (var i = 0; i < 10; i++) {
      await d.catalog.saveCustomer(Customer(id: 'c$i', name: 'CUSTOMER $i', phone: '98765432$i', city: 'X', balancePaise: 0), create: true);
    }
  }
  stdout.writeln('READY');
  var n = await d.bills.count();
  while (true) {
    final lines = [
      for (var i = 0; i < 1 + r.nextInt(8); i++)
        () {
          final p = r.nextInt(30);
          return BillLineInput(productId: 'p$p', name: 'ITEM $p', unit: 'pcs', qtyMilli: 1000 * (1 + r.nextInt(5)), ratePaise: 1000 + 137 * p, gstBp: p % 3 == 0 ? 1200 : 1800);
        }(),
    ];
    final customer = r.nextInt(100) < 60 ? 'c${r.nextInt(10)}' : null;
    final received = customer != null && r.nextBool() ? r.nextInt(3000) : null;
    final key = 'kill-${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(1 << 30)}';
    final s = await d.bills.saveBill(SaveBillInput(idemKey: key, at: DateTime.now(), lines: lines, customerId: customer, customerName: customer ?? '', receivedPaise: received, payMode: r.nextInt(3)));
    n++;
    if (r.nextInt(10) == 0 && customer != null && s.balancePaise > 0) {
      await d.ledger.receivePayment(PartyKind.customer, partyId: customer, partyName: customer, amount: 1 + r.nextInt(s.balancePaise), mode: 'cash', at: DateTime.now());
    }
    if (r.nextInt(15) == 0) await d.bills.cancelBill(s.id, reason: 'kill test');
    stdout.writeln('OK $n');
  }
}
