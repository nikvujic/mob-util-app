/// A save that didn't reach the phone's storage (e.g. it's full).
class StorageWriteException implements Exception {
  final String path;
  final Object cause;

  const StorageWriteException(this.path, this.cause);

  @override
  String toString() => 'StorageWriteException: $path: $cause';
}
