/// Pure Dart: WhatsApp reminders. The app never sends anything itself. It builds a message and a link; the person presses
/// Send inside WhatsApp. So a "reminder" here means "opened in WhatsApp", and the history says exactly that.
library;

import '../../core/money.dart';
import 'dues.dart';

// ---------------------------------------------------------------- phone numbers

/// Turns what a person typed into WhatsApp digits (country code + number, no plus sign), or null if it is not a usable number.
///  * spaces, dashes, dots and brackets are ignored
///  * a 10-digit Indian mobile (starts 6-9) gets the default country code (91)
///  * a leading 0 on a 10-digit number is dropped (0 98765 43210)
///  * "+91..." and "0091..." and "91..." are accepted
///  * "+" followed by another country code is accepted if the length is sensible (8-15 digits)
///  * anything else (letters, too short, too long, 10 digits not starting 6-9) is rejected
String? normalizePhone(String input, {String defaultCountry = '91'}) {
  var s = input.trim();
  if (s.isEmpty || RegExp(r'[A-Za-z]').hasMatch(s)) return null;
  final plus = s.startsWith('+');
  s = s.replaceAll(RegExp(r'[ \t\-.()]'), '');
  if (plus) s = s.substring(1);
  if (!RegExp(r'^[0-9]+$').hasMatch(s)) return null;
  final cc = defaultCountry;
  bool indian(String ten) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(ten);
  bool international(String d) => d.length >= 8 && d.length <= 15 && !d.startsWith('0');
  // already international: "+..." or "00..."
  if (plus || s.startsWith('00')) {
    final d = plus ? s : s.substring(2);
    if (d.startsWith(cc)) return d.length == cc.length + 10 && indian(d.substring(cc.length)) ? d : null;
    return international(d) ? d : null;
  }
  if (s.length == 10 && indian(s)) return '$cc$s';
  if (s.length == 11 && s.startsWith('0') && indian(s.substring(1))) return '$cc${s.substring(1)}';
  if (s.length == cc.length + 10 && s.startsWith(cc) && indian(s.substring(cc.length))) return s;
  return null;
}

/// A short, friendly form for showing on screen: +91 98765 43210.
String prettyPhone(String digits) {
  if (digits.length == 12 && digits.startsWith('91')) return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
  return '+$digits';
}

// ---------------------------------------------------------------- message

enum ReminderTone { friendly, firm }

/// Placeholders a template may use (shown as chips in Settings > Reminders).
const reminderPlaceholders = ['{customer_name}', '{shop_name}', '{shop_phone}', '{amount_due}', '{oldest_bill_date}', '{days_overdue}', '{bill_list}', '{last_payment_date}', '{upi_id}'];

const defaultFriendlyTemplate = '''Hello {customer_name},
Greetings from {shop_name}.
A gentle reminder: Rs. {amount_due} is pending on your account.
Oldest bill: {oldest_bill_date} ({days_overdue} days ago).
{bill_list}
Please pay at your convenience.
Last payment received: {last_payment_date}
Pay by UPI: {upi_id}
Call us: {shop_phone}
Thank you!''';

const defaultFirmTemplate = '''Dear {customer_name},
This is {shop_name}. Rs. {amount_due} on your account is overdue. The oldest bill is from {oldest_bill_date}, {days_overdue} days ago.
{bill_list}
Please clear the payment at the earliest.
Last payment received: {last_payment_date}
Pay by UPI: {upi_id}
Call us: {shop_phone}
Thank you.''';

class ReminderInput {
  const ReminderInput({required this.customerName, required this.shopName, required this.shopPhone, required this.upiId, required this.bills, required this.today, this.lastPaymentDate});
  final String customerName, shopName, shopPhone, upiId;
  final List<BillDue> bills;
  final DateTime today;
  final DateTime? lastPaymentDate;
}

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// The longest message we build (WhatsApp links get unreliable beyond a couple of thousand characters).
const maxReminderLength = 1500;

/// Fills a template. Lines whose placeholder has no value (no UPI id, no last payment, no phone) are left out completely,
/// so the message never shows an empty "Pay by UPI:" line. The bill list shows up to 5 oldest unpaid bills and then
/// "and N more"; if the whole text is still above [maxReminderLength], fewer bills are listed, and as a last resort the text is cut.
String buildReminderMessage(String template, ReminderInput i, {int maxBills = 5}) {
  final unpaid = unpaidBills(i.bills);
  final total = unpaid.fold<int>(0, (s, b) => s + b.outstanding);
  final oldest = unpaid.isEmpty ? null : unpaid.first;

  String billList(int n) {
    if (unpaid.isEmpty) return '';
    final shown = unpaid.take(n).map((b) => '${b.billNo}  ${_date(b.date)}  Rs. ${formatPaise(b.outstanding)}').toList();
    if (unpaid.length > n) shown.add('and ${unpaid.length - n} more');
    return shown.join('\n');
  }

  String render(int n) {
    final values = <String, String>{
      '{customer_name}': i.customerName.trim(),
      '{shop_name}': i.shopName.trim(),
      '{shop_phone}': i.shopPhone.trim(),
      '{amount_due}': formatPaise(total),
      '{oldest_bill_date}': oldest == null ? '' : _date(oldest.date),
      '{days_overdue}': oldest == null ? '' : '${daysOld(oldest.date, i.today)}',
      '{bill_list}': billList(n),
      '{last_payment_date}': i.lastPaymentDate == null ? '' : _date(i.lastPaymentDate!),
      '{upi_id}': i.upiId.trim(),
    };
    final out = <String>[];
    for (final line in template.split('\n')) {
      final used = [for (final k in values.keys) if (line.contains(k)) k];
      if (used.any((k) => values[k]!.isEmpty)) continue; // a line that depends on a missing value is dropped
      var l = line;
      for (final k in used) {
        l = l.replaceAll(k, values[k]!);
      }
      out.add(l);
    }
    return out.join('\n').trim();
  }

  var n = maxBills;
  var text = render(n);
  while (text.length > maxReminderLength && n > 0) {
    n--;
    text = render(n);
  }
  if (text.length > maxReminderLength) text = '${text.substring(0, maxReminderLength - 1)}…';
  return text;
}

// ---------------------------------------------------------------- links

enum LinkPlatform { windows, android, ios, macos, linux, web }

class WhatsappLinks {
  const WhatsappLinks({required this.appLink, required this.webLink});

  /// `whatsapp://send?...` opens the installed WhatsApp app directly (Windows and Android).
  final String appLink;

  /// `https://wa.me/...` opens WhatsApp Web or the desktop app through the browser (works everywhere).
  final String webLink;

  /// The links to try, first to last, on this platform: the app link first where it is supported, then the web link.
  List<String> tryOrder(LinkPlatform p) => switch (p) {
        LinkPlatform.windows || LinkPlatform.android => [appLink, webLink],
        _ => [webLink],
      };
}

/// Builds both links. [digits] is the normalised number (country code + number). The text is percent-encoded, so new lines,
/// the rupee sign, ampersands, quotes, plus signs and hashes all survive.
WhatsappLinks buildWhatsappLinks({required String digits, required String message}) {
  if (!RegExp(r'^[0-9]{8,15}$').hasMatch(digits)) throw ArgumentError.value(digits, 'digits', 'not a WhatsApp number');
  final text = Uri.encodeQueryComponent(message).replaceAll('+', '%20');
  return WhatsappLinks(appLink: 'whatsapp://send?phone=$digits&text=$text', webLink: 'https://wa.me/$digits?text=$text');
}

// ---------------------------------------------------------------- can we open it now?

class OpenCheck {
  const OpenCheck(this.allowed, this.reason);
  final bool allowed;
  final String? reason;
}

/// WhatsApp needs internet and a valid number. The reason is in plain words, shown beside the disabled button.
OpenCheck canOpenWhatsapp({required bool online, required String? digits}) {
  if (!online) return const OpenCheck(false, 'Needs internet; you are offline');
  if (digits == null) return const OpenCheck(false, 'Add a valid WhatsApp number first');
  return const OpenCheck(true, null);
}

// ---------------------------------------------------------------- history, counter, guard

/// One tap on "Open WhatsApp". Append-only (an undo removes it right after the tap). It means "opened in WhatsApp":
/// the app cannot see whether the person pressed Send.
class ReminderRecord {
  const ReminderRecord({required this.id, required this.customerId, required this.at, required this.amountDuePaise, required this.message, required this.by});
  final String id, customerId, message, by;
  final DateTime at;
  final int amountDuePaise;
}

class ReminderLog {
  const ReminderLog([this.records = const []]);
  final List<ReminderRecord> records;

  ReminderLog add(ReminderRecord r) => ReminderLog([...records, r]);

  /// Removes one record (the "Not sent? Undo" action). Unknown id: nothing changes.
  ReminderLog undo(String id) => ReminderLog([for (final r in records) if (r.id != id) r]);

  List<ReminderRecord> forCustomer(String customerId) => [for (final r in records) if (r.customerId == customerId) r]..sort((a, b) => b.at.compareTo(a.at));

  /// "Reminders opened in WhatsApp" for this customer.
  int countFor(String customerId) => records.where((r) => r.customerId == customerId).length;

  DateTime? lastFor(String customerId) {
    final l = forCustomer(customerId);
    return l.isEmpty ? null : l.first.at;
  }

  /// The most recent reminder inside the guard window, or null: if there is one, ask "Send again?" first.
  ReminderRecord? recent(String customerId, DateTime now, {int hours = 24}) {
    final l = forCustomer(customerId);
    if (l.isEmpty) return null;
    final r = l.first;
    return now.difference(r.at) < Duration(hours: hours) ? r : null;
  }
}
