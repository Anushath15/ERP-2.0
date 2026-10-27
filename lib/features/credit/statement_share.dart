import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../domain/message_templates.dart';
import '../../design/widgets.dart' show tr;
import '../../domain/credit/dues.dart';
import '../../fake/models.dart';
import '../../fake/shop_profile.dart';
import '../../fake/store.dart' show customersProvider;
import '../share/whatsapp_share.dart';
import 'statement_pdf.dart';

/// The message that goes with a statement: who it is from, the dates, and the amount to pay (and the UPI ID when the shop has one).
String statementMessage({required String customerName, required String shopName, required String shopPhone, required String upiId, required Statement statement, required DateTime today, Map<String, String> templates = const {}}) {
  final due = statement.closingPaise;
  final from = statement.from.year <= 2000 ? 'up to ' : '${formatDate(statement.from)} to ';
  return fillMessage(messageTemplateOf(templates, MessageKind.statement), {
    '{customer_name}': customerName.trim(),
    '{shop_name}': shopName.trim(),
    '{shop_phone}': shopPhone.trim(),
    '{period}': '$from${formatDate(statement.to)}',
    '{balance_text}': due > 0 ? 'Amount to pay: ${formatPaise(due, symbol: true)}' : (due < 0 ? 'You have ${formatPaise(-due, symbol: true)} in advance with us.' : 'Nothing is due. Thank you!'),
    '{amount_due}': due > 0 ? formatPaise(due, symbol: true) : '',
    '{upi_id}': due > 0 ? upiId.trim() : '',
  });
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
    message: statementMessage(customerName: customer.name, shopName: shop.name, shopPhone: shop.phone, upiId: shop.upiId, statement: statement, today: now, templates: shop.messageTemplates),
    fileName: 'Statement ${customer.name} $stamp.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-'),
    pdf: () => buildStatementPdf(statement: statement, customer: customer, shopName: shop.name, shopPhone: shop.phone, today: now, l: l, shop: shop),
    onNumber: (p) => ref.read(customersProvider.notifier).updatePhone(customer.id, p),
  );
}
