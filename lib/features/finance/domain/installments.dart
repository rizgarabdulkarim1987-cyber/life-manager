import '../../../core/db/app_database.dart';

class DebtSummary {
  const DebtSummary({
    required this.debt,
    required this.repaidMinor,
    required this.remainingMinor,
    required this.nextDue,
    required this.overdue,
  });

  final Debt debt;
  final int repaidMinor;
  final int remainingMinor;
  final DateTime? nextDue;
  final bool overdue;
}

int _daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Monthly installments on the first due date's day (clamped to short
/// months). Each is `total ~/ count`; the last takes the remainder.
List<(DateTime due, int amountMinor)> equalInstallments({
  required int totalMinor,
  required int count,
  required DateTime firstDue,
}) {
  if (count <= 0 || count > totalMinor) throw ArgumentError.value(count, 'count');
  final each = totalMinor ~/ count;
  return [
    for (var i = 0; i < count; i++)
      () {
        final y = firstDue.year + (firstDue.month - 1 + i) ~/ 12;
        final m = (firstDue.month - 1 + i) % 12 + 1;
        final day = firstDue.day.clamp(1, _daysIn(y, m));
        final due = firstDue.isUtc ? DateTime.utc(y, m, day) : DateTime(y, m, day);
        return (due, i == count - 1 ? totalMinor - each * (count - 1) : each);
      }(),
  ];
}

class InstallmentState {
  const InstallmentState({required this.inst, required this.paidMinor, required this.isPaid, required this.isOverdue});

  final Installment inst;
  final int paidMinor;
  final bool isPaid;
  final bool isOverdue;
}

/// Fills installments with the total repaid, in `seq` order.
List<InstallmentState> applyPayments(List<Installment> schedule, int totalRepaidMinor, DateTime today) {
  final ordered = [...schedule]..sort((a, b) => a.seq.compareTo(b.seq));
  var left = totalRepaidMinor;
  return [
    for (final i in ordered)
      () {
        final paid = left.clamp(0, i.amountMinor);
        left -= paid;
        final isPaid = paid == i.amountMinor;
        return InstallmentState(
          inst: i,
          paidMinor: paid,
          isPaid: isPaid,
          isOverdue: !isPaid && i.dueDate.isBefore(today),
        );
      }(),
  ];
}
