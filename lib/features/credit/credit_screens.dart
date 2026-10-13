import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/file_saver.dart';
import '../../core/date_fmt.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/data_list.dart';
import '../../design/segments.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/credit_store.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../../strings.dart';
import 'credit_dialogs.dart';
import 'party_dialogs.dart';
import 'statement_pdf.dart';

/// One line of the Credit and Dues list.
class CreditRow {
  const CreditRow({required this.customer, required this.account, required this.balance, required this.overdue, required this.oldestDays, required this.reminders, required this.lastReminded});
  final Customer customer;
  final CreditAccount account;
  final int balance, overdue, reminders;
  final int? oldestDays;
  final DateTime? lastReminded;
  bool get overLimit => balance > customer.creditLimitPaise;
  bool get isAdvance => balance < 0;
}

final creditRowsProvider = Provider<List<CreditRow>>((ref) {
  final credit = ref.watch(creditProvider);
  final customers = {for (final c in ref.watch(customersProvider)) c.id: c};
  final log = ref.watch(reminderLogProvider);
  final now = ref.watch(clockProvider);
  final out = <CreditRow>[];
  for (final e in credit.entries) {
    final c = customers[e.key];
    final a = e.value;
    if (c == null || a.balance == 0) continue;
    out.add(CreditRow(customer: c, account: a, balance: a.balance, overdue: overdueAmount(a.bills, now), oldestDays: oldestUnpaidDays(a.bills, now), reminders: log.countFor(e.key), lastReminded: log.lastFor(e.key)));
  }
  out.sort((x, y) => y.balance.compareTo(x.balance));
  return out;
});

String remindedText(Strings l, int count, DateTime? last) {
  if (count == 0 || last == null) return l.notReminded;
  final d = '${last.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][last.month - 1]}';
  return count == 1 ? l.remindedOnce(d) : l.remindedMany(count.toString(), d);
}

Widget reminderBadge(BuildContext context, int count, DateTime? last) {
  final l = tr(context);
  return Tooltip(
    message: l.remindersTooltip,
    child: StatusBadge(remindedText(l, count, last), kind: count == 0 ? BadgeKind.neutral : BadgeKind.info, icon: count == 0 ? null : Icons.chat_outlined),
  );
}

// ===================================================================== Credit and Dues

class CreditScreen extends ConsumerWidget {
  const CreditScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final rows = ref.watch(creditRowsProvider);
    final notifier = ref.read(creditProvider.notifier);
    ref.watch(creditProvider);
    final owing = rows.where((r) => r.balance > 0);
    final overdue = owing.fold<int>(0, (s, r) => s + r.overdue);
    final th = Theme.of(context).textTheme;
    final online = ref.watch(settingsProvider).sync != SyncState.offline;

    Widget actions(BuildContext ctx, CreditRow r, {bool compact = false}) {
      final wa = IconButton(
        tooltip: online ? l.actRemind : '${l.actRemind}: ${canOpenWhatsapp(online: false, digits: null).reason}',
        onPressed: r.balance > 0 ? () => remindCustomer(ctx, r.customer) : null,
        icon: const Icon(Icons.chat_outlined),
      );
      final stmt = IconButton(tooltip: l.actStatement, onPressed: () => ctx.go('/customers/${r.customer.id}/statement'), icon: const Icon(Icons.description_outlined));
      final recv = FilledButton.tonal(
        onPressed: () async {
          final rec = await showReceivePayment(ctx, r.customer);
          if (rec != null && ctx.mounted) {
            toastAction(ctx, l.recvDone(formatPaise(rec.amountPaise, symbol: true), r.customer.name), l.printReceipt, () => openReceiptPreview(ctx, ref, rec), seconds: 6);
          }
        },
        child: Text(l.receivePayment),
      );
      final settle = r.balance > 0
          ? OutlinedButton(key: ValueKey('settle-${r.customer.id}'), onPressed: () => showSettleFully(ctx, PartyRef(r.customer.id, r.customer.name, PartyKind.customer)), child: Text(l.settleFully))
          : const SizedBox.shrink();
      final addCredit = IconButton(key: ValueKey('addCredit-${r.customer.id}'), tooltip: l.addCredit, onPressed: () => showAddCredit(ctx, r.customer), icon: const Icon(Icons.add_card_outlined));
      return FittedBox(fit: BoxFit.scaleDown, alignment: compact ? Alignment.centerLeft : Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: [settle, if (r.balance > 0) const SizedBox(width: 6), recv, addCredit, wa, stmt]));
    }

    return DataListScreen<CreditRow>(
      title: l.navCredit,
      subtitle: l.creditSubtitle,
      items: rows,
      searchText: (r) => '${r.customer.name} ${r.customer.phone}',
      searchHint: l.searchCustomerHint,
      stats: [
        StatCard(label: l.statToCollect, value: '₹ ${formatPaise(notifier.totalToCollect)}', icon: Icons.south_west, tone: context.c.warning),
        StatCard(label: l.statOverdue, value: '₹ ${formatPaise(overdue)}', icon: Icons.schedule, tone: context.c.danger),
        StatCard(label: l.statCustomersOwing, value: owing.length.toString(), icon: Icons.people_outline),
        StatCard(label: l.statAdvances, value: '₹ ${formatPaise(notifier.totalAdvances)}', icon: Icons.savings_outlined, tone: context.c.success),
      ],
      filters: [
        FilterSpec(l.filterOverdue, (r) => r.overdue > 0),
        FilterSpec(l.filterOverLimit, (r) => r.overLimit),
        FilterSpec(l.filterAdvance, (r) => r.isAdvance),
      ],
      sorts: [(l.sortOldest, (a, b) => (b.oldestDays ?? -1).compareTo(a.oldestDays ?? -1))],
      addLabel: l.addCreditCustomer,
      onAdd: () => showAddCreditCustomer(context),
      onTap: (ctx, r) => ctx.go('/customers/${r.customer.id}'),
      columns: [
        ColumnSpec(l.fieldName, (c, r) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.customer.name, style: th.titleSmall), Text(r.customer.phone.isEmpty ? l.custNoNumber : r.customer.phone, style: th.bodySmall)]), flex: 4),
        ColumnSpec(l.custBalance, (c, r) => r.isAdvance ? StatusBadge(l.advanceAmount(formatPaise(-r.balance, symbol: true)), kind: BadgeKind.success) : Cell(formatPaise(r.balance, symbol: true), bold: true, color: c.c.warning), width: 110, numeric: true),
        ColumnSpec(l.colOverdue, (c, r) => r.overdue > 0 ? Cell(formatPaise(r.overdue), color: c.c.danger) : const Cell('-', muted: true), width: 90, numeric: true),
        ColumnSpec(l.colOldest, (c, r) => r.oldestDays == null ? const Cell('-', muted: true) : Cell(l.daysCount(r.oldestDays.toString()), muted: true), width: 70),
        ColumnSpec(l.colReminders, (c, r) => reminderBadge(c, r.reminders, r.lastReminded), flex: 3),
        ColumnSpec('', (c, r) => actions(c, r), width: 400, numeric: true),
      ],
      phoneTitle: (c, r) => Row(children: [Expanded(child: Text(r.customer.name, style: th.titleSmall)), r.isAdvance ? StatusBadge(l.advanceAmount(formatPaise(-r.balance, symbol: true)), kind: BadgeKind.success) : Text(formatPaise(r.balance, symbol: true), style: th.titleSmall?.copyWith(color: c.c.warning))]),
      phoneSubtitle: (r) => r.overdue > 0 ? '${r.customer.phone.isEmpty ? l.custNoNumber : r.customer.phone}  ·  ${l.statOverdue}: ${formatPaise(r.overdue, symbol: true)}' : (r.customer.phone.isEmpty ? l.custNoNumber : r.customer.phone),
      phoneActions: (c, r) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [reminderBadge(c, r.reminders, r.lastReminded), const SizedBox(height: 6), actions(c, r, compact: true)]),
      emptyTitle: l.nobodyOwes,
      emptyIcon: Icons.celebration_outlined,
    );
  }
}

// ===================================================================== statement (printable)

class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key, required this.customerId});
  final String customerId;
  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  int _range = 1; // 0 month, 1 three months, 2 all

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    final now = ref.watch(clockProvider);
    final customer = ref.watch(customersProvider).where((x) => x.id == widget.customerId).firstOrNull;
    final acct = ref.watch(creditProvider)[widget.customerId] ?? const CreditAccount();
    final settings = ref.watch(settingsProvider);
    if (customer == null) return PageFrame(title: l.statementTitle, child: EmptyState(icon: Icons.person_off_outlined, title: l.nothingFound));
    final from = switch (_range) { 0 => DateTime(now.year, now.month, 1), 1 => DateTime(now.year, now.month - 2, 1), _ => DateTime(2000) };
    final st = buildStatement(entries: acct.ledger, from: from, to: now);
    final phone = context.isPhone;
    final actions = [
      FilledButton.icon(onPressed: () => toast(context, l.printNotConnected), icon: const Icon(Icons.print), label: Text(l.print)),
      OutlinedButton.icon(
        key: const ValueKey('statementPdf'),
        onPressed: () async {
          final bytes = await buildStatementPdf(statement: st, customer: customer, shopName: settings.shopName, shopPhone: settings.shopPhone, today: now, l: l);
          final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final where = await ref.read(fileSaverProvider).save('Statement ${customer.name} $stamp.pdf', bytes);
          if (context.mounted) toast(context, where == null ? l.pdfFailed : l.pdfSaved(where));
        },
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(l.saveAsPdf),
      ),
      TextButton(onPressed: () => context.go('/customers/${widget.customerId}'), child: Text(l.back)),
    ];
    return PageFrame(
      title: l.statementTitle,
      subtitle: customer.name,
      actions: phone ? const [] : actions,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SlideSegments<int>(options: [(0, l.stRangeMonth, null), (1, l.stRange3, null), (2, l.stRangeAll, null)], selected: _range, onChanged: (v) => setState(() => _range = v)),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
            child: LayoutBuilder(builder: (ctx, bc) {
              const paperW = 595.0;
              final scale = ((bc.maxWidth - 24) / paperW).clamp(0.3, 1.6);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: paperW * (scale > 1 ? 1.0 : scale),
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), child: SizedBox(width: paperW, child: StatementPaper(statement: st, customer: customer, shopName: settings.shopName, shopPhone: settings.shopPhone, today: now))),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (phone) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
      ]),
    );
  }
}

TextStyle _paperStyle(BuildContext context, {bool b = false, double size = 12}) => TextStyle(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily, color: context.c.onPaper, fontSize: size, fontWeight: b ? FontWeight.w700 : FontWeight.w400, height: 1.3);

class StatementPaper extends StatelessWidget {
  const StatementPaper({super.key, required this.statement, required this.customer, required this.shopName, required this.shopPhone, required this.today});
  final Statement statement;
  final Customer customer;
  final String shopName, shopPhone;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final c = context.c;
    TextStyle s({bool b = false, double size = 12}) => _paperStyle(context, b: b, size: size);
    Widget row(List<Widget> cells) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
    Widget money(int v, {bool b = false}) => SizedBox(width: 78, child: Text(v == 0 ? '' : formatPaise(v), textAlign: TextAlign.right, style: s(b: b)));
    return Container(
      color: c.paper,
      padding: const EdgeInsets.all(28),
      constraints: const BoxConstraints(minHeight: 842),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(shopName.toUpperCase(), style: s(b: true, size: 18)),
        Text('Ph: $shopPhone', style: s()),
        Divider(color: c.onPaper.withValues(alpha: 0.5)),
        Center(child: Text(l.statementTitle.toUpperCase(), style: s(b: true, size: 15))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(customer.name, style: s(b: true)), Text(customer.phone, style: s()), Text(customer.city, style: s())]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${formatDate(statement.from.year <= 2000 ? DateTime(2000) : statement.from)} - ${formatDate(statement.to)}', style: s()), Text('${l.rcDate}: ${formatDate(today)}', style: s())]),
        ]),
        Divider(color: c.onPaper.withValues(alpha: 0.5)),
        row([Expanded(child: Text(l.stOpening, style: s(b: true))), SizedBox(width: 78 * 3, child: Text(formatPaise(statement.openingPaise), textAlign: TextAlign.right, style: s(b: true)))]),
        row([SizedBox(width: 70, child: Text(l.colDate, style: s(b: true))), Expanded(child: Text(l.colType, style: s(b: true))), SizedBox(width: 78, child: Text(l.colCharged, textAlign: TextAlign.right, style: s(b: true))), SizedBox(width: 78, child: Text(l.rcReceived, textAlign: TextAlign.right, style: s(b: true))), SizedBox(width: 78, child: Text(l.colRunning, textAlign: TextAlign.right, style: s(b: true)))]),
        Divider(color: c.onPaper.withValues(alpha: 0.3)),
        for (final ln in statement.lines)
          row([
            SizedBox(width: 70, child: Text(formatDate(ln.at), style: s())),
            Expanded(child: Text('${ledgerKindLabel(l, ln.kind)}${ln.billNo == null ? '' : ' ${ln.billNo}'}${ln.note.isEmpty ? '' : ' (${ln.note})'}', style: s())),
            money(ln.chargePaise),
            money(ln.creditPaise),
            SizedBox(width: 78, child: Text(formatPaise(ln.runningPaise), textAlign: TextAlign.right, style: s())),
          ]),
        Divider(color: c.onPaper.withValues(alpha: 0.5)),
        row([Expanded(child: Text(l.stCharges, style: s())), SizedBox(width: 78, child: Text(formatPaise(statement.totalCharges), textAlign: TextAlign.right, style: s()))]),
        row([Expanded(child: Text(l.stCredits, style: s())), SizedBox(width: 78, child: Text(formatPaise(statement.totalCredits), textAlign: TextAlign.right, style: s()))]),
        row([Expanded(child: Text(statement.closingPaise < 0 ? l.custAdvance : l.stClosing, style: s(b: true, size: 14))), SizedBox(width: 110, child: Text('₹ ${formatPaise(statement.closingPaise.abs())}', textAlign: TextAlign.right, style: s(b: true, size: 14)))]),
        const SizedBox(height: 16),
        Center(child: Text(l.statementHint, style: s(size: 10), textAlign: TextAlign.center)),
      ]),
    );
  }
}

// ===================================================================== payment receipt preview

class PaymentReceiptScreen extends ConsumerWidget {
  const PaymentReceiptScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final c = context.c;
    final settings = ref.watch(settingsProvider);
    final now = ref.watch(clockProvider);
    final r = ref.watch(lastReceiptProvider) ??
        PaymentReceipt(number: 'RCP-0041', customerId: 'c1', customerName: 'Murugan Electricals', amountPaise: 150000, mode: 'cash', at: now, note: '', allocations: const [Allocation('A-019804', 100000), Allocation('A-019821', 40000)], advancePaise: 10000, balanceAfter: -10000);
    TextStyle s({bool b = false, double size = 11}) => _paperStyle(context, b: b, size: size);
    String mode(String m) => switch (m) { 'upi' => l.payUpi, 'card' => l.payCard, _ => l.payCash };
    final paper = Container(
      width: 302,
      color: c.paper,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Text(settings.shopName.toUpperCase(), style: s(b: true, size: 14))),
        Center(child: Text('Ph: ${settings.shopPhone}', style: s())),
        Divider(color: c.onPaper.withValues(alpha: 0.5)),
        Center(child: Text(l.rcPaymentReceipt, style: s(b: true, size: 12))),
        const SizedBox(height: 6),
        Text('${l.rcReceiptNo}: ${r.number}', style: s(b: true)),
        Text('${l.rcDate}: ${formatDate(r.at)}', style: s()),
        Text('${l.rcReceivedFrom}: ${r.customerName}', style: s()),
        Text('${l.rcPaidBy}: ${mode(r.mode)}', style: s()),
        Divider(color: c.onPaper.withValues(alpha: 0.5)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l.rcAmount.toUpperCase(), style: s(b: true, size: 13)), Text('₹ ${formatPaise(r.amountPaise)}', style: s(b: true, size: 13))]),
        if (r.allocations.isNotEmpty) ...[const SizedBox(height: 6), Text(l.rcAppliedTo, style: s(b: true)), for (final a in r.allocations) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a.billNo, style: s()), Text(formatPaise(a.paise), style: s())])],
        if (r.advancePaise > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l.rcAdvance, style: s()), Text(formatPaise(r.advancePaise), style: s())]),
        Divider(color: c.onPaper.withValues(alpha: 0.5)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r.balanceAfter < 0 ? l.rcAdvanceNow : l.rcBalanceNow, style: s(b: true)), Text('₹ ${formatPaise(r.balanceAfter.abs())}', style: s(b: true))]),
        const SizedBox(height: 10),
        Center(child: Text(l.rcThanks, style: s(), textAlign: TextAlign.center)),
      ]),
    );
    return PageFrame(
      title: l.printReceipt,
      actions: [
        FilledButton.icon(onPressed: () => toast(context, l.printNotConnected), icon: const Icon(Icons.print), label: Text(l.print)),
        OutlinedButton.icon(onPressed: () => toast(context, l.pdfNotConnected), icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(l.saveAsPdf)),
        if (context.canPop()) TextButton(onPressed: () => context.pop(), child: Text(l.back)),
      ],
      child: Container(width: double.infinity, decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), child: paper)))),
    );
  }
}
