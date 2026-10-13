import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/date_fmt.dart';
import '../core/sound.dart';
import 'effects.dart';
import '../core/responsive.dart';
import 'motion.dart';
import 'widgets.dart';

enum FieldType { text, number, money, multiline, dropdown, date, phone, email }

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.type = FieldType.text, this.options = const [], this.initial = '', this.required = false, this.hint, this.autofocus = false, this.check});
  final String key, label;
  final FieldType type;
  final List<(String, String)> options; // (value, label)
  final String initial;
  final bool required;
  final String? hint;
  final bool autofocus;

  /// Extra check for what was typed: returns a message, or null when fine. Only runs when the field is not empty.
  final String? Function(String)? check;
}

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
  late final Map<String, String> _drop = {for (final f in widget.fields.where((f) => f.type == FieldType.dropdown)) f.key: f.initial.isNotEmpty ? f.initial : (f.options.isNotEmpty ? f.options.first.$1 : '')};

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
    Navigator.pop(context, {for (final f in widget.fields) f.key: f.type == FieldType.dropdown ? (_drop[f.key] ?? '') : _ctl[f.key]!.text.trim()});
  }

  Widget _field(FieldSpec f) {
    final l = tr(context);
    String? validate(String? v) {
      if (f.required && (v == null || v.trim().isEmpty)) return l.fieldRequired;
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
      case FieldType.date:
        return TextFormField(
          controller: _ctl[f.key],
          readOnly: true,
          decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today)),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 15), lastDate: DateTime(now.year + 3), initialDate: parseDmy(_ctl[f.key]!.text) ?? now);
            if (d != null) _ctl[f.key]!.text = formatDate(d);
          },
        );
      case FieldType.multiline:
        return TextFormField(controller: _ctl[f.key], minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate);
      case FieldType.number:
      case FieldType.money:
        return TextFormField(
          controller: _ctl[f.key],
          autofocus: f.autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: f.label, hintText: f.hint, prefixText: f.type == FieldType.money ? '₹ ' : null),
          validator: validate,
        );
      case FieldType.phone:
        return TextFormField(controller: _ctl[f.key], autofocus: f.autofocus, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()\-.]'))], decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate);
      case FieldType.email:
        return TextFormField(controller: _ctl[f.key], autofocus: f.autofocus, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate);
      case FieldType.text:
        return TextFormField(controller: _ctl[f.key], autofocus: f.autofocus, decoration: InputDecoration(labelText: f.label, hintText: f.hint), validator: validate, textInputAction: TextInputAction.next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = tr(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: Shake(
        key: _shake,
        child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
              Expanded(flex: 2, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(widget.saveLabel))),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}
