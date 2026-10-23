import '../../../core/money/amount_parse.dart';
import '../../../core/text/digits.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';

/// The one thing the chat asks before a proposal can be saved.
enum AskField {
  amount,
  account,
  toAccount,
  counterparty,
  direction,
  leg,
  newAmount,
  createAccount,
  createCategory,
  rate,
}

/// A tappable answer. [value] is an id, a code or a sentinel the controller understands.
class QuickReply {
  const QuickReply(this.label, this.value);

  final String label;
  final Object value;

  @override
  String toString() => 'QuickReply($label)';
}

class Clarification {
  const Clarification(this.field, [this.options = const []]);

  final AskField field;

  /// Empty when the answer is typed (an amount, a name).
  final List<(String label, Object value)> options;
}

/// Currencies the first account can use.
const kCurrencyChoices = [('IQD', 'IQD'), ('USD', 'USD')];

/// What is still missing for [p] to be saved, most important first.
/// Category is optional, so it is never asked.
Clarification? nextClarification(Proposal p, Lexicon lex) {
  List<(String, Object)> accounts({String? currency}) => [
    for (final a in lex.accounts)
      if (currency == null || a.currency == currency) (a.name, a.id),
  ];
  switch (p) {
    case MoneyProposal():
      if (p.amountMinor == null) return const Clarification(AskField.amount);
      if (p.accountId == null) {
        final options = accounts(currency: p.currency);
        // Nothing to pick from (or the owner named a new one): offer to make it.
        if (options.isEmpty || (p.newAccountName != null && lex.accounts.isEmpty)) {
          return const Clarification(AskField.createAccount, kCurrencyChoices);
        }
        return Clarification(AskField.account, options);
      }
      if (p.categoryId == null && (p.newCategoryName ?? '').isNotEmpty) {
        return const Clarification(AskField.createCategory, [('yes', true), ('no', false)]);
      }
    case TransferProposal():
      if (p.amountMinor == null) return const Clarification(AskField.amount);
      if (p.fromAccountId == null) return Clarification(AskField.account, accounts());
      if (p.toAccountId == null) {
        return Clarification(AskField.toAccount, [
          for (final a in accounts())
            if (a.$2 != p.fromAccountId) a,
        ]);
      }
    case DebtProposal():
      if ((p.counterparty ?? '').trim().isEmpty) return const Clarification(AskField.counterparty);
      if (p.leg == null) {
        return const Clarification(AskField.leg, [('principal', 'principal'), ('repayment', 'repayment')]);
      }
      if (p.direction == null && p.leg == 'principal') {
        return const Clarification(AskField.direction, [('owed_to_me', 'owed_to_me'), ('owed_by_me', 'owed_by_me')]);
      }
      if (p.amountMinor == null) return const Clarification(AskField.amount);
      if (p.accountId == null) {
        final options = accounts(currency: p.currency);
        if (options.isEmpty) return const Clarification(AskField.createAccount, kCurrencyChoices);
        return Clarification(AskField.account, options);
      }
    case EditProposal():
      if (p.changesNothing) return const Clarification(AskField.newAmount);
    case TaskProposal() || NoteProposal() || DeleteProposal() || ProjectIdeaProposal():
      break;
  }
  return null;
}

/// Fills [field] of [p] with a tapped [value] or typed [text]. Null when the
/// typed text doesn't answer the question (the chat then treats it as new).
Proposal? applyAnswer(Proposal p, AskField field, {Object? value, String? text}) {
  int? amount(String currency) {
    final t = text?.trim();
    if (t == null || t.isEmpty) return null;
    final parsed = parseDecimalToMinor(t, currency);
    return parsed == null || parsed.minor <= 0 ? null : parsed.minor;
  }

  switch (field) {
    case AskField.amount:
      final currency = switch (p) {
        MoneyProposal(:final currency) || DebtProposal(:final currency) => currency ?? 'IQD',
        _ => 'IQD',
      };
      final minor = value is int ? value : amount(currency);
      if (minor == null) return null;
      return switch (p) {
        MoneyProposal() => p.copyWith(amountMinor: minor),
        TransferProposal() => p.copyWith(amountMinor: minor),
        DebtProposal() => p.copyWith(amountMinor: minor),
        _ => p,
      };
    // Made in the database by the chat; here only "no" can be answered.
    case AskField.createCategory:
      if (value != false || p is! MoneyProposal) return null;
      return p.copyWith(dropNewCategory: true);
    case AskField.createAccount || AskField.rate:
      return null;
    case AskField.newAmount:
      if (p is! EditProposal) return null;
      final minor = value is int ? value : amount('IQD');
      return minor == null ? null : p.copyWith(newAmountMinor: minor);
    case AskField.account || AskField.toAccount:
      if (value is! int) return null;
      return switch (p) {
        MoneyProposal() => p.copyWith(accountId: value),
        TransferProposal() when field == AskField.toAccount => p.copyWith(toAccountId: value),
        TransferProposal() => p.copyWith(fromAccountId: value),
        DebtProposal() => p.copyWith(accountId: value),
        _ => p,
      };
    case AskField.counterparty:
      final name = text?.trim() ?? '';
      if (name.isEmpty || name.length > 80 || p is! DebtProposal) return null;
      return p.copyWith(counterparty: name);
    case AskField.direction:
      if (value is! String || p is! DebtProposal) return null;
      return p.copyWith(direction: value);
    case AskField.leg:
      if (value is! String || p is! DebtProposal) return null;
      return p.copyWith(leg: value);
  }
}

/// A chip whose label matches what the owner typed, ignoring letter variants.
QuickReply? matchReply(List<QuickReply> replies, String typed) {
  final t = normalizeForMatch(typed.trim());
  if (t.isEmpty) return null;
  return replies.where((r) => normalizeForMatch(r.label) == t).firstOrNull ??
      replies.where((r) => normalizeForMatch(r.label).contains(t)).firstOrNull;
}
