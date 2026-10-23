/// Pre-fill for the transaction form ("+" shortcuts, Capture Review).
/// Every field is optional; the form fills the rest with its defaults.
class TransactionDraft {
  const TransactionDraft({
    this.type,
    this.accountId,
    this.amountMinor,
    this.categoryId,
    this.occurredAt,
    this.description,
    this.bucketTag,
  });

  /// `income`, `expense` or `refund`.
  final String? type;
  final int? accountId;
  final int? amountMinor;
  final int? categoryId;
  final DateTime? occurredAt;
  final String? description;
  final String? bucketTag;
}

/// Pre-fill for the transfer form.
class TransferDraft {
  const TransferDraft({
    this.fromAccountId,
    this.toAccountId,
    this.amountMinor,
    this.toAmountMinor,
    this.rateE6,
    this.transferKind,
  });

  final int? fromAccountId;
  final int? toAccountId;
  final int? amountMinor;
  final int? toAmountMinor;
  final int? rateE6;

  /// `transfer` or `owner_draw`.
  final String? transferKind;
}

enum IntentType { expense, income, transfer, task, debtPayment, note }

/// Below this the review screen asks the owner to check the proposal.
const kLowConfidence = 60;

/// One thing the owner said, as the parser understood it. Nothing is saved
/// until the owner confirms it in Capture Review.
sealed class Proposal {
  const Proposal();

  IntentType get type;

  /// 0–100.
  int get confidence;
}

class MoneyProposal extends Proposal {
  const MoneyProposal({
    required this.type,
    required this.confidence,
    this.amountMinor,
    this.currency,
    this.accountId,
    this.workspaceId,
    this.categoryId,
    this.occurredAt,
    this.description,
    this.bucketTag,
  });

  /// [IntentType.expense] or [IntentType.income].
  @override
  final IntentType type;
  @override
  final int confidence;
  final int? amountMinor;
  final String? currency;
  final int? accountId;
  final int? workspaceId;
  final int? categoryId;
  final DateTime? occurredAt;
  final String? description;
  final String? bucketTag;

  TransactionDraft toTransactionDraft() => TransactionDraft(
    type: type == IntentType.income ? 'income' : 'expense',
    accountId: accountId,
    amountMinor: amountMinor,
    categoryId: categoryId,
    occurredAt: occurredAt,
    description: description,
    bucketTag: type == IntentType.expense ? bucketTag : null,
  );
}

class TransferProposal extends Proposal {
  const TransferProposal({
    required this.confidence,
    this.fromAccountId,
    this.toAccountId,
    this.amountMinor,
    this.toAmountMinor,
    this.rateE6,
    this.transferKind,
    this.occurredAt,
  });

  @override
  IntentType get type => IntentType.transfer;
  @override
  final int confidence;
  final int? fromAccountId;
  final int? toAccountId;
  final int? amountMinor;
  final int? toAmountMinor;
  final int? rateE6;
  final String? transferKind;
  final DateTime? occurredAt;

  TransferDraft toTransferDraft() => TransferDraft(
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amountMinor: amountMinor,
    toAmountMinor: toAmountMinor,
    rateE6: rateE6,
    transferKind: transferKind,
  );
}

class DebtProposal extends Proposal {
  const DebtProposal({
    required this.confidence,
    this.counterparty,
    this.direction,
    this.leg,
    this.amountMinor,
    this.currency,
    this.accountId,
    this.occurredAt,
  });

  @override
  IntentType get type => IntentType.debtPayment;
  @override
  final int confidence;
  final String? counterparty;

  /// `owed_to_me` or `owed_by_me`.
  final String? direction;

  /// `principal` or `repayment`.
  final String? leg;
  final int? amountMinor;
  final String? currency;
  final int? accountId;
  final DateTime? occurredAt;
}

class TaskProposal extends Proposal {
  const TaskProposal({required this.title, required this.confidence, this.due, this.workspaceId});

  @override
  IntentType get type => IntentType.task;
  @override
  final int confidence;
  final String title;
  final DateTime? due;
  final int? workspaceId;
}

class NoteProposal extends Proposal {
  const NoteProposal({required this.text, this.workspaceId});

  @override
  IntentType get type => IntentType.note;
  @override
  int get confidence => 100;
  final String text;
  final int? workspaceId;
}
