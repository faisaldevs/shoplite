/// Thrown by the data layer when local storage fails.
/// Repositories turn it into a [CacheFailure] via `guard`.
class CacheException implements Exception {
  const CacheException({this.message = 'Cache operation failed'});
  final String message;

  @override
  String toString() => 'CacheException: $message';
}
