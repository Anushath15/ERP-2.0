import 'dart:async';
import '../../design/hotkeys.dart';
import '../../core/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/date_fmt.dart';
import '../../core/link_launcher.dart';
import '../../core/money.dart';
import '../../core/responsive.dart';
import '../../design/form_sheet.dart';
import '../../design/motion.dart';
import '../../design/segments.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../domain/credit/dues.dart';
import '../../domain/credit/ledger.dart';
import '../../domain/credit/payment_split.dart';
import '../../domain/credit/reminder.dart';
import '../../fake/credit_store.dart';
import '../../fake/models.dart';
import '../../fake/store.dart';
import '../../fake/shop_profile.dart';
import '../../strings.dart';

String ledgerKindLabel(Strings l, LedgerKind k, {bool dealer = false}) => switch (k) {
      LedgerKind.opening => l.lkOpening,
      LedgerKind.billCredit => dealer ? l.lkDPurchase : l.lkBillCredit,
      LedgerKind.payment => dealer ? l.lkDPayment : l.lkPayment,
      LedgerKind.advance => dealer ? l.lkDAdvance : l.lkAdvance,
      LedgerKind.returnCredit => dealer ? l.lkDReturn : l.lkReturn,
      LedgerKind.adjustment => l.lkAdjust,
      LedgerKind.manualCredit => l.lkManualCredit,
      LedgerKind.writeOff => l.lkWriteOff,
      LedgerKind.billCancel => l.lkBillCancel,
    };

/// A snack bar with one action button (used for "Not sent? Undo").
void toastAction(BuildContext context, String message, String actionLabel, VoidCallback onAction, {int seconds = 8}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), duration: Duration(seconds: seconds), action: SnackBarAction(label: actionLabel, onPressed: onAction)));
}

Future<T?> _showPanel<T>(BuildContext context, Widget child) {
  if (context.isPhone) {
    return showModalBottomSheet<T>(context: context, sheetAnimationStyle: dialogStyle(context), isScrollControlled: true, useSafeArea: true, builder: (_) => child);
  }
  return showDialog<T>(context: context, animationStyle: dialogStyle(context), builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760), child: child)));
}

// ===================================================================== receive payment

/// Who a payment dialog is for.
class PartyRef {
  const PartyRef(this.id, this.name, this.kind);
  final String id, name;
  final PartyKind kind;
}

Future<PaymentReceipt?> showReceivePayment(BuildContext context, Customer customer) => showPartyPayment(context, PartyRef(customer.id, customer.name, PartyKind.customer));

/// "Receive payment" for a customer, "Pay dealer" for a dealer: same rules (oldest bill first, or the bills you choose; extra becomes an advance).
Future<PaymentReceipt?> showPartyPayment(BuildContext context, PartyRef party) => _showPanel<PaymentReceipt>(context, ReceivePaymentPanel(party: party));

class ReceivePaymentPanel extends ConsumerStatefulWidget {
  const ReceivePaymentPanel({super.key, required this.party});
  final PartyRef party;
  @override
  ConsumerState<ReceivePaymentPanel> createState() => _ReceivePaymentPanelState();
}

class _ReceivePaymentPanelState extends ConsumerState<ReceivePaymentPanel> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  String _mode = 'cash';
  late DateTime _date = ref.read(clockProvider);
  bool _manual = false;
  final _chosen = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(bookOf(ref, widget.party.kind).ensureLoaded(widget.party.id)); // a quiet account is read from the database when its payment panel opens
    final bal = bookOf(ref, widget.party.kind).balanceOf(widget.party.id);
    _amount = TextEditingController(text: bal > 0 ? (bal / 100).toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final c = context.c;
    final dealer = widget.party.kind == PartyKind.dealer;
    final acct = watchBook(ref, widget.party.kind)[widget.party.id] ?? const CreditAccount();
    final unpaid = unpaidBills(acct.bills);
    final amount = parseRupeesToPaise(_amount.text) ?? 0;
    final canAllocate = amount > 0 && (!_manual || _chosen.isNotEmpty || unpaid.isEmpty);
    final res = amount > 0 ? allocatePayment(bills: acct.bills, amount: amount, onlyBills: _manual ? _chosen : null) : null;
    final per = {for (final a in res?.allocations ?? const <Allocation>[]) a.billNo: a.paise};

    Future<void> save() async {
      if (amount <= 0) {
        setState(() => _error = l.fieldRequired);
        return;
      }
      final rec = await bookOf(ref, widget.party.kind).receivePayment(customerId: widget.party.id, customerName: widget.party.name, amount: amount, mode: _mode, at: _date, note: _note.text.trim(), onlyBills: _manual ? _chosen : null);
      if (context.mounted) Navigator.pop(context, rec);
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): save},
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: enterSaves(() => unawaited(save())), // Enter saves the payment
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
          child: Row(children: [
            Expanded(child: Text(dealer ? l.payDealer : l.receivePayment, style: th.titleLarge)),
            IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(dealer ? l.dealerPayFor(widget.party.name) : l.recvFor(widget.party.name), style: th.bodySmall),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('payAmount'),
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(labelText: l.fieldAmount, prefixText: '₹ ', errorText: _error),
              ),
              const SizedBox(height: 12),
              SlideSegments<String>(options: [('cash', l.payCash, Icons.payments_rounded), ('upi', l.payUpi, Icons.qr_code_2_rounded), ('card', l.payCard, Icons.credit_card_rounded)], selected: _mode, onChanged: (v) => setState(() => _mode = v)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(_date.year - 2), lastDate: DateTime(_date.year + 1), initialDate: _date);
                      if (d != null) setState(() => _date = d);
                    },
                    child: InputDecorator(decoration: InputDecoration(labelText: l.fieldDate, suffixIcon: const Icon(Icons.calendar_today_rounded)), child: Text(formatDate(_date))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _note, inputFormatters: [safeInput(TextKind.note)], decoration: InputDecoration(labelText: dealer ? l.dealerPayRef : l.fieldNote))),
              ]),
              const SizedBox(height: 14),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(_manual ? l.recvChoose : l.recvAuto), value: _manual, onChanged: unpaid.isEmpty ? null : (v) => setState(() => _manual = v)),
              if (unpaid.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: StatusBadge(l.recvNothingDue, kind: BadgeKind.info, icon: Icons.info_outline_rounded))
              else
                for (final b in unpaid)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.border.withValues(alpha: 0.5))),
                    child: Row(children: [
                      if (_manual) Checkbox(value: _chosen.contains(b.billNo), onChanged: (v) => setState(() => v == true ? _chosen.add(b.billNo) : _chosen.remove(b.billNo))),
                      Expanded(child: Text(l.recvBillRow(b.billNo, formatDate(b.date), formatPaise(b.outstanding, symbol: true)), style: th.bodyMedium)),
                      if ((per[b.billNo] ?? 0) > 0) StatusBadge(l.recvWillPay(formatPaise(per[b.billNo]!, symbol: true)), kind: per[b.billNo] == b.outstanding ? BadgeKind.success : BadgeKind.warning),
                    ]),
                  ),
              if (res != null) ...[
                const Divider(),
                if (res.appliedPaise > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l.recvSettles(formatPaise(res.appliedPaise, symbol: true)), style: th.titleSmall)),
                if (res.advancePaise > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: StatusBadge(l.recvAdvance(formatPaise(res.advancePaise, symbol: true)), kind: BadgeKind.info, icon: Icons.savings_rounded)),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: FilledButton.icon(onPressed: canAllocate ? save : null, icon: const Icon(Icons.check_rounded), label: Text(l.savePayment))),
          ]),
        ),
      ]),
      ),
    );
  }
}

// ===================================================================== write off (owner only)

Future<void> showWriteOff(BuildContext context, WidgetRef ref, Customer c) async {
  final l = tr(context);
  final max = maxWriteOff(ref.read(creditProvider.notifier).account(c.id).ledger);
  if (max <= 0) return;
  final v = await showFormSheet(context, title: l.writeOffTitle(c.name), saveLabel: l.writeOff, note: '${l.writeOffHelp}\n${l.writeOffMax(formatPaise(max, symbol: true))}', fields: [
    FieldSpec('amount', l.fieldAmount, type: FieldType.money, initial: (max / 100).toStringAsFixed(2), required: true, autofocus: true),
    FieldSpec('reason', l.fieldReason, type: FieldType.multiline, required: true),
  ]);
  if (v == null || !context.mounted) return;
  final amt = parseRupeesToPaise(v['amount'] ?? '') ?? 0;
  if (amt <= 0 || amt > max) {
    toast(context, l.writeOffMax(formatPaise(max, symbol: true)));
    return;
  }
  final ok = await confirmDialog(context, title: l.writeOffTitle(c.name), message: l.writeOffDone(formatPaise(amt, symbol: true)), confirmLabel: l.writeOff, danger: true);
  if (!ok || !context.mounted) return;
  await ref.read(creditProvider.notifier).writeOff(customerId: c.id, amount: amt, reason: v['reason']!, at: ref.read(clockProvider));
  if (context.mounted) toast(context, l.writeOffDone(formatPaise(amt, symbol: true)));
}

// ===================================================================== WhatsApp reminder

/// Preview dialog: the ready message (editable), then "Open WhatsApp". The app never sends anything itself.
Future<void> showReminderDialog(BuildContext context, Customer customer) => _showPanel<void>(context, ReminderPanel(customer: customer, rootContext: context));

class ReminderPanel extends ConsumerStatefulWidget {
  const ReminderPanel({super.key, required this.customer, required this.rootContext});
  final Customer customer;
  final BuildContext rootContext; // the page behind the dialog, used for the "Undo" message after the dialog closes
  @override
  ConsumerState<ReminderPanel> createState() => _ReminderPanelState();
}

class _ReminderPanelState extends ConsumerState<ReminderPanel> {
  late ReminderTone _tone = ref.read(shopProvider).reminderTone;
  late final TextEditingController _msg = TextEditingController(text: _build(_tone));
  late final TextEditingController _phone = TextEditingController(text: widget.customer.phone);
  late String _savedPhone = widget.customer.phone;
  String? _phoneError;

  String _build(ReminderTone tone) {
    final s = ref.read(shopProvider);
    final acct = ref.read(creditProvider)[widget.customer.id] ?? const CreditAccount();
    return buildReminderMessage(
      tone == ReminderTone.friendly ? s.templateFriendly : s.templateFirm,
      ReminderInput(customerName: widget.customer.name, shopName: s.name, shopPhone: s.phone, upiId: s.upiId, bills: acct.bills, today: ref.read(clockProvider), lastPaymentDate: acct.lastPaymentAt),
    );
  }

  @override
  void dispose() {
    _msg.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _digits => normalizePhone(_savedPhone, defaultCountry: ref.read(shopProvider).countryCode);

  void _savePhone() {
    final l = tr(context);
    if (normalizePhone(_phone.text, defaultCountry: ref.read(shopProvider).countryCode) == null) {
      setState(() => _phoneError = l.remNumberBad);
      return;
    }
    ref.read(customersProvider.notifier).updatePhone(widget.customer.id, _phone.text.trim());
    setState(() {
      _savedPhone = _phone.text.trim();
      _phoneError = null;
    });
  }

  Future<void> _open() async {
    final l = tr(context);
    final s = ref.read(settingsProvider);
    final now = ref.read(clockProvider);
    final digits = _digits;
    final check = canOpenWhatsapp(online: s.sync != SyncState.offline, digits: digits);
    if (!check.allowed || digits == null) return;
    final recent = ref.read(reminderLogProvider).recent(widget.customer.id, now, hours: ref.read(shopProvider).guardHours);
    if (recent != null) {
      final sameDay = recent.at.year == now.year && recent.at.month == now.month && recent.at.day == now.day;
      final when = sameDay ? 'today at ${formatTime(recent.at)}' : 'on ${formatDate(recent.at)} at ${formatTime(recent.at)}';
      final again = await confirmDialog(context, title: l.remGuardTitle, message: l.remGuard(when), confirmLabel: l.remGuardYes);
      if (!again || !mounted) return;
    }
    final links = buildWhatsappLinks(digits: digits, message: _msg.text);
    final launcher = ref.read(linkLauncherProvider);
    final ok = await openFirst(launcher, links.tryOrder(launcher.platform));
    if (!mounted) return;
    final root = widget.rootContext;
    if (!ok) {
      toast(context, l.remFailed);
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false); // still valid after this dialog closes
    final acct = ref.read(creditProvider)[widget.customer.id] ?? const CreditAccount();
    final rec = ref.read(reminderLogProvider.notifier).record(customerId: widget.customer.id, amountDue: acct.balance, message: _msg.text, at: now);
    final count = ref.read(reminderLogProvider).countFor(widget.customer.id);
    Navigator.pop(context);
    if (root.mounted) {
      toastAction(root, l.remOpened(count.toString()), l.remNotSent, () {
        container.read(reminderLogProvider.notifier).undo(rec.id);
        if (root.mounted) toast(root, l.remUndone);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(settingsProvider);
    final digits = _digits;
    final check = canOpenWhatsapp(online: s.sync != SyncState.offline, digits: digits);
    final hasNumber = _savedPhone.trim().isNotEmpty && digits != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
        child: Row(children: [
          Expanded(child: Text(l.remTitle(widget.customer.name), style: th.titleLarge)),
          IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.remHelp, style: th.bodySmall),
            const SizedBox(height: 12),
            if (!hasNumber) ...[
              Text(l.remNoNumber, style: th.bodyMedium),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: TextField(key: const ValueKey('remPhone'), controller: _phone, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()\-.]'))], decoration: InputDecoration(labelText: l.remNumber, errorText: _phoneError))),
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(top: 4), child: FilledButton(onPressed: _savePhone, child: Text(l.saveNumber))),
              ]),
              const SizedBox(height: 12),
            ] else
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.chat_rounded, size: 18), const SizedBox(width: 8), Text(prettyPhone(digits), style: th.titleSmall)])),
            SlideSegments<ReminderTone>(
              options: [(ReminderTone.friendly, l.toneFriendly, null), (ReminderTone.firm, l.toneFirm, null)],
              selected: _tone,
              onChanged: (v) => setState(() {
                _tone = v;
                _msg.text = _build(v);
              }),
            ),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('remMessage'), controller: _msg, inputFormatters: [safeInput(TextKind.message)], minLines: 8, maxLines: 14, decoration: InputDecoration(labelText: l.remMessage, alignLabelWithHint: true)),
            Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_msg.text.length} / $maxReminderLength', style: th.bodySmall))),
            if (!check.allowed && hasNumber) Padding(padding: const EdgeInsets.only(top: 6), child: StatusBadge(check.reason!, kind: BadgeKind.warning, icon: Icons.cloud_off_rounded)),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: _msg.text)));
              toast(context, l.remCopied);
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(l.remCopy),
          ),
          Tooltip(
            message: check.allowed ? l.remsTooltipOpen : (check.reason ?? ''),
            child: FilledButton.icon(key: const ValueKey('openWhatsapp'), onPressed: check.allowed && hasNumber ? _open : null, icon: const Icon(Icons.open_in_new_rounded), label: Text(l.remOpen)),
          ),
        ]),
      ),
    ]);
  }
}

/// Context-free entry point used by rows and screens: opens the reminder dialog for this customer.
void remindCustomer(BuildContext context, Customer c) => showReminderDialog(context, c);

/// Opens the payment receipt preview for a payment that was just saved.
void openReceiptPreview(BuildContext context, WidgetRef ref, PaymentReceipt r) {
  ref.read(lastReceiptProvider.notifier).set(r);
  context.push('/preview/payment');
}

class LastReceipt extends Notifier<PaymentReceipt?> {
  @override
  PaymentReceipt? build() => null;
  void set(PaymentReceipt? r) => state = r;
}

final lastReceiptProvider = NotifierProvider<LastReceipt, PaymentReceipt?>(LastReceipt.new);
