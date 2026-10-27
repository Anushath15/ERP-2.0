import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/file_saver.dart';
import '../../core/money.dart';
import '../../domain/message_templates.dart';
import '../../design/widgets.dart' show tr, toast;
import '../../fake/shop_profile.dart';
import '../../fake/store.dart';
import '../billing/cart.dart';
import '../share/whatsapp_share.dart';
import 'doc_pdf.dart';

/// The paper of a downloaded or shared PDF: the paper chosen in Settings when it is A4 or A5; a roll paper (80 or 58 mm) is a printer's
/// width, so a PDF for a customer is made on A4.
PaperSize shareablePaper(PaperSize p) => p == PaperSize.a5 ? PaperSize.a5 : PaperSize.a4;

/// "Bill A-000006.pdf" / "Estimate EST-00011.pdf", with no character a file name cannot hold.
String docFileName(PrintDoc doc, {required String bill, required String estimate}) => '${doc.mode == DocMode.estimation ? estimate : bill} ${doc.number}.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

/// The words that go with the PDF on WhatsApp.
String docMessage(PrintDoc doc, {required String shopName, required String shopPhone, String upiId = '', Map<String, String> templates = const {}}) {
  final est = doc.mode == DocMode.estimation;
  final due = !est && doc.balancePaise > 0;
  return fillMessage(messageTemplateOf(templates, est ? MessageKind.estimate : MessageKind.bill), {
    '{customer_name}': doc.customer.trim(),
    '{shop_name}': shopName.trim(),
    '{shop_phone}': shopPhone.trim(),
    '{number}': doc.number,
    '{date}': formatDate(doc.date),
    '{amount}': formatPaise(doc.calc.grandTotal, symbol: true),
    '{balance_due}': due ? formatPaise(doc.balancePaise, symbol: true) : '',
    '{upi_id}': due ? upiId.trim() : '',
  });
}

/// Download PDF: makes the PDF of a bill or an estimate and saves it like the other downloads (the same page the printed copy has).
Future<void> downloadDocPdf(BuildContext context, WidgetRef ref, PrintDoc doc) async {
  final l = tr(context);
  try {
    final st = ref.read(settingsProvider);
    final bytes = await buildDocPdf(doc: doc, paper: shareablePaper(st.paper), shop: ref.read(shopProvider), size: st.printSize, l: l);
    final where = await ref.read(fileSaverProvider).save(docFileName(doc, bill: 'Bill', estimate: 'Estimate'), bytes);
    if (!context.mounted) return;
    toast(context, where == null ? l.pdfFailed : l.pdfSaved(where));
  } catch (_) {
    if (context.mounted) toast(context, l.pdfFailed);
  }
}

/// Send on WhatsApp: the PDF is saved and copied so it can be pasted (Ctrl+V) into the chat that opens with the message.
Future<void> shareDocOnWhatsapp(BuildContext context, WidgetRef ref, PrintDoc doc) async {
  final l = tr(context);
  final shop = ref.read(shopProvider);
  final st = ref.read(settingsProvider);
  await showWhatsappShare(
    context,
    title: '${doc.mode == DocMode.estimation ? l.rcEstimate : l.rcTaxInvoice} ${doc.number}',
    phone: doc.customerPhone,
    message: docMessage(doc, shopName: shop.name, shopPhone: shop.phone, upiId: shop.upiId, templates: shop.messageTemplates),
    fileName: docFileName(doc, bill: 'Bill', estimate: 'Estimate'),
    pdf: () => buildDocPdf(doc: doc, paper: shareablePaper(st.paper), shop: shop, size: st.printSize, l: l),
  );
}
