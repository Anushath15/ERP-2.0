import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/file_saver.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../data/repo/bill_repo.dart' show BillRow;
import '../../data/repo/report_repo.dart' show CustomerSummary;
import '../../design/open_once.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/ledger.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/actions.dart' show returnsVersionProvider;
import '../../fake/credit_store.dart';
import '../../fake/data_providers.dart';
import '../../fake/stats.dart';
import '../../domain/orders.dart';
import '../purchases/purchase_screens.dart' show dealerPurchasesProvider, dealerSummaryProvider, showPurchasePopup;
import '../sales/sales_screens.dart' show showBillPopup, showEstimatePopup, estimateStatusBadge, statusInfo, billStatus;
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../../fake/shop_profile.dart';
import 'credit_dialogs.dart';
import 'credit_screens.dart' show remindedText;
import 'party_dialogs.dart';
import 'statement_pdf.dart';
import 'statement_share.dart';

/// The profile of a customer (who owes us) or a dealer (whom we owe): details, key dates, bill-wise dues with ageing, the full
/// ledger with a running balance (filter by date), and the actions. Nothing is deleted: a wrong entry is reversed by a new entry.
/// What one customer has bought and what the shop made on it (read again whenever a bill or a return is saved).
final customerSummaryProvider = FutureProvider.autoDispose.family<CustomerSummary, String>((ref, id) {
  ref.watch(statsProvider);
  ref.watch(returnsVersionProvider);
  return ref.read(appDataProvider).reports.customerSummary(id);
});

/// The customer's newest bills.
const customerBillsShown = 200;
/// A customer's estimates (refreshed whenever an estimate is saved, changed, made into a bill or deleted).
final customerEstimatesProvider = FutureProvider.autoDispose.family<List<EstimationDoc>, String>((ref, id) {
  ref.watch(estimationsProvider);
  final name = ref.watch(customersProvider).where((c) => c.id == id).firstOrNull?.name ?? '';
  return ref.read(appDataProvider).estimations.forCustomer(id, name, limit: customerBillsShown);
});

final customerBillsProvider = FutureProvider.autoDispose.family<List<BillRow>, String>((ref, id) {
  ref.watch(statsProvider);
  ref.watch(returnsVersionProvider);
  return ref.read(appDataProvider).bills.page(customerId: id, limit: customerBillsShown);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.partyId, required this.kind, this.openBillId, this.openEstimate, this.accountView = false});
  final String partyId;
  final PartyKind kind;

  /// A customer's account status page (balance, bills still to pay, ledger, reminders, statement) instead of their profile.
  final bool accountView;

  /// Opens this bill's popup at once (the Back button of the print page returns here).
  final String? openBillId;

  /// Opens this estimate's popup at once (the Back button of the print page returns here).
  final String? openEstimate;
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
    final shop = ref.watch(shopProvider);
    final customers = ref.watch(customersProvider);
    final dealers = ref.watch(recsProvider('dealers'));

    final Customer? cust = _customer ? customers.where((x) => x.id == widget.partyId).firstOrNull : null;
    final Rec? deal = _customer ? null : dealers.where((x) => x.id == widget.partyId).firstOrNull;
    if (cust == null && deal == null) {
      return PageFrame(title: _customer ? l.navCustomers : l.navDealers, child: EmptyState(icon: Icons.person_off_rounded, title: _customer ? l.nothingFound : l.dealerGone, action: FilledButton(onPressed: () => context.go(_customer ? '/customers' : '/dealers'), child: Text(l.back))));
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

    // a customer who never had credit or a debit has no account to show: only what they bought
    final hasAccount = acct.ledger.isNotEmpty;

    Widget stat(String label, String value, IconData icon, {Color? tone, String? hint}) => StatCard(label: label, value: value, icon: icon, tone: tone, hint: hint);

    final stats = LayoutBuilder(builder: (ctx, bc) {
      final cols = (bc.maxWidth / ctx.textFactor) > 900 ? 3 : ((bc.maxWidth / ctx.textFactor) > 520 ? 2 : 1);
      final w = ((bc.maxWidth - (cols - 1) * 12) / cols).floorToDouble();
      final cards = <Widget>[
        if (_customer) stat(bal < 0 ? l.custAdvance : l.custBalance, '₹ ${formatPaise(bal.abs())}', bal < 0 ? Icons.savings_rounded : Icons.south_west_rounded, tone: bal < 0 ? c.success : (bal > 0 ? c.warning : null))
        else stat(bal < 0 ? l.profAdvanceWith : l.profWeOweBalance, '₹ ${formatPaise(bal.abs())}', bal < 0 ? Icons.savings_rounded : Icons.north_east_rounded, tone: bal < 0 ? c.success : (bal > 0 ? c.danger : null)),
        stat(l.statOverdue, '₹ ${formatPaise(overdue)}', Icons.schedule_rounded, tone: overdue > 0 ? c.danger : null),
        if (_customer) stat(l.profCreditStart, acct.creditStart == null ? l.profNothingDue : formatDate(acct.creditStart!), Icons.flag_rounded) else stat(l.profAccountStarted, first == null ? l.profNone : formatDate(first), Icons.flag_rounded),
        stat(_customer ? l.profNextDue : l.profNextPay, due == null ? l.profNothingDue : (isOverdue ? l.profOverdueSince(formatDate(due)) : formatDate(due)), Icons.event_rounded, tone: isOverdue ? c.danger : null),
        stat(l.custLastPayment, amountOn(acct.lastPayment), Icons.payments_rounded),
        stat(_customer ? l.profLastCredit : l.profLastPurchase, amountOn(acct.lastCredit), Icons.add_card_rounded),
        if (_customer) stat(l.custLimit, '₹ ${formatPaise(limit)}', Icons.speed_rounded, tone: bal > limit ? c.danger : null, hint: l.limitUsed(usedPct.toString())),
        if (_customer) StatCard(label: l.custReminders, value: '${reminders.length}', icon: Icons.chat_rounded, hint: reminders.isEmpty ? l.notReminded : remindedText(l, reminders.length, reminders.first.at)),
      ];
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final k in cards) SizedBox(width: w, child: k)]);
    });

    final waNumber = phone.isEmpty ? l.custNoNumber : (normalizePhone(phone, defaultCountry: shop.countryCode) == null ? phone : prettyPhone(normalizePhone(phone, defaultCountry: shop.countryCode)!));
    final details = SectionCard(
      title: l.profDetails,
      trailing: TextButton.icon(key: const ValueKey('editParty'), onPressed: () => showEditParty(context, party), icon: const Icon(Icons.edit_rounded, size: 18), label: Text(l.editParty)),
      child: Column(children: [
        KeyValue(_customer ? l.fieldName : l.fieldDealerShop, name),
        KeyValue(l.fieldPhone, phone.isEmpty ? l.custNoNumber : phone),
        if (!_customer)
          for (final e in [(l.fieldGstinOptional, 'gstin'), (l.fieldContact, 'contact'), (l.fieldAgentName, 'agentName'), (l.fieldAgentPhone, 'agentPhone'), (l.fieldAccountNo, 'account'), (l.fieldBank, 'bank'), (l.fieldIfsc, 'ifsc'), (l.fieldEmail, 'email')])
            KeyValue(e.$1, deal!.s(e.$2).isEmpty ? '-' : deal.s(e.$2)),
        if (_customer) KeyValue(l.custWhatsapp, waNumber),
        KeyValue(l.fieldCity, city.isEmpty ? '-' : city),
        KeyValue(l.fieldAddress, address.isEmpty ? '-' : address),
        if (!_customer && deal!.s('notes').isNotEmpty) KeyValue(l.fieldNote, deal.s('notes')),
        if (_customer) KeyValue(l.custLimit, '₹ ${formatPaise(limit)}'),
      ]),
    );

    Future<void> downloadStatement() async {
      final w = win ?? (DateTime(2000), now);
      final st = buildStatement(entries: acct.ledger, from: w.$1, to: w.$2);
      final bytes = await buildStatementPdf(statement: st, customer: Customer(id: widget.partyId, name: name, phone: phone, city: city, balancePaise: 0), shopName: shop.name, shopPhone: shop.phone, today: now, l: l, dealer: !_customer, shop: shop);
      final stamp = '${now.year}-${two(now.month)}-${two(now.day)}';
      final where = await ref.read(fileSaverProvider).save('Statement $name $stamp.pdf', bytes);
      if (context.mounted) toast(context, where == null ? l.pdfFailed : l.pdfSaved(where));
    }

    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      if (hasAccount && bal > 0) FilledButton.icon(key: const ValueKey('settleFully'), onPressed: () => showSettleFully(context, party), icon: const Icon(Icons.done_all_rounded), label: Text(l.settleFully)),
      if (hasAccount)
        OutlinedButton.icon(
        key: const ValueKey('receiveOrPay'),
        onPressed: () async {
          final rec = await showPartyPayment(context, party);
          if (rec != null && context.mounted) {
            toastAction(context, _customer ? l.recvDone(formatPaise(rec.amountPaise, symbol: true), name) : l.payDealerDone(formatPaise(rec.amountPaise, symbol: true), name), l.printReceipt, () => openReceiptPreview(context, ref, rec), seconds: 6);
          }
        },
        icon: const Icon(Icons.payments_rounded),
        label: Text(_customer ? l.receivePayment : l.payDealer),
      ),
      if (_customer) OutlinedButton.icon(key: const ValueKey('addCredit'), onPressed: () => showAddCredit(context, cust!), icon: const Icon(Icons.add_card_rounded), label: Text(l.addCredit)) else OutlinedButton.icon(key: const ValueKey('addAdjustment'), onPressed: () => showAddAdjustment(context, party), icon: const Icon(Icons.tune_rounded), label: Text(l.addAccountAdjustment)),
      if (_customer && hasAccount) Tooltip(message: settings.sync == SyncState.offline ? canOpenWhatsapp(online: false, digits: null).reason! : l.remindersTooltip, child: OutlinedButton.icon(onPressed: bal > 0 ? () => remindCustomer(context, cust!) : null, icon: const Icon(Icons.chat_rounded), label: Text(l.actRemind))),
      if (_customer && hasAccount) OutlinedButton.icon(onPressed: () => context.go('/customers/${widget.partyId}/statement'), icon: const Icon(Icons.description_rounded), label: Text(l.actStatement)),
      if (hasAccount) OutlinedButton.icon(key: const ValueKey('downloadStatement'), onPressed: downloadStatement, icon: const Icon(Icons.picture_as_pdf_rounded), label: Text(l.downloadStatement)),
      if (_customer && hasAccount)
        OutlinedButton.icon(
          key: const ValueKey('profileStatementWhatsapp'),
          onPressed: () => shareStatementOnWhatsapp(context, ref, statement: buildStatement(entries: acct.ledger, from: (win ?? (DateTime(2000), now)).$1, to: (win ?? (DateTime(2000), now)).$2), customer: Customer(id: widget.partyId, name: name, phone: phone, city: city, balancePaise: 0), now: now),
          icon: const Icon(Icons.chat_rounded),
          label: Text(l.waStatementShare),
        ),
      if (_customer && bal > 0) OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: c.danger), onPressed: () => showWriteOff(context, ref, cust!), icon: const Icon(Icons.remove_circle_outline_rounded), label: Text(l.writeOff)),
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

    final summary = _customer ? ref.watch(customerSummaryProvider(widget.partyId)).asData?.value : null;
    final purchaseStats = summary == null
        ? null
        : Builder(builder: (ctx) {
            final cards = <Widget>[
              StatCard(key: const ValueKey('cust-bought'), label: l.custBought, value: '₹ ${formatPaise(summary.boughtPaise)}', icon: Icons.shopping_bag_rounded, tone: c.success, hint: l.custBoughtHint),
              StatCard(key: const ValueKey('cust-bills'), label: l.custBillsCount, value: '${summary.bills}', icon: Icons.receipt_long_rounded, hint: summary.cancelledBills > 0 ? l.custBillsCancelledHint('${summary.cancelledBills}') : null),
              StatCard(key: const ValueKey('cust-profit'), label: l.custProfit, value: '₹ ${formatPaise(summary.profitPaise)}', icon: Icons.savings_rounded, tone: summary.profitPaise < 0 ? c.danger : c.success, hint: l.profitEstimate),
              StatCard(key: const ValueKey('cust-last-bill'), label: l.custLastBill, value: summary.lastBillAt == null ? l.profNone : formatDate(summary.lastBillAt!), icon: Icons.event_rounded),
              if (summary.returns > 0) StatCard(key: const ValueKey('cust-returned'), label: l.custReturnedLabel, value: '₹ ${formatPaise(summary.returnedPaise)}', icon: Icons.assignment_return_rounded, tone: c.warning, hint: l.custReturnedHint('${summary.returns}')),
            ];
            return StatGrid(cards: cards);
          });

    final bills = _customer ? ref.watch(customerBillsProvider(widget.partyId)).asData?.value : null;
    final billsList = bills == null
        ? null
        : SectionCard(
            title: l.custBillsTitle,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (bills.isEmpty) Text(l.custNoBills, key: const ValueKey('cust-no-bills'), style: th.bodyMedium),
              for (final b in bills) ...[
                InkWell(
                  key: ValueKey('cust-bill-${b.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showBillPopup(context, ref, b, backTo: '/customers/${widget.partyId}?openBill=${Uri.encodeQueryComponent(b.id)}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.number, style: th.titleSmall?.copyWith(decoration: b.cancelled ? TextDecoration.lineThrough : null)),
                          Text('${formatDateTime(b.at)}  ·  ${l.itemsCount('${b.items}')}', style: th.bodySmall),
                        ]),
                      ),
                      StatusBadge(statusInfo(billStatus(b), l).$1, kind: statusInfo(billStatus(b), l).$2),
                      const SizedBox(width: 12),
                      SizedBox(width: 110, child: Text('₹ ${formatPaise(b.totalPaise)}', textAlign: TextAlign.right, style: th.titleSmall)),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ]),
                  ),
                ),
                if (b != bills.last) const Divider(height: 1),
              ],
              if (bills.length >= customerBillsShown) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.custBillsCapped('$customerBillsShown'), style: th.bodySmall)),
            ]),
          );

    // a customer's estimates, like their bills (a click opens the estimate: print, PDF, WhatsApp, edit, make into a bill)
    final estimates = _customer ? ref.watch(customerEstimatesProvider(widget.partyId)).asData?.value : null;
    final estimatesList = estimates == null
        ? null
        : SectionCard(
            key: const ValueKey('cust-estimates'),
            title: l.custEstimatesTitle,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (estimates.isEmpty) Text(l.custNoEstimates, key: const ValueKey('cust-no-estimates'), style: th.bodyMedium),
              for (final e in estimates) ...[
                InkWell(
                  key: ValueKey('cust-est-${e.number}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showEstimatePopup(context, ref, e, backTo: '/customers/${widget.partyId}?openEstimate=${Uri.encodeQueryComponent(e.number)}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.number, style: th.titleSmall),
                          Text('${formatDate(e.date)}  ·  ${l.itemsCount('${e.lines}')}', style: th.bodySmall),
                        ]),
                      ),
                      estimateStatusBadge(e, l),
                      const SizedBox(width: 12),
                      SizedBox(width: 110, child: Text('₹ ${formatPaise(e.totalPaise)}', textAlign: TextAlign.right, style: th.titleSmall)),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ]),
                  ),
                ),
                if (e != estimates.last) const Divider(height: 1),
              ],
              if (estimates.length >= customerBillsShown) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.custEstimatesCapped('$customerBillsShown'), style: th.bodySmall)),
            ]),
          );

    // a dealer: what was bought from them and their purchases (a click opens the purchase)
    final dsum = !_customer ? ref.watch(dealerSummaryProvider(widget.partyId)).asData?.value : null;
    final dealerStats = dsum == null
        ? null
        : Builder(builder: (ctx) {
            final cards = <Widget>[
              StatCard(key: const ValueKey('dealer-bought'), label: l.dealerBought, value: '₹ ${formatPaise(dsum.boughtPaise)}', icon: Icons.shopping_cart_checkout_rounded, tone: c.success, hint: l.dealerPaidHint(formatPaise(dsum.paidPaise, symbol: true))),
              StatCard(key: const ValueKey('dealer-purchases'), label: l.dealerPurchasesCount, value: '${dsum.purchases}', icon: Icons.receipt_long_rounded, hint: dsum.pending > 0 ? l.dealerPendingHint('${dsum.pending}') : null),
              StatCard(key: const ValueKey('dealer-last'), label: l.dealerLastPurchase, value: dsum.lastAt == null ? l.profNone : formatDate(dsum.lastAt!), icon: Icons.event_rounded),
            ];
            return StatGrid(cards: cards, wideColumns: 3);
          });
    final dpurchases = !_customer ? ref.watch(dealerPurchasesProvider(widget.partyId)).asData?.value : null;
    final purchasesList = dpurchases == null
        ? null
        : SectionCard(
            title: l.dealerPurchasesTitle,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (dpurchases.isEmpty) Text(l.dealerNoPurchases, key: const ValueKey('dealer-no-purchases'), style: th.bodyMedium),
              for (final p in dpurchases) ...[
                InkWell(
                  key: ValueKey('dealer-purchase-${p.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showPurchasePopup(context, ref, p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.number, style: th.titleSmall),
                          Text('${formatDate(p.at)}  ·  ${l.itemsCount('${p.items}')}${p.invoiceNo.isEmpty ? '' : '  ·  ${p.invoiceNo}'}', style: th.bodySmall),
                        ]),
                      ),
                      StatusBadge(p.received ? l.statusReceived : l.statusPending, kind: p.received ? BadgeKind.success : BadgeKind.warning),
                      const SizedBox(width: 12),
                      SizedBox(width: 110, child: Text('₹ ${formatPaise(p.totalPaise)}', textAlign: TextAlign.right, style: th.titleSmall)),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ]),
                  ),
                ),
                if (p != dpurchases.last) const Divider(height: 1),
              ],
            ]),
          );

    // the orders sent to this dealer (newest first): open one to send it again or make the purchase from it
    final dorders = _customer
        ? const <OrderDoc>[]
        : ([for (final r in ref.watch(recsProvider('orders'))) OrderDoc.fromRec(r)].where((o) => o.dealerId == widget.partyId && o.status != OrderStatus.cancelled).toList()..sort((a, b) => b.date.compareTo(a.date)));
    final ordersList = dorders.isEmpty
        ? null
        : SectionCard(
            key: const ValueKey('dealer-orders'),
            title: l.dealerOrdersTitle,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final o in dorders) ...[
                InkWell(
                  key: ValueKey('dealer-order-${o.number}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.go('/orders/${o.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.number, style: th.titleSmall),
                          Text('${formatDate(o.date)}  ·  ${l.itemsCount('${o.lines.length}')}${o.purchaseNo.isEmpty ? '' : '  ·  ${o.purchaseNo}'}', style: th.bodySmall),
                        ]),
                      ),
                      StatusBadge(
                        switch (o.status) { OrderStatus.open => l.orderStatusOpen, OrderStatus.sent => l.orderStatusSent, OrderStatus.converted => l.orderStatusDone, OrderStatus.cancelled => l.orderStatusCancelled },
                        kind: switch (o.status) { OrderStatus.open => BadgeKind.warning, OrderStatus.sent => BadgeKind.info, OrderStatus.converted => BadgeKind.success, OrderStatus.cancelled => BadgeKind.neutral },
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ]),
                  ),
                ),
                if (o != dorders.last) const Divider(height: 1),
              ],
            ]),
          );

    // on the profile: only how much they owe (or paid ahead) and a way into the account status page
    final accountPath = _customer ? '/customers/${widget.partyId}/account' : '/dealers/${widget.partyId}/account';
    final accountCard = !hasAccount
        ? null
        : SectionCard(
            key: const ValueKey('cust-account-card'),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push(accountPath),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Icon(bal < 0 ? Icons.savings_rounded : Icons.south_west_rounded, color: bal < 0 ? c.success : (bal > 0 ? c.warning : c.textMuted)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_customer ? (bal > 0 ? l.acctDebit : (bal < 0 ? l.acctAdvance : l.acctClean)) : (bal > 0 ? l.dealerAcctOwe : (bal < 0 ? l.dealerAcctAdvance : l.dealerAcctClean)), style: th.bodySmall),
                      Text(bal == 0 ? '₹ 0.00' : '₹ ${formatPaise(bal.abs())}', key: const ValueKey('cust-account-amount'), style: th.titleLarge?.copyWith(color: bal > 0 ? c.warning : (bal < 0 ? c.success : null))),
                    ]),
                  ),
                  FilledButton.icon(key: const ValueKey('cust-account-open'), onPressed: () => context.push(accountPath), icon: const Icon(Icons.account_balance_wallet_rounded), label: Text(l.acctStatusButton)),
                ]),
              ),
            ),
          );
    final profileActions = _customer
        ? (cust == null
            ? null
            : Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(key: const ValueKey('addCredit'), onPressed: () => showAddCredit(context, cust), icon: const Icon(Icons.add_card_rounded), label: Text(l.addCredit)),
              ]))
        : Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(key: const ValueKey('dealer-place-order'), onPressed: () => context.go('/orders/new?dealer=${Uri.encodeQueryComponent(widget.partyId)}'), icon: const Icon(Icons.chat_rounded), label: Text(l.orderPlace)),
            FilledButton.icon(key: const ValueKey('dealer-add-purchase'), onPressed: () => context.go('/purchases/new?dealer=${Uri.encodeQueryComponent(widget.partyId)}'), icon: const Icon(Icons.add_shopping_cart_rounded), label: Text(l.dealerAddPurchase)),
            OutlinedButton.icon(key: const ValueKey('addAdjustment'), onPressed: () => showAddAdjustment(context, party), icon: const Icon(Icons.tune_rounded), label: Text(l.addAccountAdjustment)),
          ]);

    final phoneLayout = context.isPhone;
    Widget rangeChips() => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in [(0, l.stRangeMonth), (1, l.stRange3), (2, l.stRangeAll)])
            ChoiceChip(key: ValueKey('range${e.$1}'), label: Text(e.$2), selected: _range == e.$1, onSelected: (_) => setState(() => _range = e.$1)),
          ChoiceChip(
            key: const ValueKey('range3'),
            avatar: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(_range == 3 && _picked != null ? '${formatDate(_picked!.start)} - ${formatDate(_picked!.end)}' : l.rangePick),
            selected: _range == 3,
            onSelected: (_) async {
              final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 15), lastDate: DateTime(now.year + 1), initialDateRange: _picked ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
              if (r != null && mounted) {
                setState(() {
                  _picked = r;
                  _range = 3;
                });
              }
            },
          ),
        ]);

    Widget reverseButton(LedgerEntry e) => gone.contains(e.id)
        ? StatusBadge(l.reversedBadge, kind: BadgeKind.neutral)
        : (isReversible(e) ? IconButton(key: ValueKey('reverse-${e.id}'), tooltip: l.reverse, visualDensity: VisualDensity.compact, onPressed: () => showReverseEntry(context, party, e), icon: const Icon(Icons.undo_rounded, size: 18)) : const SizedBox(width: 40));
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
            trailing: Tooltip(message: l.remindersTooltip, child: const Icon(Icons.info_outline_rounded, size: 20)),
            child: reminders.isEmpty
                ? Text(l.noRemindersYet, style: th.bodyMedium)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final r in reminders)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [const Icon(Icons.chat_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Text(l.reminderLine('${formatDate(r.at)} ${formatTime(r.at)}', formatPaise(r.amountDuePaise, symbol: true)), style: th.bodyMedium)), Text(r.by, style: th.bodySmall)]),
                      ),
                  ]),
          );

    final accountPage = widget.accountView;
    final content = ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      if (accountPage) ...[
        stats,
        const SizedBox(height: 12),
        actions,
        const SizedBox(height: 12),
        billsCard,
        const SizedBox(height: 12),
        ledgerCard,
        if (remindersCard != null) ...[const SizedBox(height: 12), remindersCard],
      ] else if (_customer) ...[
        if (purchaseStats != null) ...[purchaseStats, const SizedBox(height: 12)],
        if (billsList != null) ...[billsList, const SizedBox(height: 12)],
        if (estimatesList != null) ...[estimatesList, const SizedBox(height: 12)],
        if (profileActions != null) ...[profileActions, const SizedBox(height: 12)],
        details,
        if (accountCard != null) ...[const SizedBox(height: 12), accountCard],
      ] else ...[
        if (dealerStats != null) ...[dealerStats, const SizedBox(height: 12)],
        if (purchasesList != null) ...[purchasesList, const SizedBox(height: 12)],
        if (profileActions != null) ...[profileActions, const SizedBox(height: 12)],
        if (ordersList != null) ...[ordersList, const SizedBox(height: 12)],
        details,
        if (accountCard != null) ...[const SizedBox(height: 12), accountCard],
      ],
    ]);

    return PageFrame(
      title: name,
      subtitle: widget.accountView ? (_customer ? l.sectionLedger : l.dealerLedgerTitle) : '${phone.isEmpty ? l.custNoNumber : phone}  ·  $city',
      actions: [
        if (widget.accountView)
          TextButton.icon(key: const ValueKey('account-back'), onPressed: () => context.canPop() ? context.pop() : context.go(_customer ? '/customers/${widget.partyId}' : '/dealers/${widget.partyId}'), icon: const Icon(Icons.arrow_back_rounded), label: Text(_customer ? l.acctBack : l.acctBackDealer))
        else
          TextButton.icon(onPressed: () => context.go(_customer ? '/customers' : '/dealers'), icon: const Icon(Icons.arrow_back_rounded), label: Text(_customer ? l.navCustomers : l.navDealers)),
      ],
      child: OpenOnce(
        key: ValueKey('open-bill-${widget.openBillId ?? ''}'),
        run: widget.openBillId == null
            ? null
            : () async {
                final d = await ref.read(appDataProvider).bills.detail(widget.openBillId!);
                if (d != null && context.mounted) await showBillPopup(context, ref, d.row, backTo: '/customers/${widget.partyId}?openBill=${Uri.encodeQueryComponent(d.row.id)}');
              },
        child: OpenOnce(
          key: ValueKey('open-estimate-${widget.openEstimate ?? ''}'),
          run: widget.openEstimate == null
              ? null
              : () async {
                  final list = await ref.read(customerEstimatesProvider(widget.partyId).future);
                  final e = list.where((x) => x.number == widget.openEstimate).firstOrNull;
                  if (e != null && context.mounted) showEstimatePopup(context, ref, e, backTo: '/customers/${widget.partyId}?openEstimate=${Uri.encodeQueryComponent(e.number)}');
                },
          child: content,
        ),
      ),
    );
  }
}
