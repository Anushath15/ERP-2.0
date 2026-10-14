import 'package:drift/native.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/data/ids.dart';
import 'package:erp2/domain/models.dart';

/// A fresh in-memory shop for tests. [clock] defaults to a fixed afternoon so days and numbers are predictable.
AppData memoryShop({DateTime? now, String device = 'dev-test'}) {
  var t = now ?? DateTime(2026, 10, 14, 15, 30);
  final db = AppDatabase(NativeDatabase.memory(), native: false);
  final cx = DataContext(db: db, deviceId: device, clock: () => t);
  return AppData(cx);
}

Product sampleProduct(String name, {int price = 15000, int cost = 9000, int stock = 10000, int gst = 1800, String id = '', String unit = 'pcs'}) =>
    Product(id: id.isEmpty ? newId() : id, name: name, category: 'Hardware', unit: unit, pricePaise: price, costPaise: cost, stockMilli: stock, gstBp: gst, barcode: '');

Customer sampleCustomer(String name, {String id = '', int limit = 5000000, String phone = '9876543210'}) => Customer(id: id.isEmpty ? newId() : id, name: name, phone: phone, city: 'Coimbatore', balancePaise: 0, creditLimitPaise: limit);
