import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../design/widgets.dart' show tr;
import '../../domain/credit/dues.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show customersProvider;
import '../share/whatsapp_share.dart';
import 'statement_pdf.dart';

/// The message that goes with a statement: who it is from, the dates, and the amount to pay (and the UPI ID when the shop has one).
String statementMessage({required String customerName, required String shopName, required String shopPhone, required String upiId, required Statement statement, required DateTime today}) {
  final due = statement.closingPaise;
  final from = statement.from.year <= 2000 ? '' : '${formatDate(statement.from)} to ';
  final b = StringBuffer('Hello $customerName,\nThis is $shopName.');
  b.write('\nYour account statement (${from.isEmpty ? 'up to ' : from}${formatDate(statement.to)}) is attached.');
  if (due > 0) {
    b.write('\nAmount to pay: ${formatPaise(due, symbol: true)}');
    if (upiId.trim().isNotEmpty) b.write('\nPay by UPI: ${upiId.trim()}');
  } else if (due < 0) {
    b.write('\nYou have ${formatPaise(-due, symbol: true)} in advance with us.');
  } else {
    b.write('\nNothing is due. Thank you!');
  }
  if (shopPhone.trim().isNotEmpty) b.write('\nFor any question: ${shopPhone.trim()}');
  b.write('\nThank you.');
  return b.toString();
}

/// Statement on WhatsApp: the PDF is saved and its folder opens, the chat opens with the message (see [showWhatsappShare]).
Future<void> shareStatementOnWhatsapp(BuildContext context, WidgetRef ref, {required Statement statement, required Customer customer, required DateTime now}) async {
  final shop = ref.read(shopProvider);
  final l = tr(context);
  final stamp = '${now.year}-${two(now.month)}-${two(now.day)}';
  await showWhatsappShare(
    context,
    title: '${l.statementTitle}: ${customer.name}',
    phone: customer.phone,
    message: statementMessage(customerName: customer.name, shopName: shop.name, shopPhone: shop.phone, upiId: shop.upiId, statement: statement, today: now),
    fileName: 'Statement ${customer.name} $stamp.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-'),
    pdf: () => buildStatementPdf(statement: statement, customer: customer, shopName: shop.name, shopPhone: shop.phone, today: now, l: l, shop: shop),
    onNumber: (p) => ref.read(customersProvider.notifier).updatePhone(customer.id, p),
  );
}
