import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/lexicon.dart';
import '../domain/proposal.dart';

/// Invisible marks around each amount in a sentence, so the chat can mask the amounts of cards
/// that are no longer waiting for an OK (the owner just typed those; old ones stay hidden).
const kAmountStart = '';
const kAmountEnd = '';

/// [text] with the marks removed; the marked amounts become [mask] unless [reveal].
String maskAmounts(String text, {required bool reveal, required String mask}) =>
    text.replaceAllMapped(RegExp('$kAmountStart(.*?)$kAmountEnd'), (m) => reveal ? m[1]! : mask);

/// One plain sentence saying what saving [p] would do. [entry] is the saved
/// row an edit or delete acts on; it is named without its amount.
String describeProposal(Proposal p, Lexicon lex, AppLocalizations l, {Transaction? entry}) {
  String account(int? id) => lex.accounts.where((a) => a.id == id).firstOrNull?.name ?? '—';
  String currencyOf(int? accountId) =>
      lex.accounts.where((a) => a.id == accountId).firstOrNull?.currency ?? lex.baseCurrency;
  String money(int? minor, String currency) =>
      minor == null ? '—' : '$kAmountStart${formatMoney(Money(minor, currency), localeCode: l.localeName)}$kAmountEnd';

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
    case TaskProposal():
      final kind = switch (p.kind) {
        'appointment' => l.taskKindAppointment,
        'reminder' => l.taskKindReminder,
        _ => l.taskKindTask,
      };
      return l.chatTaskLine(kind, p.title, taskWhenText(p, l));
    case NoteProposal(:final text):
      return l.chatNoteLine(text);
    case ProjectIdeaProposal(:final title):
      return l.chatProjectLine(title);
    case DeleteProposal():
      return l.chatDeleteEntry(entryLabel(entry, lex, l));
    case EditProposal():
      final name = entryLabel(entry, lex, l);
      if (p.newAmountMinor != null) {
        return l.chatEditAmount(name, money(p.newAmountMinor, entry?.currencyCode ?? lex.baseCurrency));
      }
      if (p.newCategoryId != null) {
        return l.chatEditCategory(
          name,
          lex.categories.where((c) => c.id == p.newCategoryId).firstOrNull?.name ?? l.chatNoCategory,
        );
      }
      return l.chatEditDescription(name, p.newDescription ?? '');
  }
}

/// «24/10 17:00 · المنصور», or «no date».
String taskWhenText(TaskProposal p, AppLocalizations l) {
  final d = p.due;
  final parts = [
    if (d != null) '${d.day}/${d.month}',
    if (d != null && p.hasTime) '${d.hour}:${d.minute.toString().padLeft(2, '0')}',
    if ((p.place ?? '').isNotEmpty) p.place!,
  ];
  return parts.isEmpty ? l.chatNoDate : parts.join(' · ');
}

/// «تكسي on 22/10»: what the owner wrote, else its category.
String entryLabel(Transaction? t, Lexicon lex, AppLocalizations l) {
  if (t == null) return '—';
  final what = (t.description ?? '').trim().isNotEmpty
      ? t.description!.trim()
      : lex.categories.where((c) => c.id == t.categoryId).firstOrNull?.name ?? l.chatNoCategory;
  final d = t.occurredAt.toLocal();
  return l.chatEntryLabel(what, '${d.day}/${d.month}');
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
  'receiptKept' => l.capReason_receiptKept,
  _ => l.capReason_lowConfidence,
};
