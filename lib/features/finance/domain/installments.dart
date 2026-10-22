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
