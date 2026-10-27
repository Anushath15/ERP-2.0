/// Orders to dealers: a list of what to buy from one dealer. It is sent on WhatsApp, and when the goods come it becomes a purchase (the quantities and the
/// rates can still be changed there). Pure Dart. An order is one small record (kind `orders`): number, date, dealer, status, note, items.
library;

import 'message_templates.dart';
import 'models.dart';

enum OrderStatus { open, sent, converted, cancelled }

OrderStatus orderStatusOf(String s) => OrderStatus.values.firstWhere((x) => x.name == s, orElse: () => OrderStatus.open);

class OrderLine {
  const OrderLine({required this.productId, required this.name, required this.unit, required this.qtyMilli});
  final String productId, name, unit;
  final int qtyMilli;

  Map<String, Object> toMap() => {'pid': productId, 'name': name, 'unit': unit, 'qty': qtyMilli};

  static OrderLine? fromMap(Object? m) {
    if (m is! Map) return null;
    final q = m['qty'];
    if (q is! int || q <= 0) return null;
    return OrderLine(productId: '${m['pid'] ?? ''}', name: '${m['name'] ?? ''}', unit: '${m['unit'] ?? ''}', qtyMilli: q);
  }
}

/// A saved order, read from its record.
class OrderDoc {
  const OrderDoc({required this.id, required this.number, required this.date, required this.dealerId, required this.dealerName, required this.status, required this.note, required this.lines, this.purchaseNo = '', this.sentAt});
  final String id, number, dealerId, dealerName, note, purchaseNo;
  final DateTime date;
  final DateTime? sentAt;
  final OrderStatus status;
  final List<OrderLine> lines;

  bool get editable => status == OrderStatus.open || status == OrderStatus.sent;

  static OrderDoc fromRec(Rec r) {
    final raw = r.f['lines'];
    return OrderDoc(
      id: r.id,
      number: r.s('no'),
      date: r.f['date'] is DateTime ? r.f['date'] as DateTime : DateTime.fromMillisecondsSinceEpoch(0),
      dealerId: r.s('dealerId'),
      dealerName: r.s('dealerName'),
      status: orderStatusOf(r.s('status')),
      note: r.s('note'),
      purchaseNo: r.s('purchaseNo'),
      sentAt: r.f['sentAt'] is DateTime ? r.f['sentAt'] as DateTime : null,
      lines: _readLines(raw),
    );
  }

  static List<OrderLine> _readLines(Object? raw) {
    final out = <OrderLine>[];
    if (raw is List) {
      for (final m in raw) {
        final l = OrderLine.fromMap(m);
        if (l != null) out.add(l);
      }
    }
    return out;
  }

  static Map<String, Object> fields({required DateTime date, required String dealerId, required String dealerName, required OrderStatus status, required String note, required List<OrderLine> lines, String purchaseNo = '', DateTime? sentAt}) => {
        'date': date,
        'dealerId': dealerId,
        'dealerName': dealerName,
        'status': status.name,
        'note': note,
        'purchaseNo': purchaseNo,
        'lines': [for (final l in lines) l.toMap()],
        'sentAt': ?sentAt,
      };
}

/// The WhatsApp text of an order: who it is from, the numbered items with quantities, the note. WhatsApp links get unreliable beyond a couple of thousand
/// characters, so a very long list is cut and the PDF carries the rest.
String orderMessage({required String dealerName, required String shopName, required String shopPhone, required String number, required List<OrderLine> lines, String note = '', String Function(int milli)? qty, String? template}) {
  String q(int m) => qty != null ? qty(m) : (m % 1000 == 0 ? '${m ~/ 1000}' : (m / 1000).toString());
  final t = template ?? defaultOrderMessage;
  Map<String, String> values(String items) => {
        '{dealer_name}': dealerName.trim(),
        '{shop_name}': shopName.trim(),
        '{shop_phone}': shopPhone.trim(),
        '{number}': number,
        '{item_list}': items,
        '{note}': note.trim(),
      };
  // the items get what is left of the message length once the rest of the words are in
  final room = maxMessageLength - fillMessage(t, values('#')).length - 40;
  final body = StringBuffer();
  var shown = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = '${i + 1}. ${lines[i].name} - ${q(lines[i].qtyMilli)} ${lines[i].unit}\n';
    if (body.length + line.length > room) break;
    body.write(line);
    shown++;
  }
  if (shown < lines.length) body.write('... and ${lines.length - shown} more (see the PDF)\n');
  return fillMessage(t, values(body.toString().trimRight()));
}
