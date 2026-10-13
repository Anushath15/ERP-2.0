import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/file_saver.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/ledger.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/credit_store.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import 'credit_dialogs.dart';
import 'credit_screens.dart' show remindedText;
import 'party_dialogs.dart';
import 'statement_pdf.dart';

/// The profile of a customer (who owes us) or a dealer (whom we owe): details, key dates, bill-wise dues with ageing, the full
/// ledger with a running balance (filter by date), and the actions. Nothing is deleted: a wrong entry is reversed by a new entry.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.partyId, required this.kind});
  final String partyId;
  final PartyKind kind;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _range = 2; // 0 this month, 1 last 3 months, 2 whole history, 3 picked dates
  DateTimeRange? _picked;

  bool get _customer => widget.kind == PartyKind.customer;

  /// The ledger window the person chose: (from, to), null = no limit.
  (DateTime, DateTime)? _window(DateTime now) => switch (_range) {
        0 => (DateTime(now.year, now.month, 1), now),
        1 => (DateTime(now.year, now.month - 2, 1), now),
        3 when _picked != null => (_picked!.start, _picked!.end),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final now = ref.watch(clockProvider);
    final settings = ref.watch(settingsProvider);
    final customers = ref.watch(customersProvider);
    final dealers = ref.watch(recsProvider('dealers'));

    final Customer? cust = _customer ? customers.where((x) => x.id == widget.partyId).firstOrNull : null;
    final Rec? deal = _customer ? null : dealers.where((x) => x.id == widget.partyId).firstOrNull;
    if (cust == null && deal == null) {
      return PageFrame(title: _customer ? l.navCustomers : l.navDealers, child: EmptyState(icon: Icons.person_off_outlined, title: _customer ? l.nothingFound : l.dealerGone, action: FilledButton(onPressed: () => context.go(_customer ? '/customers' : '/dealers'), child: Text(l.back))));
    }
    final name = cust?.name ?? deal!.s('name');
    final phone = cust?.phone ?? deal!.s('phone');
    final city = cust?.city ?? deal!.s('city');
    final address = cust?.address ?? deal!.s('address');
    final party = PartyRef(widget.partyId, name, widget.kind);

    final acct = watchBook(ref, widget.kind)[widget.partyId] ?? const CreditAccount();
    final log = _customer ? ref.watch(reminderLogProvider) : null;
    final bal = acct.balance;
    final unpaid = unpaidBills(acct.bills);
    final age = ageing(acct.bills, now);
    final overdue = overdueAmount(acct.bills, now);
    final reminders = log?.forCustomer(widget.partyId) ?? const <ReminderRecord>[];
    final gone = reversedIds(acct.ledger);
    final win = _window(now);
    final all = withRunningBalance(acct.ledger);
    final shown = [
      for (final ln in all)
        if (win == null || (!ln.entry.at.isBefore(DateTime(win.$1.year, win.$1.month, win.$1.day)) && ln.entry.at.isBefore(DateTime(win.$2.year, win.$2.month, win.$2.day).add(const Duration(days: 1))))) ln
    ].reversed.toList();
    String amountOn(LedgerEntry? e) => e == null ? l.profNone : l.amountOnDate(formatPaise(e.amountPaise.abs(), symbol: true), formatDate(e.at));
    final due = acct.nextDue();
    final isOverdue = due != null && due.isBefore(DateTime(now.year, now.month, now.day));
    final first = acct.ledger.isEmpty ? null : (acct.ledger.map((e) => e.at).reduce((a, b) => a.isBefore(b) ? a : b));
    final limit = cust?.creditLimitPaise ?? 0;
    final usedPct = limit == 0 ? 0 : (bal > 0 ? (bal * 100 ~/ limit) : 0);

    Widget stat(String label, String value, IconData icon, {Color? tone, String? hint}) => StatCard(label: label, value: value, icon: icon, tone: tone, hint: hint);

    final stats = LayoutBuilder(builder: (ctx, bc) {
      final cols = (bc.maxWidth / ctx.textFactor) > 900 ? 3 : ((bc.maxWidth / ctx.textFactor) > 520 ? 2 : 1);
      final w = ((bc.maxWidth - (cols - 1) * 12) / cols).floorToDouble();
      final cards = <Widget>[
        if (_customer) stat(bal < 0 ? l.custAdvance : l.custBalance, '₹ ${formatPaise(bal.abs())}', bal < 0 ? Icons.savings_outlined : Icons.south_west, tone: bal < 0 ? c.success : (bal > 0 ? c.warning : null))
        else stat(bal < 0 ? l.profAdvanceWith : l.profWeOweBalance, '₹ ${formatPaise(bal.abs())}', bal < 0 ? Icons.savings_outlined : Icons.north_east, tone: bal < 0 ? c.success : (bal > 0 ? c.danger : null)),
        stat(l.statOverdue, '₹ ${formatPaise(overdue)}', Icons.schedule, tone: overdue > 0 ? c.danger : null),
        if (_customer) stat(l.profCreditStart, acct.creditStart == null ? l.profNothingDue : formatDate(acct.creditStart!), Icons.flag_outlined) else stat(l.profAccountStarted, first == null ? l.profNone : formatDate(first), Icons.flag_outlined),
        stat(_customer ? l.profNextDue : l.profNextPay, due == null ? l.profNothingDue : (isOverdue ? l.profOverdueSince(formatDate(due)) : formatDate(due)), Icons.event_outlined, tone: isOverdue ? c.danger : null),
        stat(l.custLastPayment, amountOn(acct.lastPayment), Icons.payments_outlined),
        stat(_customer ? l.profLastCredit : l.profLastPurchase, amountOn(acct.lastCredit), Icons.add_card_outlined),
        if (_customer) stat(l.custLimit, '₹ ${formatPaise(limit)}', Icons.speed, tone: bal > limit ? c.danger : null, hint: l.limitUsed(usedPct.toString())),
        if (_customer) StatCard(label: l.custReminders, value: '${reminders.length}', icon: Icons.chat_outlined, hint: reminders.isEmpty ? l.notReminded : remindedText(l, reminders.length, reminders.first.at)),
      ];
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final k in cards) SizedBox(width: w, child: k)]);
    });

    final waNumber = phone.isEmpty ? l.custNoNumber : (normalizePhone(phone, defaultCountry: settings.countryCode) == null ? phone : prettyPhone(normalizePhone(phone, defaultCountry: settings.countryCode)!));
    final details = SectionCard(
      title: l.profDetails,
      trailing: TextButton.icon(key: const ValueKey('editParty'), onPressed: () => showEditParty(context, party), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l.editParty)),
      child: Column(children: [
        KeyValue(l.fieldName, name),
        KeyValue(l.fieldPhone, phone.isEmpty ? l.custNoNumber : phone),
        if (_customer) KeyValue(l.custWhatsapp, waNumber),
        KeyValue(l.fieldCity, city.isEmpty ? '-' : city),
        KeyValue(l.fieldAddress, address.isEmpty ? '-' : address),
        if (_customer) KeyValue(l.custLimit, '₹ ${formatPaise(limit)}'),
      ]),
    );

    Future<void> downloadStatement() async {
      final w = win ?? (DateTime(2000), now);
      final st = buildStatement(entries: acct.ledger, from: w.$1, to: w.$2);
      final bytes = await buildStatementPdf(statement: st, customer: Customer(id: widget.partyId, name: name, phone: phone, city: city, balancePaise: 0), shopName: settings.shopName, shopPhone: settings.shopPhone, today: now, l: l, dealer: !_customer);
      final stamp = '${now.year}-${two(now.month)}-${two(now.day)}';
      final where = await ref.read(fileSaverProvider).save('Statement $name $stamp.pdf', bytes);
      if (mounted) toast(context, where == null ? l.pdfFailed : l.pdfSaved(where));
    }

    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      if (bal > 0) FilledButton.icon(key: const ValueKey('settleFully'), onPressed: () => showSettleFully(context, party), icon: const Icon(Icons.done_all), label: Text(l.settleFully)),
      OutlinedButton.icon(
        key: const ValueKey('receiveOrPay'),
        onPressed: () async {
          final rec = await showPartyPayment(context, party);
          if (rec != null && context.mounted) {
            toastAction(context, _customer ? l.recvDone(formatPaise(rec.amountPaise, symbol: true), name) : l.payDealerDone(formatPaise(rec.amountPaise, symbol: true), name), l.printReceipt, () => openReceiptPreview(context, ref, rec), seconds: 6);
          }
        },
        icon: const Icon(Icons.payments_outlined),
        label: Text(_customer ? l.receivePayment : l.payDealer),
      ),
      if (_customer) OutlinedButton.icon(key: const ValueKey('addCredit'), onPressed: () => showAddCredit(context, cust!), icon: const Icon(Icons.add_card_outlined), label: Text(l.addCredit)) else OutlinedButton.icon(key: const ValueKey('addAdjustment'), onPressed: () => showAddAdjustment(context, party), icon: const Icon(Icons.tune), label: Text(l.addAccountAdjustment)),
      if (_customer) Tooltip(message: settings.sync == SyncState.offline ? canOpenWhatsapp(online: false, digits: null).reason! : l.remindersTooltip, child: OutlinedButton.icon(onPressed: bal > 0 ? () => remindCustomer(context, cust!) : null, icon: const Icon(Icons.chat_outlined), label: Text(l.actRemind))),
      if (_customer) OutlinedButton.icon(onPressed: () => context.go('/customers/${widget.partyId}/statement'), icon: const Icon(Icons.description_outlined), label: Text(l.actStatement)),
      OutlinedButton.icon(key: const ValueKey('downloadStatement'), onPressed: downloadStatement, icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(l.downloadStatement)),
      if (_customer && bal > 0) OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: c.danger), onPressed: () => showWriteOff(context, ref, cust!), icon: const Icon(Icons.remove_circle_outline), label: Text(l.writeOff)),
    ]);

    final ageChips = Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in [(l.age0, age.d0to30, BadgeKind.success), (l.age31, age.d31to60, BadgeKind.info), (l.age61, age.d61to90, BadgeKind.warning), (l.age90, age.d90plus, BadgeKind.danger)]) StatusBadge('${e.$1}: ${formatPaise(e.$2, symbol: true)}', kind: e.$2 == 0 ? BadgeKind.neutral : e.$3),
    ]);

    final billsCard = SectionCard(
      title: _customer ? l.sectionBillWise : l.dealerBillsTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ageChips,
        const SizedBox(height: 10),
        if (acct.unbilledBalance > 0)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(l.openingBalanceRow, style: th.bodyMedium)), Text(formatPaise(acct.unbilledBalance, symbol: true), style: th.titleSmall)])),
        if (unpaid.isEmpty && acct.unbilledBalance <= 0) Text(_customer ? l.nobodyOwes : l.dealerNobodyDue, style: th.bodyMedium),
        for (final b in unpaid)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${b.billNo}  ·  ${formatDate(b.date)}', style: th.titleSmall), Text(l.billPaidOf(formatPaise(b.paidPaise, symbol: true), formatPaise(b.totalPaise, symbol: true)), style: th.bodySmall)])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(formatPaise(b.outstanding, symbol: true), style: th.titleSmall?.copyWith(color: c.warning)), Text(l.daysCount(daysOld(b.date, now).toString()), style: th.bodySmall)]),
            ]),
          ),
      ]),
    );

    final phoneLayout = context.isPhone;
    Widget rangeChips() => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in [(0, l.stRangeMonth), (1, l.stRange3), (2, l.stRangeAll)])
            ChoiceChip(key: ValueKey('range${e.$1}'), label: Text(e.$2), selected: _range == e.$1, onSelected: (_) => setState(() => _range = e.$1)),
          ChoiceChip(
            key: const ValueKey('range3'),
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_range == 3 && _picked != null ? '${formatDate(_picked!.start)} - ${formatDate(_picked!.end)}' : l.rangePick),
            selected: _range == 3,
            onSelected: (_) async {
              final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 15), lastDate: DateTime(now.year + 1), initialDateRange: _picked ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
              if (r != null) setState(() {
                    _picked = r;
                    _range = 3;
                  });
            },
          ),
        ]);

    Widget reverseButton(LedgerEntry e) => gone.contains(e.id)
        ? StatusBadge(l.reversedBadge, kind: BadgeKind.neutral)
        : (isReversible(e) ? IconButton(key: ValueKey('reverse-${e.id}'), tooltip: l.reverse, visualDensity: VisualDensity.compact, onPressed: () => showReverseEntry(context, party, e), icon: const Icon(Icons.undo, size: 18)) : const SizedBox(width: 40));
    String kindText(LedgerEntry e) => '${ledgerKindLabel(l, e.kind, dealer: !_customer)}${e.billNo == null ? '' : '  ·  ${e.billNo}'}';

    final ledgerCard = SectionCard(
      title: _customer ? l.sectionLedger : l.dealerLedgerTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        rangeChips(),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_customer ? l.creditNoAccount : l.dealerNoAccount, style: th.bodyMedium))
        else ...[
          if (!phoneLayout)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
              SizedBox(width: 92, child: Text(l.colDate, style: th.labelMedium?.copyWith(color: c.textMuted))),
              Expanded(flex: 3, child: Text(l.colType, style: th.labelMedium?.copyWith(color: c.textMuted))),
              SizedBox(width: 96, child: Text(l.colCharged, textAlign: TextAlign.right, style: th.labelMedium?.copyWith(color: c.textMuted))),
              SizedBox(width: 110, child: Text(l.colCredited, textAlign: TextAlign.right, style: th.labelMedium?.copyWith(color: c.textMuted))),
              SizedBox(width: 110, child: Text(l.colRunning, textAlign: TextAlign.right, style: th.labelMedium?.copyWith(color: c.textMuted))),
              const SizedBox(width: 44),
            ])),
          for (final ln in shown) ...[
            const Divider(),
            Padding(
              key: ValueKey('ledgerRow-${ln.entry.id}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: phoneLayout
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(kindText(ln.entry), style: th.titleSmall?.copyWith(decoration: gone.contains(ln.entry.id) ? TextDecoration.lineThrough : null))), Text(formatPaise(ln.entry.amountPaise.abs(), symbol: true), style: th.titleSmall?.copyWith(color: ln.entry.amountPaise > 0 ? c.warning : c.success)), reverseButton(ln.entry)]),
                      Text('${formatDate(ln.entry.at)}  ·  ${l.colRunning}: ${formatPaise(ln.runningPaise, symbol: true)}${ln.entry.note.isEmpty ? '' : '\n${ln.entry.note}'}', style: th.bodySmall),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 92, child: Text(formatDate(ln.entry.at), style: th.bodyMedium)),
                      Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(kindText(ln.entry), style: th.titleSmall?.copyWith(decoration: gone.contains(ln.entry.id) ? TextDecoration.lineThrough : null)), if (ln.entry.note.isNotEmpty) Text(ln.entry.note, style: th.bodySmall)])),
                      SizedBox(width: 96, child: Text(ln.entry.amountPaise > 0 ? formatPaise(ln.entry.amountPaise) : '', textAlign: TextAlign.right, style: th.bodyMedium?.copyWith(color: c.warning))),
                      SizedBox(width: 110, child: Text(ln.entry.amountPaise < 0 ? formatPaise(-ln.entry.amountPaise) : '', textAlign: TextAlign.right, style: th.bodyMedium?.copyWith(color: c.success))),
                      SizedBox(width: 110, child: Text(formatPaise(ln.runningPaise), textAlign: TextAlign.right, style: th.titleSmall)),
                      SizedBox(width: 44, child: Align(alignment: Alignment.centerRight, child: reverseButton(ln.entry))),
                    ]),
            ),
          ],
        ],
      ]),
    );

    final remindersCard = !_customer
        ? null
        : SectionCard(
            title: l.sectionReminders,
            trailing: Tooltip(message: l.remindersTooltip, child: const Icon(Icons.info_outline, size: 20)),
            child: reminders.isEmpty
                ? Text(l.noRemindersYet, style: th.bodyMedium)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final r in reminders)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [const Icon(Icons.chat_outlined, size: 18), const SizedBox(width: 8), Expanded(child: Text(l.reminderLine('${formatDate(r.at)} ${formatTime(r.at)}', formatPaise(r.amountDuePaise, symbol: true)), style: th.bodyMedium)), Text(r.by, style: th.bodySmall)]),
                      ),
                  ]),
          );

    return PageFrame(
      title: name,
      subtitle: '${phone.isEmpty ? l.custNoNumber : phone}  ·  $city',
      actions: [TextButton.icon(onPressed: () => context.go(_customer ? '/customers' : '/dealers'), icon: const Icon(Icons.arrow_back), label: Text(_customer ? l.navCustomers : l.navDealers))],
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        stats,
        const SizedBox(height: 12),
        actions,
        const SizedBox(height: 12),
        details,
        const SizedBox(height: 12),
        billsCard,
        const SizedBox(height: 12),
        ledgerCard,
        if (remindersCard != null) ...[const SizedBox(height: 12), remindersCard],
      ]),
    );
  }
}
