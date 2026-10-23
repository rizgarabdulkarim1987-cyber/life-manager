import '../../../core/db/app_database.dart';

/// How one transaction moves the balance of [accountId], in that account's
/// minor units. This is the reference the SQL balance query mirrors.
/// [debtDirection] is required for `debt_payment` rows.
int balanceEffect(Transaction t, int accountId, {String? debtDirection}) {
  var effect = 0;
  if (t.accountId == accountId) {
    effect += switch (t.type) {
      'income' => t.paymentStatus == 'paid' ? t.amountMinor : 0,
      'expense' => -t.amountMinor,
      'refund' || 'adjustment' => t.amountMinor,
      'transfer' => -t.amountMinor,
      'debt_payment' => _debtSign(t, debtDirection) * t.amountMinor,
      _ => throw StateError('unknown transaction type'),
    };
  }
  if (t.type == 'transfer' && t.toAccountId == accountId) effect += t.toAmountMinor!;
  return effect;
}

/// Borrowed money (owed by me) comes in as principal and goes out as
/// repayment; lent money is the reverse. Neither is income or expense.
int _debtSign(Transaction t, String? direction) {
  if (direction == null) throw StateError('debt direction required');
  final inflow = (direction == 'owed_by_me') == (t.debtLeg == 'principal');
  return inflow ? 1 : -1;
}
