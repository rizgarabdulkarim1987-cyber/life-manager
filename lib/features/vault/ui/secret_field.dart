import 'package:flutter/material.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';

/// A text field for a secret (plan Decision 17): hidden by default, no
/// autocorrect, no suggestions, and no keyboard learning.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.error,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.extraAction,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? error;
  final bool autofocus;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Shown before the show/hide button, e.g. "generate".
  final Widget? extraAction;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        errorText: widget.error,
        errorMaxLines: 3,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?widget.extraAction,
            IconButton(
              tooltip: _visible ? l.vltHide : l.vltReveal,
              icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ],
        ),
      ),
    );
  }
}

/// A multi-line secret (notes, recovery codes): can't be obscured, but the
/// keyboard still mustn't learn from it.
class SecretMultilineField extends StatelessWidget {
  const SecretMultilineField({super.key, required this.controller, required this.label, this.onChanged});

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    minLines: 2,
    maxLines: 8,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    keyboardType: TextInputType.multiline,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
  );
}
