import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../core/cloud/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/logo_image.dart';
import '../../core/responsive.dart';
import '../../core/validators.dart';
import '../../design/form_sheet.dart' show textProblemMessage;
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

    Widget field(String keyName, String label, String value, ValueChanged<String> on, {TextInputType? type, int lines = 1, String? hint, TextKind kind = TextKind.name}) => TextFormField(
          key: ValueKey('shop-$keyName'),
          initialValue: value,
          keyboardType: type,
          minLines: lines,
          maxLines: lines,
          autovalidateMode: AutovalidateMode.always,
          inputFormatters: [safeInput(kind)],
          validator: (v) => textProblemMessage(l, kind, checkText(kind, v ?? '')),
          // a wrong value is shown with its reason and NOT saved: the shop keeps its last good value
          onChanged: (v) {
            if (checkText(kind, v) == null) on(storeText(kind, v));
          },
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
          ShopLogo(png: s.logoPng, size: 56),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240), child: Text(l.shopLogoNote, style: th.bodySmall)),
          OutlinedButton.icon(
            key: const ValueKey('shop-logo-choose'),
            onPressed: () async {
              final bytes = await ref.read(logoPickerProvider)();
              if (bytes == null || !context.mounted) return;
              final b64 = prepareLogo(bytes);
              if (b64 == null) {
                toast(context, l.logoBad);
                return;
              }
              set((x) => x.copyWith(logoPng: b64));
              toast(context, l.logoSaved);
            },
            icon: const Icon(Icons.image_rounded),
            label: Text(l.chooseFile),
          ),
          if (s.logoPng.isNotEmpty) TextButton(key: const ValueKey('shop-logo-remove'), onPressed: () => set((x) => x.copyWith(logoPng: '')), child: Text(l.logoRemove)),
        ]),
        const SizedBox(height: 14),
        wrap([
          field('name', l.setShopName, s.name, (v) => set((x) => x.copyWith(name: v))),
          field('owner', l.shopOwner, s.ownerName, (v) => set((x) => x.copyWith(ownerName: v))),
          field('address', l.fieldAddress, s.address, (v) => set((x) => x.copyWith(address: v)), lines: 2, kind: TextKind.address),
          field('phone', l.fieldPhone, s.phone, (v) => set((x) => x.copyWith(phone: v)), type: TextInputType.phone, kind: TextKind.phone),
          field('email', l.fieldEmail, s.email, (v) => set((x) => x.copyWith(email: v)), type: TextInputType.emailAddress, kind: TextKind.email),
          field('gstin', 'GSTIN', s.gstin, (v) => set((x) => x.copyWith(gstin: v)), kind: TextKind.gstin),
          field('upi', l.setUpi, s.upiId, (v) => set((x) => x.copyWith(upiId: v)), kind: TextKind.upi),
          field('bank', l.shopBank, s.bankDetails, (v) => set((x) => x.copyWith(bankDetails: v)), lines: 2, kind: TextKind.address),
          field('footer', l.shopFooter, s.billFooter, (v) => set((x) => x.copyWith(billFooter: v)), lines: 2, kind: TextKind.address),
          field('prefix', l.shopPrefix, s.invoicePrefix, (v) => set((x) => x.copyWith(invoicePrefix: v.trim())), hint: 'SE-', kind: TextKind.town),
        ]),
      ]),
    );

    final tax = SectionCard(
      title: l.setTax,
      child: Column(children: [
        SwitchListTile(key: const ValueKey('shop-inclusive'), contentPadding: EdgeInsets.zero, title: Text(l.setPricesIncludeGst), subtitle: Text(l.setPricesIncludeGstHelp), value: s.pricesIncludeGst, onChanged: (v) => set((x) => x.copyWith(pricesIncludeGst: v))),
        SwitchListTile(key: const ValueKey('shop-roundoff'), contentPadding: EdgeInsets.zero, title: Text(l.setRoundOff), subtitle: Text(l.setRoundOffHelp), value: s.roundOff, onChanged: (v) => set((x) => x.copyWith(roundOff: v))),
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
      actions: [
        OutlinedButton.icon(key: const ValueKey('shop-settings'), onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_rounded), label: Text(l.navSettings)),
        OutlinedButton.icon(key: const ValueKey('shop-signout'), onPressed: () async {
          final ok = await confirmDialog(context, title: l.signOutConfirmTitle, message: l.signOutConfirmText, confirmLabel: l.signOut, danger: true);
          if (!ok) return;
          await ref.read(authProvider.notifier).signOut();
          if (context.mounted) context.go('/signin');
        }, icon: const Icon(Icons.logout_rounded), label: Text(l.signOut)),
      ],
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

/// Opens the picture chooser (PNG or JPG). Overridden in tests so no real file dialog is needed.
final logoPickerProvider = Provider<Future<Uint8List?> Function()>((ref) => () async {
      const types = XTypeGroup(label: 'Picture', extensions: ['png', 'jpg', 'jpeg']);
      final f = await openFile(acceptedTypeGroups: [types]);
      if (f == null) return null;
      if (await f.length() > maxLogoInputBytes) return Uint8List(0);
      return f.readAsBytes();
    });

/// The shop's own logo when it has one, else the program's logo.
class ShopLogo extends StatelessWidget {
  const ShopLogo({super.key, required this.png, this.size = 40});
  final String png;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = logoBytes(png);
    if (bytes == null) return AppLogo(size: size);
    return Image.memory(bytes, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.high, errorBuilder: (_, _, _) => AppLogo(size: size));
  }
}
