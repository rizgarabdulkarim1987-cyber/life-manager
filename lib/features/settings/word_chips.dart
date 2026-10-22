import 'package:flutter/material.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';

/// Editable words as chips: type one, add it, remove any with its ✕.
/// [fixed] words are shown first and cannot be removed.
class WordChips extends StatefulWidget {
  const WordChips({
    super.key,
    required this.words,
    required this.onChanged,
    required this.inputLabel,
    required this.inputKey,
    required this.addKey,
    this.fixed = const [],
    this.fixedLabel,
    this.wordsLabel,
  });

  final List<String> words;
  final ValueChanged<List<String>> onChanged;
  final String inputLabel;
  final Key inputKey;
  final Key addKey;
  final List<String> fixed;
  final String? fixedLabel;
  final String? wordsLabel;

  @override
  State<WordChips> createState() => _WordChipsState();
}

class _WordChipsState extends State<WordChips> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final w = _input.text.trim().replaceAll(',', ' ');
    if (w.isEmpty) return;
    if (!widget.words.contains(w)) widget.onChanged([...widget.words, w]);
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final label = Theme.of(context).textTheme.labelMedium?.copyWith(color: k.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.fixed.isNotEmpty) ...[
          if (widget.fixedLabel != null) Text(widget.fixedLabel!, style: label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in widget.fixed)
                Chip(
                  label: Text(w),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: k.surfaceHigh,
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (widget.wordsLabel != null && widget.words.isNotEmpty) ...[
          Text(widget.wordsLabel!, style: label),
          const SizedBox(height: 6),
        ],
        if (widget.words.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in widget.words)
                InputChip(
                  key: ValueKey('word-$w'),
                  label: Text(w),
                  deleteButtonTooltipMessage: l.setRemoveWord(w),
                  onDeleted: () => widget.onChanged([...widget.words]..remove(w)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: widget.inputKey,
                controller: _input,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: widget.inputLabel, counterText: ''),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filledTonal(
                key: widget.addKey,
                tooltip: widget.inputLabel,
                onPressed: _input.text.trim().isEmpty ? null : _add,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
