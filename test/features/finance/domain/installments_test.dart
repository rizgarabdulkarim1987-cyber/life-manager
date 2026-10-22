import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/domain/installments.dart';

void main() {
  test(
    'equalInstallments 1,000,000 / 3 from 2027-01-31 → 333333, 333333, 333334 on 2027-01-31, 2027-02-28, 2027-03-31',
    () {
      final s = equalInstallments(totalMinor: 1000000, count: 3, firstDue: DateTime.utc(2027, 1, 31));
      expect(s.map((x) => x.$2), [333333, 333333, 333334]);
      expect(s.map((x) => x.$1), [DateTime.utc(2027, 1, 31), DateTime.utc(2027, 2, 28), DateTime.utc(2027, 3, 31)]);
    },
  );

  test('equalInstallments rejects a count of 0 or more than the total', () {
    expect(() => equalInstallments(totalMinor: 10, count: 0, firstDue: DateTime.utc(2027)), throwsArgumentError);
    expect(() => equalInstallments(totalMinor: 2, count: 3, firstDue: DateTime.utc(2027)), throwsArgumentError);
  });

  test('applyPayments 400000 marks #1 paid, #2 partly paid', () {
    final schedule = [
      for (var i = 0; i < 3; i++)
        Installment(id: i + 1, debtId: 1, seq: i, dueDate: DateTime.utc(2027, 1 + i, 1), amountMinor: 333333),
    ];
    final s = applyPayments(schedule, 400000, DateTime.utc(2027, 2, 15));
    expect(s.map((x) => x.paidMinor), [333333, 66667, 0]);
    expect(s.map((x) => x.isPaid), [true, false, false]);
    expect(s.map((x) => x.isOverdue), [false, true, false]);
  });
}
