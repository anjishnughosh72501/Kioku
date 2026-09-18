import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_mobile/core/errors/network_exceptions.dart';

/// Lightweight cancellation token for network requests.
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw NetworkException.cancelled();
    }
  }
}

/// Centralized HTTP client wrapper with timeouts, retries, exponential backoff,
/// and typed [NetworkException] handling.
class HttpClientHelper {
  final http.Client innerClient;
  http.Client get _innerClient => innerClient;

  static const Duration defaultApiTimeout = Duration(seconds: 5);
  static const Duration defaultUploadTimeout = Duration(seconds: 30);

  HttpClientHelper({http.Client? client})
      : innerClient = client ?? http.Client();

  static final HttpClientHelper instance = HttpClientHelper();

  /// GET request with automatic retries on idempotent failures.
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration timeout = defaultApiTimeout,
    int maxRetries = 2,
    CancellationToken? cancelToken,
  }) async {
    return _sendWithRetry(
      method: 'GET',
      url: url,
      action: () => _innerClient.get(url, headers: headers),
      timeout: timeout,
      maxRetries: maxRetries,
      cancelToken: cancelToken,
    );
  }

  /// POST request. By default [maxRetries] is 0 unless [retrySafe] is explicitly true.
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = defaultApiTimeout,
    bool retrySafe = false,
    int maxRetries = 0,
    CancellationToken? cancelToken,
  }) async {
    final retries = retrySafe ? (maxRetries > 0 ? maxRetries : 2) : 0;
    return _sendWithRetry(
      method: 'POST',
      url: url,
      action: () => _innerClient.post(url, headers: headers, body: body),
      timeout: timeout,
      maxRetries: retries,
      cancelToken: cancelToken,
    );
  }

  /// PUT request with automatic retries on idempotent failures.
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = defaultApiTimeout,
    int maxRetries = 2,
    CancellationToken? cancelToken,
  }) async {
    return _sendWithRetry(
      method: 'PUT',
      url: url,
      action: () => _innerClient.put(url, headers: headers, body: body),
      timeout: timeout,
      maxRetries: maxRetries,
      cancelToken: cancelToken,
    );
  }

  /// DELETE request.
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = defaultApiTimeout,
    bool retrySafe = false,
    int maxRetries = 0,
    CancellationToken? cancelToken,
  }) async {
    final retries = retrySafe ? (maxRetries > 0 ? maxRetries : 2) : 0;
    return _sendWithRetry(
      method: 'DELETE',
      url: url,
      action: () => _innerClient.delete(url, headers: headers, body: body),
      timeout: timeout,
      maxRetries: retries,
      cancelToken: cancelToken,
    );
  }

  Future<http.Response> _sendWithRetry({
    required String method,
    required Uri url,
    required Future<http.Response> Function() action,
    required Duration timeout,
    required int maxRetries,
    CancellationToken? cancelToken,
  }) async {
    int attempts = 0;

    while (true) {
      cancelToken?.throwIfCancelled();
      attempts++;

      try {
        final response = await action().timeout(timeout);
        cancelToken?.throwIfCancelled();

        // Retry on 5xx if retries remaining
        if (response.statusCode >= 500 && attempts <= maxRetries) {
          await _backoff(attempts);
          continue;
        }

        return response;
      } on NetworkException {
        rethrow;
      } on TimeoutException catch (e) {
        if (attempts <= maxRetries) {
          await _backoff(attempts);
          continue;
        }
        throw NetworkException.timeout(e);
      } on SocketException catch (e) {
        if (attempts <= maxRetries) {
          await _backoff(attempts);
          continue;
        }
        throw NetworkException.offline(e);
      } on http.ClientException catch (e) {
        if (attempts <= maxRetries) {
          await _backoff(attempts);
          continue;
        }
        throw NetworkException.unreachable(e);
      } catch (e) {
        if (attempts <= maxRetries) {
          await _backoff(attempts);
          continue;
        }
        throw NetworkException(e.toString(), cause: e);
      }
    }
  }

  Future<void> _backoff(int attempt) async {
    // Attempt 1: 500ms, Attempt 2: 1000ms
    final delayMs = attempt == 1 ? 500 : 1000;
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  void close() {
    _innerClient.close();
  }
}
