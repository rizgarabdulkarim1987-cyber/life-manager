/// An amount in integer minor units of [currency]. Never a double.
final class Money {
  const Money(this.minor, this.currency);

  final int minor;
  final String currency;

  bool get isZero => minor == 0;

  Money operator +(Money o) => Money(minor + _same(o).minor, currency);

  Money operator -(Money o) => Money(minor - _same(o).minor, currency);

  Money operator -() => Money(-minor, currency);

  Money _same(Money o) {
    if (o.currency != currency) throw CurrencyMismatch(currency, o.currency);
    return o;
  }

  @override
  bool operator ==(Object other) => other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}

final class CurrencyMismatch implements Exception {
  const CurrencyMismatch(this.a, this.b);
  final String a;
  final String b;

  @override
  String toString() => 'CurrencyMismatch($a, $b)';
}
