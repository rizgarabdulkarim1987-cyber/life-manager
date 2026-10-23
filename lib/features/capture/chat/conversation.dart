import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../core/text/digits.dart';
import '../../settings/settings_repository.dart';
import '../capture_pipeline.dart';
import '../data/capture_committer.dart';
import '../data/capture_repository.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';
import 'clarify.dart';
import 'describe.dart';

enum CardState { open, accepted, dropped, saved, undone }

/// One proposal the owner says OK or No to. The cards of one message are saved together.
class ProposalCard {
  const ProposalCard({
    required this.id,
    required this.captureId,
    required this.proposal,
    required this.text,
    this.state = CardState.open,
  });

  final int id;
  final int captureId;
  final Proposal proposal;
  final String text;
  final CardState state;

  ProposalCard copyWith({CardState? state}) =>
      ProposalCard(id: id, captureId: captureId, proposal: proposal, text: text, state: state ?? this.state);
}

sealed class ChatMessage {
  const ChatMessage();
}

class UserMessage extends ChatMessage {
  const UserMessage(this.text);

  final String text;
}

class AssistantMessage extends ChatMessage {
  const AssistantMessage(this.text, {this.cards = const [], this.replies = const [], this.asksFor, this.undoCaptureId});

  final String text;
  final List<ProposalCard> cards;

  /// Tappable answers to [asksFor].
  final List<QuickReply> replies;
  final AskField? asksFor;

  /// Set on the "Saved" message: Undo takes this capture back.
  final int? undoCaptureId;

  AssistantMessage copyWith({List<ProposalCard>? cards}) => AssistantMessage(
    text,
    cards: cards ?? this.cards,
    replies: replies,
    asksFor: asksFor,
    undoCaptureId: undoCaptureId,
  );
}

/// A question still waiting: which proposal of which capture, and what is missing.
class _Pending {
  const _Pending(this.captureId, this.proposals, this.index, this.field);

  final int captureId;
  final List<Proposal> proposals;
  final int index;
  final AskField field;
}

/// The chat behind the composer: the owner writes, the app shows what it
/// understood as cards, asks for what is missing, and saves only on OK.
class Conversation extends Notifier<List<ChatMessage>> {
  _Pending? _pending;
  var _nextCard = 0;

  @override
  List<ChatMessage> build() => const [];

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<(AppLocalizations, Lexicon)> _context() async {
    final s = await SettingsRepository(_db).get();
    final l = lookupAppLocalizations(Locale(s.localeCode));
    return (l, await loadLexicon(_db, l));
  }

  void _add(ChatMessage m) => state = [...state, m];

  void _replace(int i, ChatMessage m) => state = [...state]..[i] = m;

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _add(UserMessage(t));
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      final asked = state.whereType<AssistantMessage>().lastOrNull;
      final chip = asked == null ? null : matchReply(asked.replies, t);
      final filled = applyAnswer(
        pending.proposals[pending.index],
        pending.field,
        value: chip?.value,
        text: chip == null ? t : null,
      );
      // An answer that doesn't fit is a new message.
      if (filled != null) return _continue(pending, filled);
    }
    final outcome = await ref.read(capturePipelineProvider).fromText(t);
    final capture = await CaptureRepository(_db).get(outcome.captureId);
    final json = capture?.parsedJson;
    final (l, lex) = await _context();
    final proposals = [for (final p in json == null ? const <Proposal>[] : decodeProposals(json)) ?_readGuess(p, lex)];
    if (proposals.isEmpty) {
      _add(AssistantMessage(l.chatNotUnderstood));
      return;
    }
    await _askOrShow(outcome.captureId, proposals);
  }

  /// A clause the rules could only guess was a task: an expense when it names
  /// an expense category («تكسي»), otherwise not shown.
  Proposal? _readGuess(Proposal p, Lexicon lex) {
    if (p is! TaskProposal || p.confidence >= 100 || p.due != null) return p;
    final words = normalizeForMatch(p.title).split(' ');
    final category = lex.categories.where((c) => c.kind == 'expense' && c.terms.any(words.contains)).firstOrNull;
    if (category == null) return null;
    return MoneyProposal(type: IntentType.expense, confidence: 50, categoryId: category.id, description: p.title);
  }

  Future<void> answer(QuickReply reply) async {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    _add(UserMessage(reply.label));
    final filled = applyAnswer(pending.proposals[pending.index], pending.field, value: reply.value);
    if (filled != null) await _continue(pending, filled);
  }

  Future<void> _continue(_Pending pending, Proposal filled) =>
      _askOrShow(pending.captureId, [...pending.proposals]..[pending.index] = filled);

  /// Asks the first missing thing, or shows every proposal as a card.
  Future<void> _askOrShow(int captureId, List<Proposal> proposals) async {
    final (l, lex) = await _context();
    for (var i = 0; i < proposals.length; i++) {
      final c = nextClarification(proposals[i], lex);
      if (c == null) continue;
      _pending = _Pending(captureId, proposals, i, c.field);
      _add(
        AssistantMessage(
          _question(c.field, l),
          asksFor: c.field,
          replies: [for (final (label, value) in c.options) QuickReply(_chip(label, l), value)],
        ),
      );
      return;
    }
    _add(
      AssistantMessage(
        proposals.length == 1 ? '${describeProposal(proposals.single, lex, l)} ${l.chatConfirm}' : l.chatConfirm,
        cards: [
          for (final p in proposals)
            ProposalCard(id: _nextCard++, captureId: captureId, proposal: p, text: describeProposal(p, lex, l)),
        ],
      ),
    );
  }

  String _question(AskField f, AppLocalizations l) => switch (f) {
    AskField.amount => l.chatAskAmount,
    AskField.account => l.chatAskAccount,
    AskField.toAccount => l.chatAskToAccount,
    AskField.counterparty => l.chatAskCounterparty,
    AskField.direction => l.chatAskDirection,
    AskField.leg => l.chatAskLeg,
  };

  String _chip(String label, AppLocalizations l) => switch (label) {
    'owed_to_me' => l.chatOwedToMe,
    'owed_by_me' => l.chatOwedByMe,
    'principal' => l.chatNewDebt,
    'repayment' => l.chatRepayment,
    _ => label,
  };

  Future<void> accept(ProposalCard card) => _decide(card, CardState.accepted);

  Future<void> drop(ProposalCard card) => _decide(card, CardState.dropped);

  Future<void> _decide(ProposalCard card, CardState to) async {
    final i = state.indexWhere((m) => m is AssistantMessage && m.cards.any((c) => c.id == card.id));
    if (i < 0) return;
    final msg = state[i] as AssistantMessage;
    if (msg.cards.firstWhere((c) => c.id == card.id).state != CardState.open) return;
    final cards = [for (final c in msg.cards) c.id == card.id ? c.copyWith(state: to) : c];
    _replace(i, msg.copyWith(cards: cards));
    if (cards.any((c) => c.state == CardState.open)) return;

    final (l, _) = await _context();
    final accepted = cards.where((c) => c.state == CardState.accepted).toList();
    if (accepted.isEmpty) {
      await CaptureRepository(_db).discard(card.captureId);
      _add(AssistantMessage(l.chatDroppedAll));
      return;
    }
    final items = [for (final c in accepted) await _commitItem(c.proposal)];
    await CaptureCommitter(_db).commit(card.captureId, items);
    _replace(
      i,
      msg.copyWith(
        cards: [for (final c in cards) c.state == CardState.accepted ? c.copyWith(state: CardState.saved) : c],
      ),
    );
    _add(AssistantMessage(l.chatSaved, undoCaptureId: card.captureId));
  }

  Future<CommitItem> _commitItem(Proposal p) async {
    switch (p) {
      case MoneyProposal():
        return MoneyCommit(p, null);
      case TransferProposal():
        return TransferCommit(p);
      case DebtProposal():
        if (p.leg != 'repayment') return DebtCommit(p, null);
        final who = (p.counterparty ?? '').trim();
        final debt =
            await (_db.select(_db.debts)
                  ..where((d) => d.closedAt.isNull() & d.counterparty.equals(who))
                  ..limit(1))
                .getSingleOrNull();
        return debt == null ? KeepInInbox(p) : DebtCommit(p, debt.id);
      case TaskProposal() || NoteProposal():
        return KeepInInbox(p);
    }
  }

  Future<void> undo(int captureId) async {
    await CaptureCommitter(_db).undo(captureId);
    final (l, _) = await _context();
    state = [
      for (final m in state)
        if (m is AssistantMessage && m.cards.any((c) => c.captureId == captureId))
          m.copyWith(
            cards: [for (final c in m.cards) c.state == CardState.saved ? c.copyWith(state: CardState.undone) : c],
          )
        else
          m,
    ];
    _add(AssistantMessage(l.chatUndone));
  }
}

final conversationProvider = NotifierProvider<Conversation, List<ChatMessage>>(Conversation.new);
