import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';

/// One plain sentence saying what saving [p] would do.
String describeProposal(Proposal p, Lexicon lex, AppLocalizations l) {
  String account(int? id) => lex.accounts.where((a) => a.id == id).firstOrNull?.name ?? '—';
  String currencyOf(int? accountId) =>
      lex.accounts.where((a) => a.id == accountId).firstOrNull?.currency ?? lex.baseCurrency;
  String money(int? minor, String currency) =>
      minor == null ? '—' : formatMoney(Money(minor, currency), localeCode: l.localeName);

  switch (p) {
    case MoneyProposal():
      final category = lex.categories.where((c) => c.id == p.categoryId).firstOrNull?.name ?? l.chatNoCategory;
      final amount = money(p.amountMinor, p.currency ?? currencyOf(p.accountId));
      return p.type == IntentType.income
          ? l.chatIncome(amount, category, account(p.accountId))
          : l.chatExpense(amount, category, account(p.accountId));
    case TransferProposal():
      return l.chatTransfer(
        money(p.amountMinor, currencyOf(p.fromAccountId)),
        account(p.fromAccountId),
        account(p.toAccountId),
      );
    case DebtProposal():
      final who = p.counterparty ?? '—';
      final amount = money(p.amountMinor, p.currency ?? currencyOf(p.accountId));
      if (p.leg == 'repayment') return l.chatDebtRepay(who, amount);
      return p.direction == 'owed_by_me' ? l.chatDebtOwedByMe(who, amount) : l.chatDebtOwedToMe(who, amount);
    case TaskProposal(:final title):
      return l.chatLater(title);
    case NoteProposal(:final text):
      return l.chatLater(text);
  }
}

/// Why a capture waits in the Inbox, for [SavedToInbox.reasonKey].
String inboxReason(AppLocalizations l, String key) => switch (key) {
  'noSpeechEngine' => l.capReason_noSpeechEngine,
  'noSpeechOnlineOff' => l.capReason_noSpeechOnlineOff,
  'noSpeechNoKey' => l.capReason_noSpeechNoKey,
  'noSpeechNotAsked' => l.capReason_noSpeechNotAsked,
  'noSpeechDeclined' => l.capReason_noSpeechDeclined,
  'noSpeechOffline' => l.capReason_noSpeechOffline,
  'sttFailed' => l.capReason_sttFailed,
  'empty' => l.capReason_empty,
  _ => l.capReason_lowConfidence,
};
