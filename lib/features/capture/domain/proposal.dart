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

enum IntentType { expense, income, transfer, task, debtPayment, note, edit, delete, projectIdea }

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
    this.newCategoryName,
    this.newAccountName,
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

  /// A category or account the owner named that does not exist yet; the chat offers to make it.
  final String? newCategoryName;
  final String? newAccountName;

  MoneyProposal copyWith({
    int? amountMinor,
    String? currency,
    int? accountId,
    int? categoryId,
    bool dropNewCategory = false,
    bool dropNewAccount = false,
  }) => MoneyProposal(
    type: type,
    confidence: confidence,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    accountId: accountId ?? this.accountId,
    workspaceId: workspaceId,
    categoryId: categoryId ?? this.categoryId,
    occurredAt: occurredAt,
    description: description,
    bucketTag: bucketTag,
    newCategoryName: dropNewCategory || categoryId != null ? null : newCategoryName,
    newAccountName: dropNewAccount || accountId != null ? null : newAccountName,
  );

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

  TransferProposal copyWith({int? fromAccountId, int? toAccountId, int? amountMinor}) => TransferProposal(
    confidence: confidence,
    fromAccountId: fromAccountId ?? this.fromAccountId,
    toAccountId: toAccountId ?? this.toAccountId,
    amountMinor: amountMinor ?? this.amountMinor,
    toAmountMinor: toAmountMinor ?? (amountMinor ?? this.amountMinor),
    rateE6: rateE6,
    transferKind: transferKind,
    occurredAt: occurredAt,
  );

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

  DebtProposal copyWith({String? counterparty, String? direction, String? leg, int? amountMinor, int? accountId}) =>
      DebtProposal(
        confidence: confidence,
        counterparty: counterparty ?? this.counterparty,
        direction: direction ?? this.direction,
        leg: leg ?? this.leg,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency,
        accountId: accountId ?? this.accountId,
        occurredAt: occurredAt,
      );
}

class TaskProposal extends Proposal {
  const TaskProposal({
    required this.title,
    required this.confidence,
    this.due,
    this.workspaceId,
    this.kind = 'task',
    this.place,
    this.hasTime = false,
  });

  @override
  IntentType get type => IntentType.task;
  @override
  final int confidence;
  final String title;
  final DateTime? due;
  final int? workspaceId;

  /// `task`, `reminder` or `appointment`.
  final String kind;
  final String? place;

  /// Whether [due] carries a time of day, not just a date.
  final bool hasTime;
}

/// «عندي فكرة مشروع …»: becomes a project the planner chat then works on.
class ProjectIdeaProposal extends Proposal {
  const ProjectIdeaProposal({required this.title, this.description});

  @override
  IntentType get type => IntentType.projectIdea;
  @override
  int get confidence => 100;
  final String title;
  final String? description;
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

/// Which saved entry «edit» and «delete» mean: `last`, `last_expense`,
/// `last_income`, or words found in its description or category.
const kTargetLast = 'last';

/// «غير المبلغ لـ 30 الف»: changes one saved income or expense. [txId] is
/// picked by the chat from [target] before the card is shown.
class EditProposal extends Proposal {
  const EditProposal({
    required this.confidence,
    this.target = kTargetLast,
    this.txId,
    this.newAmountMinor,
    this.newCategoryId,
    this.newDescription,
  });

  @override
  IntentType get type => IntentType.edit;
  @override
  final int confidence;
  final String target;
  final int? txId;
  final int? newAmountMinor;
  final int? newCategoryId;
  final String? newDescription;

  bool get changesNothing => newAmountMinor == null && newCategoryId == null && newDescription == null;

  EditProposal copyWith({int? txId, int? newAmountMinor}) => EditProposal(
    confidence: confidence,
    target: target,
    txId: txId ?? this.txId,
    newAmountMinor: newAmountMinor ?? this.newAmountMinor,
    newCategoryId: newCategoryId,
    newDescription: newDescription,
  );
}

/// «احذف آخر مصروف»: deletes one saved income or expense.
class DeleteProposal extends Proposal {
  const DeleteProposal({required this.confidence, this.target = kTargetLast, this.txId});

  @override
  IntentType get type => IntentType.delete;
  @override
  final int confidence;
  final String target;
  final int? txId;

  DeleteProposal copyWith({int? txId}) =>
      DeleteProposal(confidence: confidence, target: target, txId: txId ?? this.txId);
}
