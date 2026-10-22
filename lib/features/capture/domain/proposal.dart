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
