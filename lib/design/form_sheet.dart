import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/date_fmt.dart';
import '../core/sound.dart';
import '../core/validators.dart';
import 'effects.dart';
import 'hotkeys.dart';
import '../core/responsive.dart';
import 'motion.dart';
import '../strings.dart';
import 'widgets.dart';

/// [choice]: two or three buttons side by side (one is always chosen); the value is the chosen option's value.
/// [combo]: a text box that also has a list to pick from (the person may pick one or type something new).
enum FieldType { text, number, money, multiline, dropdown, choice, combo, date, phone, email }

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.type = FieldType.text, this.options = const [], this.initial = '', this.required = false, this.hint, this.autofocus = false, this.check, this.kind, this.suffix, this.obscure = false, this.digits, this.percentOf, this.fills});
  final String key, label;

  /// A percent field: it is a percent of the field [percentOf] and fills the field [fills] (typing 50 with the MRP at 100 makes the price 50); typing the price or
  /// changing the MRP updates the percent. The percent itself is not saved.
  final String? percentOf, fills;
  final FieldType type;
  final List<(String, String)> options; // (value, label)
  final String initial;
  final bool required;
  final String? hint;
  final bool autofocus;

  /// Extra check for what was typed: returns a message, or null when fine. Only runs when the field is not empty.
  final String? Function(String)? check;

  /// What kind of text this is (sets the length limit and the shape check). When left out it follows the field type.
  final TextKind? kind;

  /// A button inside the field, at its end (for example "make a barcode"); it can fill the field through its controller.
  final Widget Function(TextEditingController controller)? suffix;

  /// Hide what is typed (a PIN).
  final bool obscure;

  /// Digits only, at most this many (a PIN).
  final int? digits;

  TextKind get textKind => kind ?? switch (type) { FieldType.multiline => TextKind.note, FieldType.phone => TextKind.phone, FieldType.email => TextKind.email, _ => TextKind.name };
}

/// The words for what is wrong with a text (null when nothing is).
String? textProblemMessage(Strings l, TextKind k, TextProblem? p) => switch (p) {
      null => null,
      TextProblem.tooLong => l.errTooLong(maxLength(k).toString()),
      TextProblem.badChars => l.errBadChars,
      TextProblem.notGstin => l.errGstin,
      TextProblem.notUpi => l.errUpi,
      TextProblem.notPhone => l.errPhone,
    };

/// Opens a form as a dialog (desktop / tablet) or a bottom sheet (phone). Returns the entered values, or null if cancelled.
Future<Map<String, String>?> showFormSheet(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required String saveLabel,
  String? note,
  List<Widget> extraActions = const [],
}) {
  final body = _FormBody(title: title, fields: fields, saveLabel: saveLabel, note: note);
  if (context.isPhone) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      sheetAnimationStyle: dialogStyle(context),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: body),
    );
  }
  return showDialog<Map<String, String>>(
    context: context,
    animationStyle: dialogStyle(context),
    builder: (ctx) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720), child: body)),
  );
}

class _FormBody extends StatefulWidget {
  const _FormBody({required this.title, required this.fields, required this.saveLabel, this.note});
  final String title, saveLabel;
  final String? note;
  final List<FieldSpec> fields;
  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final _formKey = GlobalKey<FormState>();
  final _shake = GlobalKey<ShakeState>();
  late final Map<String, TextEditingController> _ctl = {for (final f in widget.fields) f.key: TextEditingController(text: f.initial)};
  late final Map<String, String> _drop = {for (final f in widget.fields.where((f) => f.type == FieldType.dropdown || f.type == FieldType.choice)) f.key: f.initial.isNotEmpty ? f.initial : (f.options.isNotEmpty ? f.options.first.$1 : '')};

  bool _busyPct = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields.where((f) => f.percentOf != null && f.fills != null)) {
      final pct = _ctl[f.key]!, base = _ctl[f.percentOf!]!, tgt = _ctl[f.fills!]!;
      String pctOf(double t, double b) => (t / b * 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
      void fillTarget() {
        final b = double.tryParse(base.text), p = double.tryParse(pct.text);
        if (b == null || p == null) return;
        _busyPct = true;
        tgt.text = (b * p / 100).toStringAsFixed(2);
        _busyPct = false;
      }
      void fillPercent() {
        final b = double.tryParse(base.text), t = double.tryParse(tgt.text);
        if (b == null || b <= 0 || t == null) return;
        _busyPct = true;
        pct.text = pctOf(t, b);
        _busyPct = false;
      }
      // only a real change of the text counts (a tap into the box also notifies); each watcher remembers the text it last saw
      void watch(TextEditingController c, void Function() act) {
        var seen = c.text;
        c.addListener(() {
          if (_busyPct || seen == c.text) return;
          seen = c.text;
          act();
        });
      }
      watch(pct, fillTarget);
      watch(tgt, fillPercent);
      watch(base, () {
        if (pct.text.isNotEmpty) {
          fillTarget();
        } else {
          fillPercent();
        }
      });
      if (pct.text.isEmpty && base.text.isNotEmpty && tgt.text.isNotEmpty) fillPercent();
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shake.currentState?.shake();
      playSoundIn(context, SoundKind.error);
      return;
    }
    Navigator.pop(context, {for (final f in widget.fields) f.key: f.type == FieldType.dropdown || f.type == FieldType.choice ? (_drop[f.key] ?? '') : (f.type == FieldType.money || f.type == FieldType.number || f.type == FieldType.date ? _ctl[f.key]!.text.trim() : storeText(f.textKind, _ctl[f.key]!.text))});
  }

  Widget _field(FieldSpec f) {
    final l = tr(context);
    String? validate(String? v) {
      if (f.required && (v == null || cleanText(v, multiline: f.textKind == TextKind.note).isEmpty)) return l.fieldRequired;
      if (v != null && v.trim().isNotEmpty && f.type != FieldType.money && f.type != FieldType.number && f.type != FieldType.date) {
        final bad = textProblemMessage(l, f.textKind, checkText(f.textKind, v));
        if (bad != null) return bad;
      }
      if (f.check != null && v != null && v.trim().isNotEmpty) return f.check!(v.trim());
      return null;
    }
    switch (f.type) {
      case FieldType.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: _drop[f.key],
          decoration: InputDecoration(labelText: f.label),
          items: [for (final o in f.options) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
          onChanged: (v) => setState(() => _drop[f.key] = v ?? ''),
        );
      case FieldType.combo:
        return TextFormField(
          key: ValueKey('combo-${f.key}'),
          controller: _ctl[f.key],
          inputFormatters: [safeInput(f.textKind)],
          decoration: InputDecoration(
            labelText: f.label,
            hintText: f.hint,
            suffixIcon: f.options.isEmpty
                ? null
                : PopupMenuButton<String>(
                    key: ValueKey('combo-menu-${f.key}'),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    tooltip: f.label,
                    onSelected: (v) => setState(() => _ctl[f.key]!.text = v),
                    itemBuilder: (_) => [for (final o in f.options) PopupMenuItem(value: o.$1, child: Text(o.$2))],
                  ),
          ),
          validator: validate,
        );
      case FieldType.choice:
        return Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            key: ValueKey('choice-${f.key}'),
            showSelectedIcon: false,
            segments: [for (final o in f.options) ButtonSegment(value: o.$1, label: Text(o.$2))],
            selected: {_drop[f.key] ?? ''},
            onSelectionChanged: (v) => setState(() => _drop[f.key] = v.first),
          ),
        );
      case FieldType.date:
        return TextFormField(
          controller: _ctl[f.key],
          readOnly: true,
          decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today_rounded)),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 15), lastDate: DateTime(now.year + 3), initialDate: parseDmy(_ctl[f.key]!.text) ?? now);
            if (d != null) _ctl[f.key]!.text = formatDate(d);
          },
        );
      case FieldType.multiline:
        return TextFormField(controller: _ctl[f.key], minLines: 2, maxLines: 4, inputFormatters: [safeInput(f.textKind)], decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate);
      case FieldType.number:
      case FieldType.money:
        return TextFormField(
          controller: _ctl[f.key],
          autofocus: f.autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: f.label, hintText: f.hint, prefixText: f.type == FieldType.money && f.percentOf == null ? '₹ ' : null, suffixText: f.percentOf != null ? '%' : null),
          validator: validate,
        );
      case FieldType.phone:
        return TextFormField(controller: _ctl[f.key], autofocus: f.autofocus, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()\-.]'))], decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate);
      case FieldType.email:
        return TextFormField(controller: _ctl[f.key], autofocus: f.autofocus, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate);
      case FieldType.text:
        return TextFormField(controller: _ctl[f.key], autofocus: f.autofocus, obscureText: f.obscure, keyboardType: f.digits != null ? TextInputType.number : null, inputFormatters: f.digits != null ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(f.digits)] : [safeInput(f.textKind)], decoration: InputDecoration(labelText: f.label, hintText: f.hint, suffixIcon: f.suffix?.call(_ctl[f.key]!)), validator: validate, textInputAction: TextInputAction.next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: enterSaves(_save),
        child: Shake(
        key: _shake,
        child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(children: [
                if (widget.note != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.note!, style: Theme.of(context).textTheme.bodySmall)),
                for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(f)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: Text(widget.saveLabel))),
            ]),
          ),
        ]),
      ),
      ),
      ),
    );
  }
}
