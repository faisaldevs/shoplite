class CacheException implements Exception {
  const CacheException({this.message = "Cache Oparation Failed"});
  final String message;

  @override
  String toString() => "Exception: $message";
}
