/// The words of every WhatsApp message the program writes, as templates the shop can edit (Shop profile > WhatsApp messages). A template is plain
/// text with placeholders in braces, like {customer_name}. Each kind has a default; the shop's own text replaces it, and "Reset" brings the default back.
///
/// Filling: a line that uses a placeholder with no value (no UPI ID, no balance, no note) is left out completely, so a message never shows an empty
/// "Pay by UPI:" line. An unknown placeholder (a typing slip like {custmer}) is left as typed, so the mistake is visible in the preview.
library;

enum MessageKind { bill, estimate, statement, order }

const messageKindOrder = [MessageKind.bill, MessageKind.estimate, MessageKind.statement, MessageKind.order];

/// The longest message a template or a filled message may be (WhatsApp links get unreliable beyond a couple of thousand characters).
const maxMessageLength = 1500;

const defaultBillMessage = '''Hello {customer_name},
This is {shop_name}.
Your bill {number} dated {date} for {amount} is attached.
Balance to pay: {balance_due}
Pay by UPI: {upi_id}
For any question: {shop_phone}
Thank you.''';

const defaultEstimateMessage = '''Hello {customer_name},
This is {shop_name}.
Your estimate {number} dated {date} for {amount} is attached.
This is an estimate, not a bill. Prices may change.
For any question: {shop_phone}
Thank you.''';

const defaultStatementMessage = '''Hello {customer_name},
This is {shop_name}.
Your account statement ({period}) is attached.
{balance_text}
Pay by UPI: {upi_id}
For any question: {shop_phone}
Thank you.''';

const defaultOrderMessage = '''Hello {dealer_name},
This is {shop_name}. Please send these items ({number}):
{item_list}
{note}
Please confirm the rates and when you can deliver. The order is also in the PDF.
{shop_phone}
Thank you.''';

String defaultMessage(MessageKind k) => switch (k) {
      MessageKind.bill => defaultBillMessage,
      MessageKind.estimate => defaultEstimateMessage,
      MessageKind.statement => defaultStatementMessage,
      MessageKind.order => defaultOrderMessage,
    };

/// The placeholders a kind of message may use (shown as chips under the editor).
List<String> messagePlaceholders(MessageKind k) => switch (k) {
      MessageKind.bill => const ['{customer_name}', '{shop_name}', '{shop_phone}', '{number}', '{date}', '{amount}', '{balance_due}', '{upi_id}'],
      MessageKind.estimate => const ['{customer_name}', '{shop_name}', '{shop_phone}', '{number}', '{date}', '{amount}'],
      MessageKind.statement => const ['{customer_name}', '{shop_name}', '{shop_phone}', '{period}', '{balance_text}', '{amount_due}', '{upi_id}'],
      MessageKind.order => const ['{dealer_name}', '{shop_name}', '{shop_phone}', '{number}', '{item_list}', '{note}'],
    };

/// Fills [template] with [values] (keys like '{number}'). A line whose placeholder has an empty value is dropped; the result is never longer than
/// [maxMessageLength] (cut at a line end when it can be).
String fillMessage(String template, Map<String, String> values) {
  final out = <String>[];
  final marks = RegExp(r'\{[a-z_]+\}');
  for (final line in template.split('\n')) {
    final used = [for (final m in marks.allMatches(line)) m.group(0)!].where(values.containsKey).toList();
    if (used.any((k) => values[k]!.trim().isEmpty)) continue;
    var l = line;
    for (final k in used) {
      l = l.replaceAll(k, values[k]!);
    }
    out.add(l);
  }
  var text = out.join('\n').trim();
  if (text.length > maxMessageLength) {
    final cut = text.lastIndexOf('\n', maxMessageLength - 1);
    text = cut > maxMessageLength ~/ 2 ? text.substring(0, cut) : '${text.substring(0, maxMessageLength - 1)}…';
  }
  return text;
}

/// Made-up details for the preview under the editor (the real message is filled from the bill, estimate, statement or order being sent).
Map<String, String> sampleMessageValues(MessageKind k, {required String shopName, required String shopPhone, required String upiId, required String today}) => switch (k) {
      MessageKind.bill => {'{customer_name}': 'Murugan Electricals', '{shop_name}': shopName, '{shop_phone}': shopPhone, '{number}': 'A-000123', '{date}': today, '{amount}': '₹1,250.00', '{balance_due}': '₹250.00', '{upi_id}': upiId},
      MessageKind.estimate => {'{customer_name}': 'Murugan Electricals', '{shop_name}': shopName, '{shop_phone}': shopPhone, '{number}': 'EST-00045', '{date}': today, '{amount}': '₹3,480.00'},
      MessageKind.statement => {'{customer_name}': 'Murugan Electricals', '{shop_name}': shopName, '{shop_phone}': shopPhone, '{period}': 'up to $today', '{balance_text}': 'Amount to pay: ₹3,450.00', '{amount_due}': '₹3,450.00', '{upi_id}': upiId},
      MessageKind.order => {'{dealer_name}': 'Kumar Agencies', '{shop_name}': shopName, '{shop_phone}': shopPhone, '{number}': 'PO-0007', '{item_list}': '1. 4" PVC TEE - 10 Nos\n2. 18W LED BULB - 25 Nos', '{note}': 'Please deliver by Friday.'},
    };

/// The shop's own text for [k] when it wrote one, else the default.
String messageTemplateOf(Map<String, String> custom, MessageKind k) {
  final t = custom[k.name];
  return t == null || t.trim().isEmpty ? defaultMessage(k) : t;
}
