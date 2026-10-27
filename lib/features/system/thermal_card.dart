import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/widgets.dart';
import '../../fake/store.dart';
import '../print/escpos.dart' show parsePrinterAddress;
import '../print/print_layout.dart' show isRoll;
import '../print/thermal_action.dart';

/// Settings > Thermal printer, direct: how the receipt printer is reached (the bill printer chosen above, or a network address), letters per
/// line, the paper cut and the cash drawer; with a test slip and an "Open drawer" button. Everything here is this computer's own setting.
class ThermalCard extends ConsumerStatefulWidget {
  const ThermalCard({super.key});
  @override
  ConsumerState<ThermalCard> createState() => _ThermalCardState();
}

class _ThermalCardState extends ConsumerState<ThermalCard> {
  late final _address = TextEditingController(text: ref.read(settingsProvider).thermalAddress);

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    final th = Theme.of(context).textTheme;
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).set;
    final on = s.thermal != ThermalLink.off;
    final badAddress = s.thermal == ThermalLink.network && _address.text.trim().isNotEmpty && parsePrinterAddress(_address.text) == null;

    Widget row(String title, String? help, Widget trailing) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: th.titleSmall), if (help != null) Text(help, style: th.bodySmall)])),
            const SizedBox(width: 12),
            Flexible(child: Align(alignment: Alignment.centerRight, child: trailing)),
          ]),
        );
    String paperName(PaperSize p) => switch (p) { PaperSize.a4 => l.paperA4, PaperSize.a5 => l.paperA5, PaperSize.mm80 => l.paper80, PaperSize.mm58 => l.paper58 };

    return SectionCard(
      title: l.setThermal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.setThermalHelp, style: th.bodySmall),
        row(l.thermalHow, l.thermalHowHelp, SegmentedButton<ThermalLink>(
          key: const ValueKey('thermalLink'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: ThermalLink.off, label: Text(l.thermalOff, key: const ValueKey('thermal-off'))),
            ButtonSegment(value: ThermalLink.windows, label: Text(l.thermalWindows, key: const ValueKey('thermal-windows'))),
            ButtonSegment(value: ThermalLink.network, label: Text(l.thermalNetwork, key: const ValueKey('thermal-network'))),
          ],
          selected: {s.thermal},
          onSelectionChanged: (v) => set((x) => x.copyWith(thermal: v.first)),
        )),
        if (on && !isRoll(s.paper)) StatusBadge(l.thermalNeedsRoll(paperName(s.paper)), key: const ValueKey('thermalNeedsRoll'), kind: BadgeKind.warning, icon: Icons.info_outline_rounded),
        if (s.thermal == ThermalLink.network)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              key: const ValueKey('thermalAddress'),
              controller: _address,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l.thermalAddress, hintText: l.thermalAddressHint, errorText: badAddress ? l.thermalAddressBad : null, errorMaxLines: 3),
              onChanged: (v) {
                setState(() {});
                // only a good address is kept; a half-typed one is shown with its reason
                if (parsePrinterAddress(v) != null || v.trim().isEmpty) set((x) => x.copyWith(thermalAddress: v.trim()));
              },
            ),
          ),
        if (on) ...[
          row(l.thermalChars, l.thermalCharsHelp, SegmentedButton<int>(
            key: const ValueKey('thermalChars'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(l.thermalCharsAuto)),
              const ButtonSegment(value: 32, label: Text('32')),
              const ButtonSegment(value: 42, label: Text('42')),
              const ButtonSegment(value: 48, label: Text('48')),
            ],
            selected: {s.thermalChars},
            onSelectionChanged: (v) => set((x) => x.copyWith(thermalChars: v.first)),
          )),
          SwitchListTile(key: const ValueKey('thermalCut'), contentPadding: EdgeInsets.zero, title: Text(l.thermalCut), value: s.thermalCut, onChanged: (v) => set((x) => x.copyWith(thermalCut: v))),
          SwitchListTile(key: const ValueKey('thermalDrawer'), contentPadding: EdgeInsets.zero, title: Text(l.thermalDrawer), subtitle: Text(l.thermalDrawerHelp), value: s.thermalDrawer, onChanged: (v) => set((x) => x.copyWith(thermalDrawer: v))),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
            OutlinedButton.icon(key: const ValueKey('thermalTest'), onPressed: () => thermalTestNow(context, ref), icon: const Icon(Icons.receipt_long_rounded), label: Text(l.thermalTest)),
            OutlinedButton.icon(key: const ValueKey('thermalOpenDrawer'), onPressed: () => thermalTestNow(context, ref, drawerOnly: true), icon: const Icon(Icons.point_of_sale_rounded), label: Text(l.thermalOpenDrawer)),
          ]),
        ],
      ]),
    );
  }
}
