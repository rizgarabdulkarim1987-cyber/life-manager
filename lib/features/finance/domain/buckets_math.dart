import '../../../core/db/app_database.dart';

/// Splits [totalBaseMinor] by basis points. Each share is floored; the
/// remainder goes to the bucket with the largest share (the first on a tie),
/// so the shares always sum to the total.
List<int> defaultSplit(int totalBaseMinor, List<int> percentBp) {
  final shares = [for (final bp in percentBp) totalBaseMinor * bp ~/ 10000];
  final rest = totalBaseMinor - shares.fold<int>(0, (s, x) => s + x);
  if (rest != 0 && shares.isNotEmpty) {
    var top = 0;
    for (var i = 1; i < percentBp.length; i++) {
      if (percentBp[i] > percentBp[top]) top = i;
    }
    shares[top] += rest;
  }
  return shares;
}

/// One bucket's figures, all in the base currency.
class BucketStatus {
  const BucketStatus({
    required this.bucket,
    required this.allocatedMinor,
    required this.spentMinor,
    required this.availableMinor,
    required this.targetMinor,
  });

  final Bucket bucket;
  final int allocatedMinor;
  final int spentMinor;
  final int availableMinor;
  final int? targetMinor;

  /// Spent as basis points of allocated; null when nothing was allocated.
  int? get usedBp => allocatedMinor <= 0 ? null : spentMinor * 10000 ~/ allocatedMinor;
}
