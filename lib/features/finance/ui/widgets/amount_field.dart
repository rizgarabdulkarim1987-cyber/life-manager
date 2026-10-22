import 'package:flutter/material.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/money/amount_parse.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money_format.dart';
import '../ui_format.dart';

/// Minor units as plain typed text: 10000 USD → "100.00", 91700 IQD → "91700".
String minorToPlain(int minor, String currency) {
  final e = currencyExponent(currency);
  final unit = pow10(e).toInt();
  final abs = minor.abs();
  final body = e == 0 ? '$abs' : '${abs ~/ unit}.${(abs % unit).toString().padLeft(e, '0')}';
  return minor < 0 ? '-$body' : body;
}

/// A money field typed left to right in every locale. Accepts Arabic-Indic
/// digits and grouping, and says so when it had to round to the currency.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.currency,
    required this.onMinor,
    this.initialMinor,
    this.label,
    this.fieldKey,
    this.controller,
    this.readOnly = false,
    this.large = false,
    this.helper,
  });

  final String currency;
  final ValueChanged<int?> onMinor;
  final int? initialMinor;
  final String? label;
  final Key? fieldKey;

  /// Supply one when the owner computes this field's text (transfers).
  final TextEditingController? controller;
  final bool readOnly;
  final bool large;
  final String? helper;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _own = TextEditingController(
    text: widget.initialMinor == null ? '' : minorToPlain(widget.initialMinor!, widget.currency),
  );
  bool _rounded = false;

  TextEditingController get _ctl => widget.controller ?? _own;

  @override
  void didUpdateWidget(AmountField old) {
    super.didUpdateWidget(old);
    // A new currency changes the precision; re-read what is typed.
    if (old.currency != widget.currency && _ctl.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _changed(_ctl.text) : null);
    }
  }

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _changed(String s) {
    final p = s.trim().isEmpty ? null : parseDecimalToMinor(s, widget.currency);
    setState(() => _rounded = p?.rounded ?? false);
    widget.onMinor(p?.minor);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final label = currencyLabel(widget.currency, langOf(context));
    return TextField(
      key: widget.fieldKey,
      controller: _ctl,
      readOnly: widget.readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      textAlign: widget.large ? TextAlign.center : TextAlign.start,
      style: widget.large ? text.headlineMedium?.copyWith(fontWeight: FontWeight.w600) : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '0',
        suffixText: label,
        filled: widget.readOnly ? true : null,
        helperText: _rounded ? l.finAmountRounded(widget.currency) : widget.helper,
        helperMaxLines: 2,
      ),
      onChanged: widget.readOnly ? null : _changed,
    );
  }
}
