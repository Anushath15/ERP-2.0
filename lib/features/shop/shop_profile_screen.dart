import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive.dart';
import '../../design/app_logo.dart';
import '../../design/widgets.dart';
import '../../fake/shop_profile.dart';
import '../system/reminder_settings.dart';

/// The shop's own details, in one place (not in Settings): printed bills and estimates read from here. It belongs to the
/// SHOP, so in Phase 2 it syncs between the shop's devices; Settings keeps only this device's own preferences.
class ShopProfileScreen extends ConsumerWidget {
  const ShopProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(shopProvider);
    final set = ref.read(shopProvider.notifier).set;

    Widget field(String keyName, String label, String value, ValueChanged<String> on, {TextInputType? type, int lines = 1, String? hint}) => TextFormField(
          key: ValueKey('shop-$keyName'),
          initialValue: value,
          keyboardType: type,
          minLines: lines,
          maxLines: lines,
          onChanged: on,
          decoration: InputDecoration(labelText: label, hintText: hint),
        );

    Widget wrap(List<Widget> children) => LayoutBuilder(builder: (ctx, bc) {
          final two = bc.maxWidth > 560;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final w in children) SizedBox(width: two ? (bc.maxWidth - 12) / 2 : bc.maxWidth, child: w)]);
        });

    final details = SectionCard(
      title: l.setShop,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const AppLogo(size: 56),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240), child: Text(l.shopLogoNote, style: th.bodySmall)),
          OutlinedButton.icon(onPressed: () => toast(context, l.demoOnly), icon: const Icon(Icons.image_outlined), label: Text(l.chooseFile)),
        ]),
        const SizedBox(height: 14),
        wrap([
          field('name', l.setShopName, s.name, (v) => set((x) => x.copyWith(name: v))),
          field('owner', l.shopOwner, s.ownerName, (v) => set((x) => x.copyWith(ownerName: v))),
          field('address', l.fieldAddress, s.address, (v) => set((x) => x.copyWith(address: v)), lines: 2),
          field('phone', l.fieldPhone, s.phone, (v) => set((x) => x.copyWith(phone: v)), type: TextInputType.phone),
          field('gstin', 'GSTIN', s.gstin, (v) => set((x) => x.copyWith(gstin: v))),
          field('upi', l.setUpi, s.upiId, (v) => set((x) => x.copyWith(upiId: v))),
          field('bank', l.shopBank, s.bankDetails, (v) => set((x) => x.copyWith(bankDetails: v)), lines: 2),
          field('footer', l.shopFooter, s.billFooter, (v) => set((x) => x.copyWith(billFooter: v)), lines: 2),
          field('prefix', l.shopPrefix, s.invoicePrefix, (v) => set((x) => x.copyWith(invoicePrefix: v.trim())), hint: 'A-'),
        ]),
      ]),
    );

    final tax = SectionCard(
      title: l.setTax,
      child: Column(children: [
        SwitchListTile(key: const ValueKey('shop-inclusive'), contentPadding: EdgeInsets.zero, title: Text(l.setPricesIncludeGst), subtitle: Text(l.setPricesIncludeGstHelp), value: s.pricesIncludeGst, onChanged: (v) => set((x) => x.copyWith(pricesIncludeGst: v))),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.setRoundOff), subtitle: Text(l.setRoundOffHelp), value: true, onChanged: (_) => toast(context, l.demoOnly)),
      ]),
    );

    SwitchListTile sw(String k, String label, bool value, EstimateShows Function(EstimateShows, bool) change) =>
        SwitchListTile(key: ValueKey('est-$k'), contentPadding: EdgeInsets.zero, dense: true, title: Text(label), value: value, onChanged: (v) => set((x) => x.copyWith(estimate: change(x.estimate, v))));

    final estimate = SectionCard(
      title: l.estShowTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.estShowHelp, style: th.bodySmall),
        const SizedBox(height: 4),
        sw('name', l.estShowName, s.estimate.shopName, (e, v) => e.copyWith(shopName: v)),
        sw('address', l.estShowAddress, s.estimate.address, (e, v) => e.copyWith(address: v)),
        sw('gstin', l.estShowGstin, s.estimate.gstin, (e, v) => e.copyWith(gstin: v)),
        sw('phone', l.estShowPhone, s.estimate.phone, (e, v) => e.copyWith(phone: v)),
        sw('number', l.estShowNumber, s.estimate.number, (e, v) => e.copyWith(number: v)),
        sw('tax', l.estShowTax, s.estimate.taxLines, (e, v) => e.copyWith(taxLines: v)),
      ]),
    );

    const reminders = RemindersCard();
    const credit = CreditSettingsCard();
    return PageFrame(
      title: l.navShop,
      subtitle: l.shopProfileSubtitle,
      child: context.isDesktop
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [for (final c in [details, tax]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [for (final c in [estimate, reminders, credit]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)])),
              ]),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [for (final c in [details, tax, estimate, reminders, credit]) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)]),
    );
  }
}
