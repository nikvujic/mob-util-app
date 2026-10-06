int _lastTimestamp = 0;
int _sequence = 0;

/// Returns a unique, time-ordered id. Safe to call several times within the
/// same millisecond (e.g. when adding shopping items quickly).
String generateId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  if (now == _lastTimestamp) {
    _sequence++;
  } else {
    _lastTimestamp = now;
    _sequence = 0;
  }
  return '$now-$_sequence';
}
