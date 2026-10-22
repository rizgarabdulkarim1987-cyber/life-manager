import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/domain/ledger.dart';

Transaction t(
  String type,
  int amount, {
  int account = 1,
  int? to,
  int? toAmount,
  String status = 'paid',
  String? leg,
  int? debtId,
}) {
  final d = DateTime.utc(2026);
  return Transaction(
    id: 1,
    type: type,
    accountId: account,
    workspaceId: 1,
    amountMinor: amount,
    currencyCode: 'IQD',
    toAccountId: to,
    toAmountMinor: toAmount,
    paymentStatus: status,
    debtLeg: leg,
    debtId: debtId,
    occurredAt: d,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  test('simple types', () {
    expect(balanceEffect(t('income', 5), 1), 5);
    expect(balanceEffect(t('income', 5, status: 'pending'), 1), 0);
    expect(balanceEffect(t('expense', 5), 1), -5);
    expect(balanceEffect(t('refund', 5), 1), 5);
    expect(balanceEffect(t('adjustment', -5), 1), -5);
    expect(balanceEffect(t('expense', 5), 2), 0);
  });

  test('transfer legs', () {
    final x = t('transfer', 131000, to: 2, toAmount: 10000);
    expect(balanceEffect(x, 1), -131000);
    expect(balanceEffect(x, 2), 10000);
    expect(balanceEffect(x, 3), 0);
  });

  test('debt legs follow the debt direction', () {
    expect(balanceEffect(t('debt_payment', 9, leg: 'principal', debtId: 1), 1, debtDirection: 'owed_by_me'), 9);
    expect(balanceEffect(t('debt_payment', 9, leg: 'repayment', debtId: 1), 1, debtDirection: 'owed_by_me'), -9);
    expect(balanceEffect(t('debt_payment', 9, leg: 'principal', debtId: 1), 1, debtDirection: 'owed_to_me'), -9);
    expect(balanceEffect(t('debt_payment', 9, leg: 'repayment', debtId: 1), 1, debtDirection: 'owed_to_me'), 9);
  });
}
