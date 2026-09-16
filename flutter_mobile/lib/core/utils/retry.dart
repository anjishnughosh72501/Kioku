import 'dart:async';

/// Retries an idempotent async action with exponential backoff on transient network failures.
Future<T> retryAsync<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 300),
  double backoffFactor = 2.0,
  bool Function(Object error)? shouldRetry,
}) async {
  var delay = initialDelay;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (attempt == maxAttempts) rethrow;
      if (shouldRetry != null && !shouldRetry(e)) rethrow;
      await Future.delayed(delay);
      delay = Duration(milliseconds: (delay.inMilliseconds * backoffFactor).round());
    }
  }
  throw StateError('retryAsync: unreachable');
}
