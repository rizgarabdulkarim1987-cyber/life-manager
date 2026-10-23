import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/security/money_privacy.dart';
import '../chat/conversation.dart';
import '../chat/describe.dart' show maskAmounts;
import 'composer.dart';

/// Which navigators already show the sheet, so a second send doesn't stack another.
final _openOn = Expando<bool>();

/// The conversation with the assistant, over whichever tab the owner is on.
Future<void> openChatSheet(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  if (_openOn[nav] ?? false) return;
  _openOn[nav] = true;
  try {
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ChatSheet(),
    );
  } finally {
    _openOn[nav] = null;
  }
}

class _ChatSheet extends StatelessWidget {
  const _ChatSheet();

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: DraggableScrollableSheet(
        key: const ValueKey('chat-sheet'),
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            Expanded(child: _Messages(scroll: scroll)),
            const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 16), child: Composer(inSheet: true)),
          ],
        ),
      ),
    );
  }
}

class _Messages extends ConsumerWidget {
  const _Messages({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(conversationProvider);
    final l = context.l10n;
    final k = context.tokens;
    if (messages.isEmpty) {
      return ListView(
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l.chatEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: k.textMuted),
          ),
        ],
      );
    }
    // Newest at the bottom, next to the composer.
    final items = messages.reversed.toList();
    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: items.length,
      itemBuilder: (context, i) => switch (items[i]) {
        UserMessage(:final text) => _UserBubble(text),
        final AssistantMessage m => _AssistantBubble(m),
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 48, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: k.accent, borderRadius: BorderRadius.circular(18)),
        child: Text(text, style: TextStyle(color: k.onAccent)),
      ),
    );
  }
}

class _AssistantBubble extends ConsumerWidget {
  const _AssistantBubble(this.m);

  final AssistantMessage m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final l = context.l10n;
    final chat = ref.read(conversationProvider.notifier);
    final text = Theme.of(context).textTheme;
    // A single card already carries the sentence; the bubble only asks.
    final showText = m.cards.length != 1;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 32, top: 6, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showText || m.cards.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: k.surfaceHigh, borderRadius: BorderRadius.circular(18)),
                child: Text(
                  maskAmounts(
                    m.text,
                    reveal:
                        moneyShownOf(ref) ||
                        m.cards.any((c) => c.state == CardState.open || c.state == CardState.accepted),
                    mask: kMaskedMoney,
                  ),
                  style: text.bodyLarge,
                ),
              ),
            for (final c in m.cards) _Card(card: c, single: m.cards.length == 1, confirm: l.chatConfirm),
            if (m.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, r) in m.replies.indexed)
                      ActionChip(key: ValueKey('reply-$i'), label: Text(r.label), onPressed: () => chat.answer(r)),
                  ],
                ),
              ),
            if (m.openProjectId != null)
              TextButton.icon(
                key: ValueKey('open-project-${m.openProjectId}'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/projects/${m.openProjectId}');
                },
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: Text(l.chatOpenProject),
              ),
            if (m.undoCaptureId != null)
              TextButton.icon(
                key: ValueKey('undo-${m.undoCaptureId}'),
                onPressed: () => chat.undo(m.undoCaptureId!),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(l.chatUndo),
              ),
          ],
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.card, required this.single, required this.confirm});

  final ProposalCard card;
  final bool single;
  final String confirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final chat = ref.read(conversationProvider.notifier);
    final i = card.id;
    final status = switch (card.state) {
      CardState.open || CardState.accepted => null,
      CardState.saved => (Icons.check_circle_rounded, l.chatStateSaved, k.success),
      CardState.dropped => (Icons.remove_circle_outline_rounded, l.chatStateDropped, k.textMuted),
      CardState.undone => (Icons.undo_rounded, l.chatStateUndone, k.textMuted),
      CardState.edited => (Icons.edit_note_rounded, l.chatStateEdited, k.textMuted),
    };
    return Container(
      key: ValueKey('card-$i'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: card.state == CardState.accepted ? k.accent : k.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            maskAmounts(
              card.text,
              reveal: moneyShownOf(ref) || card.state == CardState.open || card.state == CardState.accepted,
              mask: kMaskedMoney,
            ),
            style: text.bodyLarge,
          ),
          const SizedBox(height: 10),
          if (status != null)
            Row(
              children: [
                Icon(status.$1, size: 18, color: status.$3),
                const SizedBox(width: 6),
                Text(status.$2, style: text.labelLarge?.copyWith(color: status.$3)),
              ],
            )
          else if (card.state == CardState.accepted)
            Row(
              children: [
                Icon(Icons.check_rounded, size: 18, color: k.accent),
                const SizedBox(width: 6),
                Text(l.chatOk, style: text.labelLarge?.copyWith(color: k.accent)),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(key: ValueKey('card-ok-$i'), onPressed: () => chat.accept(card), child: Text(l.chatOk)),
                OutlinedButton(
                  key: ValueKey('card-edit-$i'),
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    final id = await chat.edit(card);
                    if (id != null) {
                      router.push('/capture/$id');
                    }
                  },
                  child: Text(l.chatEdit),
                ),
                TextButton(key: ValueKey('card-drop-$i'), onPressed: () => chat.drop(card), child: Text(l.chatDrop)),
              ],
            ),
        ],
      ),
    );
  }
}
