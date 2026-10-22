import 'package:flutter/material.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';

/// One text field in a dialog. [parse] returns the value, or null to show
/// [invalidText]. The dialog owns its controller, so the exit animation never
/// sees a disposed one.
class TextPromptDialog<T> extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.parse,
    required this.invalidText,
    this.message,
    this.suffix,
    this.fieldKey,
    this.saveKey,
    this.numeric = false,
  });

  final String title;
  final String? message;
  final String label;
  final String? suffix;
  final T? Function(String) parse;
  final String invalidText;
  final Key? fieldKey;
  final Key? saveKey;

  /// Numbers are typed left to right even in RTL.
  final bool numeric;

  @override
  State<TextPromptDialog<T>> createState() => _TextPromptDialogState<T>();
}

class _TextPromptDialogState<T> extends State<TextPromptDialog<T>> {
  final _ctl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = widget.parse(_ctl.text);
    if (v == null) return setState(() => _error = widget.invalidText);
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: 12)],
          TextField(
            key: widget.fieldKey,
            controller: _ctl,
            autofocus: true,
            keyboardType: widget.numeric
                ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                : TextInputType.text,
            textDirection: widget.numeric ? TextDirection.ltr : null,
            decoration: InputDecoration(labelText: widget.label, suffixText: widget.suffix, errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: widget.saveKey, onPressed: _submit, child: Text(l.save)),
      ],
    );
  }
}
