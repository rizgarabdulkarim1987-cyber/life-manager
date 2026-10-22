/// Wraps a secret so string interpolation, collections and logs never show it.
/// Read [value] only where the secret is actually used.
final class Sensitive<T> {
  const Sensitive(this.value);

  final T value;

  @override
  String toString() => '‹redacted›';
}
