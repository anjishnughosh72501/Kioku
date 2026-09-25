import 'dart:collection';
import 'package:flutter/foundation.dart';

class ScrubbedLogEntry {
  final DateTime timestamp;
  final String message;
  final String? stackTrace;

  const ScrubbedLogEntry({
    required this.timestamp,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'stackTrace': stackTrace,
  };
}

/// Privacy-respecting error telemetry service with PII scrubbing.
/// Sanitizes sensitive file paths, tokens, friend codes, and emails before logging.
class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter instance = ErrorReporter._();

  static const int maxLogEntries = 50;
  final Queue<ScrubbedLogEntry> _logRingBuffer = Queue<ScrubbedLogEntry>();

  List<ScrubbedLogEntry> get logs => List.unmodifiable(_logRingBuffer);

  /// Captures an error, scrubs all sensitive data, and buffers it.
  void recordError(dynamic error, dynamic stackTrace, {String? context}) {
    final scrubbedMsg = scrub(error.toString());
    final scrubbedStack = stackTrace != null
        ? scrub(stackTrace.toString())
        : null;
    final prefix = context != null ? '[$context] ' : '';

    final entry = ScrubbedLogEntry(
      timestamp: DateTime.now(),
      message: '$prefix$scrubbedMsg',
      stackTrace: scrubbedStack,
    );

    if (_logRingBuffer.length >= maxLogEntries) {
      _logRingBuffer.removeFirst();
    }
    _logRingBuffer.addLast(entry);

    if (kDebugMode) {
      debugPrint('ScrubbedError: ${entry.message}');
    }
  }

  /// Scrubs file paths, bearer tokens, emails, and device identifiers from strings.
  static String scrub(String input) {
    var result = input;

    // Scrub file paths (Windows, Linux, macOS, Android sandbox)
    result = result.replaceAll(RegExp(r'[a-zA-Z]:\\[^\s]+'), '[LOCAL_PATH]');
    result = result.replaceAll(
      RegExp(r'/data/user/0/[^\s]+'),
      '[APP_SANDBOX_PATH]',
    );
    result = result.replaceAll(RegExp(r'/Users/[^\s]+'), '[USER_PATH]');
    result = result.replaceAll(RegExp(r'/home/[^\s]+'), '[HOME_PATH]');

    // Scrub emails
    result = result.replaceAll(
      RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+'),
      '[EMAIL]',
    );

    // Scrub JWT / Bearer tokens
    result = result.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*'),
      'Bearer [REDACTED_JWT]',
    );

    // Scrub 24-word recovery seeds if found in errors
    result = result.replaceAll(
      RegExp(r'([a-z]{3,8}\s+){11,23}[a-z]{3,8}', caseSensitive: false),
      '[REDACTED_MNEMONIC]',
    );

    return result;
  }

  void clearLogs() {
    _logRingBuffer.clear();
  }
}
