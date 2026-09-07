/// A disposed account's asynchronous work must stop, not fall back to another
/// account's database or silently become an online-only operation.
class StaleAccountScope implements Exception {
  const StaleAccountScope();

  @override
  String toString() => 'The active account changed.';
}
