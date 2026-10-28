import 'dart:async';
import '../../strings.dart';
import '../../core/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../data/ids.dart';
import '../../design/form_sheet.dart';
import '../../design/motion.dart';
import '../../design/segments.dart';
import '../../design/widgets.dart';
import '../../domain/credit/ledger.dart';
import '../../domain/credit/payment_split.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/credit_store.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import 'credit_dialogs.dart';

String _m(int p) => formatPaise(p, symbol: true);

/// "Settle fully": the whole balance is recorded as received (customer) or paid (dealer). The person chooses how it was paid and
/// may add a note. Afterwards an Undo is offered for 8 seconds.
Future<void> showSettleFully(BuildContext context, PartyRef party) async {
  final l = tr(context);
  final container = ProviderScope.containerOf(context);
  final book = container.read(party.kind == PartyKind.customer ? creditProvider.notifier : dealerLedgerProvider.notifier);
  final owed = book.balanceOf(party.id);
  if (owed <= 0) {
    toast(context, party.kind == PartyKind.customer ? l.nobodyOwes : l.dealerNobodyDue);
    return;
  }
  final note = TextEditingController();
  var mode = 'cash';
  final ok = await showDialog<bool>(
    context: context,
    animationStyle: dialogStyle(context),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.settleTitle(party.name)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(party.kind == PartyKind.customer ? l.settleText(_m(owed)) : l.settleTextDealer(_m(owed), party.name)),
            const SizedBox(height: 12),
            SlideSegments<String>(options: [('cash', l.payCash, Icons.payments_rounded), ('upi', l.payUpi, Icons.qr_code_2_rounded), ('card', l.payCard, Icons.credit_card_rounded)], selected: mode, onChanged: (v) => setState(() => mode = v)),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('settleNote'), controller: note, inputFormatters: [safeInput(TextKind.note)], decoration: InputDecoration(labelText: l.settleNote)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton.icon(key: const ValueKey('settleConfirm'), onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.done_all_rounded), label: Text(l.settleConfirm(_m(owed)))),
        ],
      ),
    ),
  );
  final text = note.text.trim();
  note.dispose();
  if (ok != true || !context.mounted) return;
  final at = container.read(clockProvider);
  final r = await book.settleFully(customerId: party.id, customerName: party.name, mode: mode, at: at, note: text);
  if (r == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  toastAction(context, party.kind == PartyKind.customer ? l.settleDone(_m(r.amountPaise), party.name) : l.settleDoneDealer(_m(r.amountPaise), party.name), l.settleUndo, () {
    unawaited(() async {
      if (await book.undoPayment(r)) {
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(SnackBar(content: Text(l.settleUndone)));
      }
    }());
  }, seconds: 8);
}

/// Credit added by hand: amount, date, note and a reason (required).
Future<void> showAddCredit(BuildContext context, Customer c) async {
  final l = tr(context);
  final container = ProviderScope.containerOf(context);
  final v = await showFormSheet(context, title: l.addCreditTitle(c.name), saveLabel: l.save, note: l.addCreditHelp, fields: [
    FieldSpec('amount', l.fieldAmount, type: FieldType.money, required: true, autofocus: true),
    FieldSpec('date', l.fieldDate, type: FieldType.date, initial: formatDate(container.read(clockProvider))),
    FieldSpec('reason', l.fieldReason, required: true),
    FieldSpec('note', l.fieldNote),
  ]);
  if (v == null || !context.mounted) return;
  final amt = parseRupeesToPaise(v['amount'] ?? '') ?? 0;
  if (amt <= 0) return;
  final DateTime at = parseDmy(v['date'] ?? '') ?? container.read(clockProvider);
  final reason = (v['note'] ?? '').isEmpty ? v['reason']! : '${v['reason']} (${v['note']})';
  await container.read(creditProvider.notifier).addManualCredit(customerId: c.id, amount: amt, at: at, reason: reason);
  if (context.mounted) toast(context, l.addCreditDone(_m(amt), c.name));
}

/// A new person who already owes money: details, the amount owed now and the date the credit started.
Future<void> showAddCreditCustomer(BuildContext context) async {
  final l = tr(context);
  final container = ProviderScope.containerOf(context);
  final v = await showFormSheet(context, title: l.addCreditCustomerTitle, saveLabel: l.save, note: l.creditStartHelp, fields: [
    FieldSpec('name', l.fieldName, required: true, autofocus: true),
    FieldSpec('phone', l.fieldPhone, type: FieldType.phone, hint: '98765 43210', required: true, check: (x) => normalizePhone(x) == null ? l.errPhone : null),
    FieldSpec('city', l.fieldCity),
    FieldSpec('address', l.fieldAddress),
    FieldSpec('gstin', l.fieldGstinOptional, kind: TextKind.gstin),
    FieldSpec('limit', l.creditLimitField, type: FieldType.money, initial: '50000.00'),
    FieldSpec('amount', l.openingBalance, type: FieldType.money, required: true),
    FieldSpec('date', l.creditStartDate, type: FieldType.date, initial: formatDate(container.read(clockProvider))),
  ]);
  if (v == null || !context.mounted) return;
  final amt = parseRupeesToPaise(v['amount'] ?? '') ?? 0;
  if (amt <= 0) return;
  final limit = parseRupeesToPaise(v['limit'] ?? '') ?? 5000000;
  final id = newId();
  final c = Customer(id: id, name: v['name']!, phone: v['phone'] ?? '', city: v['city'] ?? '', address: v['address'] ?? '', gstin: v['gstin'] ?? '', balancePaise: 0, creditLimitPaise: limit);
  container.read(customersProvider.notifier).add(c);
  await container.read(creditProvider.notifier).addOpening(customerId: id, amount: amt, at: parseDmy(v['date'] ?? '') ?? container.read(clockProvider));
  if (context.mounted) toast(context, l.partyAdded(c.name, _m(amt)));
}

/// Edit a customer's or dealer's details.
/// The fields of a dealer, for adding and for editing. Only the shop or organization name and its phone must be filled in; every other detail
/// (GST number, bank account, contact person, collection agent and his phone, e-mail, notes) is optional.
List<FieldSpec> dealerFormFields(Strings l, {Rec? r}) {
  String v(String k) => r?.s(k) ?? '';
  return [
    FieldSpec('name', l.fieldDealerShop, initial: v('name'), required: true, autofocus: true),
    FieldSpec('phone', l.fieldPhone, type: FieldType.phone, initial: v('phone'), required: true),
    FieldSpec('gstin', l.fieldGstinOptional, initial: v('gstin'), kind: TextKind.gstin),
    FieldSpec('contact', l.fieldContact, initial: v('contact')),
    FieldSpec('agentName', l.fieldAgentName, initial: v('agentName')),
    FieldSpec('agentPhone', l.fieldAgentPhone, type: FieldType.phone, initial: v('agentPhone')),
    FieldSpec('account', l.fieldAccountNo, initial: v('account')),
    FieldSpec('bank', l.fieldBank, initial: v('bank')),
    FieldSpec('ifsc', l.fieldIfsc, initial: v('ifsc')),
    FieldSpec('email', l.fieldEmail, type: FieldType.email, initial: v('email')),
    FieldSpec('city', l.fieldCity, initial: v('city')),
    FieldSpec('address', l.fieldAddress, initial: v('address')),
    FieldSpec('notes', l.fieldNote, type: FieldType.multiline, initial: v('notes')),
  ];
}

/// The record map of a dealer from what the form returned.
Map<String, Object> dealerFromForm(Map<String, String> v) => {for (final k in dealerFormKeys) k: (v[k] ?? '').trim()};

const dealerFormKeys = ['name', 'phone', 'gstin', 'contact', 'agentName', 'agentPhone', 'account', 'bank', 'ifsc', 'email', 'city', 'address', 'notes'];

Future<void> showEditParty(BuildContext context, PartyRef party) async {
  final l = tr(context);
  final container = ProviderScope.containerOf(context);
  if (party.kind == PartyKind.customer) {
    final c = container.read(customersProvider).firstWhere((x) => x.id == party.id);
    final v = await showFormSheet(context, title: l.editParty, saveLabel: l.save, fields: [
      FieldSpec('name', l.fieldName, initial: c.name, required: true, autofocus: true),
      FieldSpec('phone', l.fieldPhone, type: FieldType.phone, initial: c.phone, check: (x) => normalizePhone(x) == null ? l.errPhone : null),
      FieldSpec('city', l.fieldCity, initial: c.city),
      FieldSpec('address', l.fieldAddress, initial: c.address),
      FieldSpec('gstin', l.fieldGstinOptional, initial: c.gstin, kind: TextKind.gstin),
      FieldSpec('limit', l.creditLimitField, type: FieldType.money, initial: (c.creditLimitPaise / 100).toStringAsFixed(2)),
    ]);
    if (v == null || !context.mounted) return;
    container.read(customersProvider.notifier).update(c.copyWith(name: v['name'], phone: v['phone'], city: v['city'], address: v['address'], gstin: v['gstin'], creditLimitPaise: parseRupeesToPaise(v['limit'] ?? '') ?? c.creditLimitPaise));
  } else {
    final r = container.read(recsProvider('dealers')).firstWhere((x) => x.id == party.id);
    final v = await showFormSheet(context, title: l.editParty, saveLabel: l.save, fields: dealerFormFields(l, r: r));
    if (v == null || !context.mounted) return;
    container.read(recsProvider('dealers').notifier).replace(r.with_(dealerFromForm(v)));
  }
  if (context.mounted) toast(context, l.partyEdited);
}

/// A wrong entry is cancelled by a new entry; the wrong one stays visible. A reason is required.
Future<void> showReverseEntry(BuildContext context, PartyRef party, LedgerEntry e) async {
  final l = tr(context);
  final container = ProviderScope.containerOf(context);
  final v = await showFormSheet(context, title: l.reverseTitle, saveLabel: l.reverse, note: l.reverseText, fields: [
    FieldSpec('reason', l.reverseReason, required: true, autofocus: true),
  ]);
  if (v == null || !context.mounted) return;
  final at = container.read(clockProvider);
  await container.read(party.kind == PartyKind.customer ? creditProvider.notifier : dealerLedgerProvider.notifier).reverseEntry(partyId: party.id, entryId: e.id, reason: v['reason']!, at: at);
  if (context.mounted) toast(context, l.reverseDone);
}

/// Dealers: a correction by hand (freight, discount...). Plus = we owe more, minus = we owe less.
Future<void> showAddAdjustment(BuildContext context, PartyRef party) async {
  final l = tr(context);
  final container = ProviderScope.containerOf(context);
  final v = await showFormSheet(context, title: l.addAdjustmentTitle(party.name), saveLabel: l.save, note: l.addAdjustmentHelp, fields: [
    FieldSpec('dir', l.adjDirection, type: FieldType.dropdown, options: [('more', l.adjMore), ('less', l.adjLess)], initial: 'more'),
    FieldSpec('amount', l.fieldAmount, type: FieldType.money, required: true, autofocus: true),
    FieldSpec('date', l.fieldDate, type: FieldType.date, initial: formatDate(container.read(clockProvider))),
    FieldSpec('reason', l.fieldReason, required: true),
  ]);
  if (v == null || !context.mounted) return;
  final amt = parseRupeesToPaise(v['amount'] ?? '') ?? 0;
  if (amt <= 0) return;
  await container.read(dealerLedgerProvider.notifier).addAdjustment(partyId: party.id, signedPaise: v['dir'] == 'less' ? -amt : amt, at: parseDmy(v['date'] ?? '') ?? container.read(clockProvider), reason: v['reason']!);
  if (context.mounted) toast(context, l.adjDone(_m(amt)));
}
