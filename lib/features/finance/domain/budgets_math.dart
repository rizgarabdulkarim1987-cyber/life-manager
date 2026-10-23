import '../../../core/db/app_database.dart';

/// A budget's figures for one month, in the budget's currency.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.actualMinor,
    required this.remainingMinor,
    required this.percentBp,
    required this.missingRates,
  });

  final Budget budget;
  final int actualMinor;
  final int remainingMinor;
  final int percentBp;

  /// Currencies left out because no rate existed on their transaction dates.
  final List<String> missingRates;
}
