/// n / d rounded half to even. [d] must be positive.
BigInt divRoundHalfEven(BigInt n, BigInt d) {
  if (d <= BigInt.zero) throw ArgumentError.value(d, 'd', 'must be positive');
  final negative = n.isNegative;
  final a = n.abs();
  var q = a ~/ d;
  final twice = (a - q * d) * BigInt.two;
  if (twice > d || (twice == d && q.isOdd)) q += BigInt.one;
  return negative ? -q : q;
}
