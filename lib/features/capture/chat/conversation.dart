import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../core/text/digits.dart';
import '../../finance/data/accounts_repository.dart';
import '../../finance/data/categories_repository.dart';
import '../../finance/data/rates_repository.dart';
import '../../finance/ui/ui_format.dart' show formatRateE6;
import '../../finance/data/transactions_repository.dart';
import '../../settings/settings_repository.dart';
import '../capture_pipeline.dart';
import '../data/capture_committer.dart';
import '../data/capture_repository.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';
import 'clarify.dart';
import 'describe.dart';
import 'targets.dart';

enum CardState { open, accepted, dropped, saved, undone, edited }

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
      final filled = await _apply(pending, value: chip?.value, text: chip == null ? t : null);
      // An answer that doesn't fit is a new message.
      if (filled != null) return _continue(pending, filled);
    }
    await _handle(await ref.read(capturePipelineProvider).fromText(t));
  }

  /// A voice note: the transcript shows as the owner's bubble, then the same flow as text.
  Future<void> sendVoice(Uint8List wav) async {
    _pending = null;
    final outcome = await ref.read(capturePipelineProvider).fromVoice(wav);
    final capture = await CaptureRepository(_db).get(outcome.captureId);
    final heard = capture?.transcript?.trim() ?? '';
    if (heard.isNotEmpty) _add(UserMessage(heard));
    if (outcome is SavedToInbox && heard.isEmpty) {
      final (l, _) = await _context();
      _add(AssistantMessage(l.chatVoiceKept(inboxReason(l, outcome.reasonKey))));
      return;
    }
    await _handle(outcome);
  }

  /// A receipt photo: read online, then the same OK/No cards as text.
  Future<void> sendImage(Uint8List jpeg) async {
    _pending = null;
    final (l, _) = await _context();
    _add(UserMessage(l.chatReceiptSent));
    final outcome = await ref.read(capturePipelineProvider).fromImage(jpeg);
    if (outcome is SavedToInbox) {
      _add(AssistantMessage(l.chatReceiptKept(inboxReason(l, outcome.reasonKey))));
      return;
    }
    await _handle(outcome);
  }

  Future<void> _handle(CaptureOutcome outcome) async {
    final capture = await CaptureRepository(_db).get(outcome.captureId);
    final json = capture?.parsedJson;
    final (l, lex) = await _context();
    final proposals = <Proposal>[];
    for (final p in json == null ? const <Proposal>[] : decodeProposals(json)) {
      final read = _readGuess(p, lex);
      if (read == null) continue;
      final found = await _withEntry(read, lex);
      if (found == null) {
        _add(AssistantMessage(l.chatNoEntry));
        return;
      }
      proposals.add(found);
    }
    if (proposals.isEmpty) {
      _add(AssistantMessage(l.chatNotUnderstood));
      return;
    }
    await _askOrShow(outcome.captureId, proposals);
  }

  /// Edits and deletes get the row they mean; null when there is none.
  Future<Proposal?> _withEntry(Proposal p, Lexicon lex) async {
    switch (p) {
      case EditProposal(txId: null):
        final t = await resolveTarget(_db, p.target, lex);
        return t == null ? null : p.copyWith(txId: t.id);
      case DeleteProposal(txId: null):
        final t = await resolveTarget(_db, p.target, lex);
        return t == null ? null : p.copyWith(txId: t.id);
      default:
        return p;
    }
  }

  Future<Transaction?> _entryOf(Proposal p) async {
    final id = switch (p) {
      EditProposal(:final txId) || DeleteProposal(:final txId) => txId,
      _ => null,
    };
    return id == null ? null : TransactionsRepository(_db).get(id);
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
    final filled = await _apply(pending, value: reply.value);
    if (filled != null) await _continue(pending, filled);
  }

  /// Fills the pending question. Making a category or account happens here,
  /// on the owner's yes; everything else is [applyAnswer].
  Future<Proposal?> _apply(_Pending pending, {Object? value, String? text}) async {
    final p = pending.proposals[pending.index];
    switch ((pending.field, p)) {
      case (AskField.createCategory, final MoneyProposal m) when value == true:
        final id = await CategoriesRepository(_db)
            .create(kind: m.type == IntentType.income ? 'income' : 'expense', name: m.newCategoryName!);
        return m.copyWith(categoryId: id);
      case (AskField.createAccount, _) when value is String:
        final (l, lex) = await _context();
        final named = p is MoneyProposal ? p.newAccountName : null;
        final id = await AccountsRepository(_db).create(
          workspaceId: lex.personalWorkspaceId,
          name: (named ?? '').isNotEmpty ? named! : l.chatDefaultAccountName(value),
          kind: 'cash',
          currencyCode: value,
        );
        return switch (p) {
          MoneyProposal() => p.copyWith(accountId: id, currency: value),
          DebtProposal() => p.copyWith(accountId: id),
          _ => p,
        };
      case (AskField.rate, final MoneyProposal m):
        var rate = value is int ? value : (text == null ? null : parseRateE6(text));
        if (rate == null) return null;
        // «132000» is what 100 dollars cost, as the exchange shops quote it.
        if (rate > 10000 * 1000000) rate ~/= 100;
        final (from, base) = await _currencies(m);
        await RatesRepository(_db).setRate(base: from, quote: base, rateE6: rate, effectiveFrom: _today());
        return m;
      default:
        return applyAnswer(p, pending.field, value: value, text: text);
    }
  }

  Future<void> _continue(_Pending pending, Proposal filled) =>
      _askOrShow(pending.captureId, [...pending.proposals]..[pending.index] = filled);

  /// Asks the first missing thing, or shows every proposal as a card.
  Future<void> _askOrShow(int captureId, List<Proposal> proposals) async {
    final (l, lex) = await _context();
    for (var i = 0; i < proposals.length; i++) {
      final c = nextClarification(proposals[i], lex) ?? await _rateQuestion(proposals[i]);
      if (c == null) continue;
      _pending = _Pending(captureId, proposals, i, c.field);
      _add(
        AssistantMessage(
          _question(c.field, l, proposals[i]),
          asksFor: c.field,
          replies: [for (final (label, value) in c.options) QuickReply(_chip(label, l), value)],
        ),
      );
      return;
    }
    final texts = [for (final p in proposals) describeProposal(p, lex, l, entry: await _entryOf(p))];
    _add(
      AssistantMessage(
        proposals.length == 1 ? '${texts.single} ${l.chatConfirm}' : l.chatConfirm,
        cards: [
          for (final (i, p) in proposals.indexed)
            ProposalCard(id: _nextCard++, captureId: captureId, proposal: p, text: texts[i]),
        ],
      ),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// The proposal's account currency and the base currency.
  Future<(String, String)> _currencies(MoneyProposal p) async {
    final base = (await SettingsRepository(_db).get()).baseCurrency;
    final from = p.accountId == null
        ? (p.currency ?? base)
        : (await AccountsRepository(_db).get(p.accountId!)).currencyCode;
    return (from, base);
  }

  /// Redesign §11.2: an income in another currency asks today's rate once a
  /// day, offering the last one, so the split into buckets can be made.
  Future<Clarification?> _rateQuestion(Proposal p) async {
    if (p is! MoneyProposal || p.type != IntentType.income || p.accountId == null) return null;
    final (from, base) = await _currencies(p);
    if (from == base) return null;
    final last = await RatesRepository(_db).rateOn(from, base, _today());
    if (last != null && last.effectiveFrom.isAtSameMomentAs(_today())) return null;
    final offer = last != null && last.base == from ? last.rateE6 : null;
    return Clarification(AskField.rate, [if (offer != null) (formatRateE6(offer), offer)]);
  }

  String _question(AskField f, AppLocalizations l, Proposal proposal) => switch (f) {
    AskField.amount => l.chatAskAmount,
    AskField.account => l.chatAskAccount,
    AskField.toAccount => l.chatAskToAccount,
    AskField.counterparty => l.chatAskCounterparty,
    AskField.direction => l.chatAskDirection,
    AskField.leg => l.chatAskLeg,
    AskField.newAmount => l.chatAskNewAmount,
    AskField.createAccount => l.chatAskCreateAccount,
    AskField.rate => l.chatAskRate(switch (proposal) {
      MoneyProposal(:final currency) => currency ?? 'USD',
      _ => 'USD',
    }),
    AskField.createCategory => l.chatAskCreateCategory(switch (proposal) {
      MoneyProposal(:final newCategoryName) => newCategoryName ?? '',
      _ => '',
    }),
  };

  String _chip(String label, AppLocalizations l) => switch (label) {
    'owed_to_me' => l.chatOwedToMe,
    'owed_by_me' => l.chatOwedByMe,
    'principal' => l.chatNewDebt,
    'repayment' => l.chatRepayment,
    'yes' => l.chatYesCreate,
    'no' => l.chatNoThanks,
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
      case EditProposal():
        return EditCommit(p);
      case DeleteProposal():
        return DeleteCommit(p);
      case TaskProposal() || NoteProposal():
        return KeepInInbox(p);
    }
  }

  /// Hands the message's cards to the full review form: what the chat filled
  /// in is written to the capture first. Returns the capture to open.
  Future<int?> edit(ProposalCard card) async {
    final i = state.indexWhere((m) => m is AssistantMessage && m.cards.any((c) => c.id == card.id));
    if (i < 0) return null;
    final msg = state[i] as AssistantMessage;
    if (msg.cards.any((c) => c.state != CardState.open && c.state != CardState.accepted)) return null;
    final capture = await CaptureRepository(_db).get(card.captureId);
    if (capture == null || capture.status != 'pending') return null;
    await CaptureRepository(_db)
        .setParsed(card.captureId, [for (final c in msg.cards) c.proposal], by: capture.parsedBy ?? 'rules');
    _replace(i, msg.copyWith(cards: [for (final c in msg.cards) c.copyWith(state: CardState.edited)]));
    return card.captureId;
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
