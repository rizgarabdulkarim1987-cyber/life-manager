/// How far the Investment bucket is from paying for a project (redesign §9.3).
///
/// [remainingMinor] is what is still missing (0 when the bucket already covers the cost);
/// [months] is how many months of the recent pace it takes to close the gap, or null when
/// the bucket gets nothing each month (no pace to measure) while something is still missing.
typedef Affordability = ({int remainingMinor, int? months});

Affordability computeAffordability({
  required int costBaseMinor,
  required int investmentAvailableMinor,
  required int avgMonthlyAllocationMinor,
}) {
  final remaining = costBaseMinor - investmentAvailableMinor;
  if (remaining <= 0) return (remainingMinor: 0, months: 0);
  if (avgMonthlyAllocationMinor <= 0) return (remainingMinor: remaining, months: null);
  final months = (remaining + avgMonthlyAllocationMinor - 1) ~/ avgMonthlyAllocationMinor;
  return (remainingMinor: remaining, months: months);
}
