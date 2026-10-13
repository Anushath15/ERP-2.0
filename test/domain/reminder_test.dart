import 'package:flutter_test/flutter_test.dart';
import 'package:erp2/domain/credit/dues.dart';
import 'package:erp2/domain/credit/reminder.dart';

// These tests cover our own code: phone numbers, the message text, the link we build, the counter and the 24-hour guard.
// They do NOT prove that WhatsApp itself opens or sends anything: that needs a real phone or PC (listed as Not verified).

DateTime d(int y, int m, int day, [int h = 0, int min = 0]) => DateTime(y, m, day, h, min);

void main() {
  group('normalizePhone', () {
    const ok = {
      '9876543210': '919876543210',
      '98765 43210': '919876543210',
      '98765-43210': '919876543210',
      '(98765) 43210': '919876543210',
      '98765.43210': '919876543210',
      '09876543210': '919876543210',
      '0 98765 43210': '919876543210',
      '+91 98765 43210': '919876543210',
      '+919876543210': '919876543210',
      '919876543210': '919876543210',
      '0091 9876543210': '919876543210',
      '  6000000000 ': '916000000000',
      '+971 50 123 4567': '971501234567',
      '+1 (415) 555-2671': '14155552671',
      '0097150 123 4567': '971501234567',
    };
    for (final e in ok.entries) {
      test('accepts "${e.key}"', () => expect(normalizePhone(e.key), e.value));
    }
    const bad = ['', '   ', 'abc', '98765abc10', '12345', '123456789', '98765432100', '5876543210', '1234567890', '+91 12345 67890', '+91 98765 4321', '+91 98765 432100', '++919876543210', '9876-5432-1', '0', '+', '00', '+0123456789', 'call me'];
    for (final b in bad) {
      test('rejects "$b"', () => expect(normalizePhone(b), isNull));
    }
    test('another default country code works', () {
      expect(normalizePhone('0501234567', defaultCountry: '971'), isNull, reason: 'only Indian-style 10-digit mobiles are auto-completed');
      expect(normalizePhone('+971501234567', defaultCountry: '971'), isNull, reason: 'a 971 number must follow the same 10-digit rule: not Indian mobile');
      expect(normalizePhone('+919876543210', defaultCountry: '971'), '919876543210');
    });
    test('pretty form', () {
      expect(prettyPhone('919876543210'), '+91 98765 43210');
      expect(prettyPhone('971501234567'), '+971501234567');
    });
  });

  group('message builder', () {
    final today = d(2026, 10, 13);
    List<BillDue> bills(int n) => [for (var i = 0; i < n; i++) BillDue(billNo: 'A-0198${10 + i}', date: d(2026, 7, 1 + i), totalPaise: 100000 + i * 5000, paidPaise: i == 0 ? 20000 : 0)];
    ReminderInput input({int n = 3, String upi = 'shop@upi', String phone = '98765 43210', DateTime? last}) => ReminderInput(customerName: 'Murugan Traders', shopName: 'Senthil Enterprises', shopPhone: phone, upiId: upi, bills: bills(n), today: today, lastPaymentDate: last);

    test('friendly message has every piece, in plain words', () {
      final m = buildReminderMessage(defaultFriendlyTemplate, input(last: d(2026, 9, 5)));
      expect(m, contains('Hello Murugan Traders,'));
      expect(m, contains('Senthil Enterprises'));
      expect(m, contains('Rs. 2,950.00 is pending'), reason: '800 + 1050 + 1100 rupees');
      expect(m, contains('01/07/2026'));
      expect(m, contains('104 days ago'));
      expect(m, contains('A-019810  01/07/2026  Rs. 800.00'));
      expect(m, contains('A-019812'));
      expect(m, contains('Last payment received: 05/09/2026'));
      expect(m, contains('shop@upi'));
      expect(m, contains('98765 43210'));
      expect(m, isNot(contains('{')), reason: 'no placeholder is left');
    });

    test('bill list shows 5 oldest then "and N more"', () {
      final m = buildReminderMessage(defaultFriendlyTemplate, input(n: 8));
      expect('A-0198'.allMatches(m).length, 5);
      expect(m, contains('and 3 more'));
      expect(m, contains('A-019810'));
      expect(m, isNot(contains('A-019815')));
    });

    test('lines with a missing value are dropped, never printed empty', () {
      final m = buildReminderMessage(defaultFriendlyTemplate, input(upi: '', phone: ' ', last: null));
      expect(m, isNot(contains('UPI')));
      expect(m, isNot(contains('Call us')));
      expect(m, isNot(contains('Last payment')));
    });

    test('firm tone is a different, still polite message', () {
      final m = buildReminderMessage(defaultFirmTemplate, input());
      expect(m, contains('overdue'));
      expect(m, contains('Dear Murugan Traders'));
      expect(m, isNot(equals(buildReminderMessage(defaultFriendlyTemplate, input()))));
    });

    test('custom template with every placeholder', () {
      final all = reminderPlaceholders.join('|');
      final m = buildReminderMessage(all, input(last: d(2026, 9, 5)));
      expect(m.split('|').length, 9);
      expect(m, isNot(contains('{')));
    });

    test('unknown placeholders are left alone; nothing owed gives an empty bill list line dropped', () {
      expect(buildReminderMessage('Hi {customer_name} {nonsense}', input()), 'Hi Murugan Traders {nonsense}');
      final none = ReminderInput(customerName: 'A', shopName: 'S', shopPhone: '1', upiId: '', bills: const [], today: today);
      expect(buildReminderMessage('{customer_name}\n{bill_list}\nbye', none), 'A\nbye');
    });

    test('stays under 1,500 characters: fewer bills are listed, then the text is cut', () {
      final long = 'x' * 40;
      final i = ReminderInput(customerName: long, shopName: long, shopPhone: '1', upiId: long, bills: bills(60), today: today);
      final m = buildReminderMessage(defaultFriendlyTemplate, i);
      expect(m.length, lessThanOrEqualTo(maxReminderLength));
      final huge = buildReminderMessage('{customer_name}' * 200, ReminderInput(customerName: 'N' * 30, shopName: 's', shopPhone: '1', upiId: '', bills: bills(1), today: today));
      expect(huge.length, maxReminderLength);
      expect(huge.endsWith('…'), true);
    });

    test('default templates fit comfortably with a normal customer', () {
      expect(buildReminderMessage(defaultFriendlyTemplate, input(n: 20)).length, lessThan(700));
      expect(buildReminderMessage(defaultFirmTemplate, input(n: 20)).length, lessThan(700));
    });
  });

  group('whatsapp links', () {
    const digits = '919876543210';
    const msg = 'Hello Ravi & Sons,\nPending: ₹ 1,200.50 (A-1) "quote" 50% #tag +1 ?x=1';
    final links = buildWhatsappLinks(digits: digits, message: msg);

    test('wa.me link: number in the path, text encoded', () {
      expect(links.webLink, startsWith('https://wa.me/919876543210?text='));
      final text = Uri.parse(links.webLink).queryParameters['text'];
      expect(text, msg, reason: 'decoding gives back exactly what we sent (new lines, rupee sign, &, quotes, %, #, +, ?)');
      expect(links.webLink, isNot(contains('\n')));
      expect(links.webLink, contains('%0A'));
      expect(links.webLink.substring(links.webLink.indexOf('?text=') + 6), isNot(contains('&')), reason: 'an ampersand in the text must not end the text');
      expect(links.webLink, isNot(contains(' ')));
    });

    test('app link: whatsapp://send with phone and the same text', () {
      expect(links.appLink, startsWith('whatsapp://send?phone=919876543210&text='));
      final u = Uri.parse(links.appLink);
      expect(u.queryParameters['phone'], digits);
      expect(u.queryParameters['text'], msg);
    });

    test('which link is tried first on each platform', () {
      expect(links.tryOrder(LinkPlatform.windows), [links.appLink, links.webLink]);
      expect(links.tryOrder(LinkPlatform.android), [links.appLink, links.webLink]);
      for (final p in [LinkPlatform.web, LinkPlatform.macos, LinkPlatform.linux, LinkPlatform.ios]) {
        expect(links.tryOrder(p), [links.webLink], reason: '$p');
      }
    });

    test('refuses a bad number', () {
      expect(() => buildWhatsappLinks(digits: '98765', message: 'x'), throwsArgumentError);
      expect(() => buildWhatsappLinks(digits: '+919876543210', message: 'x'), throwsArgumentError);
    });

    test('a full 1,500-character message makes a link that decodes back to the same text', () {
      final long = List.generate(1500, (i) => 'abc ₹&\n"+#'[i % 10]).join();
      final l = buildWhatsappLinks(digits: digits, message: long);
      expect(Uri.parse(l.webLink).queryParameters['text'], long);
    });
  });

  group('can we open WhatsApp now?', () {
    test('offline disables it with the reason; a missing number asks for the number; otherwise allowed', () {
      final off = canOpenWhatsapp(online: false, digits: '919876543210');
      expect(off.allowed, false);
      expect(off.reason, 'Needs internet; you are offline');
      final nonum = canOpenWhatsapp(online: true, digits: null);
      expect(nonum.allowed, false);
      expect(nonum.reason, contains('number'));
      expect(canOpenWhatsapp(online: true, digits: '919876543210').allowed, true);
      expect(canOpenWhatsapp(online: false, digits: null).reason, 'Needs internet; you are offline');
    });
  });

  group('reminder log: counter, undo, 24-hour guard', () {
    ReminderRecord rec(String id, String cid, DateTime at) => ReminderRecord(id: id, customerId: cid, at: at, amountDuePaise: 12345, message: 'm', by: 'owner');

    test('each opened reminder adds one to the customer count; undo takes it back', () {
      var log = const ReminderLog();
      log = log.add(rec('1', 'c1', d(2026, 10, 10, 9)));
      log = log.add(rec('2', 'c1', d(2026, 10, 12, 16, 10)));
      log = log.add(rec('3', 'c2', d(2026, 10, 12, 17)));
      expect(log.countFor('c1'), 2);
      expect(log.countFor('c2'), 1);
      expect(log.countFor('nobody'), 0);
      expect(log.lastFor('c1'), d(2026, 10, 12, 16, 10));
      log = log.undo('2');
      expect(log.countFor('c1'), 1);
      expect(log.lastFor('c1'), d(2026, 10, 10, 9));
      expect(log.undo('missing').records.length, log.records.length, reason: 'unknown id changes nothing');
      expect(log.forCustomer('c1').first.id, '1');
    });

    test('guard: a reminder in the last 24 hours asks first', () {
      final log = const ReminderLog().add(rec('1', 'c1', d(2026, 10, 12, 16, 10)));
      expect(log.recent('c1', d(2026, 10, 13, 16, 9))?.id, '1', reason: '23h59m later');
      expect(log.recent('c1', d(2026, 10, 13, 16, 10)), isNull, reason: 'exactly 24 hours later: allowed again');
      expect(log.recent('c2', d(2026, 10, 12, 17)), isNull, reason: 'another customer');
      expect(log.recent('c1', d(2026, 10, 12, 20), hours: 2), isNull, reason: 'guard length is a setting');
      expect(log.recent('c1', d(2026, 10, 12, 17), hours: 2)?.id, '1');
    });

    test('guard looks at the latest reminder, and an undo removes it from the guard', () {
      var log = const ReminderLog().add(rec('1', 'c1', d(2026, 10, 1))).add(rec('2', 'c1', d(2026, 10, 13, 8)));
      expect(log.recent('c1', d(2026, 10, 13, 9)), isNotNull);
      log = log.undo('2');
      expect(log.recent('c1', d(2026, 10, 13, 9)), isNull);
    });
  });
}
