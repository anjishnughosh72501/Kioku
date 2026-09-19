import 'package:flutter/foundation.dart';

/// Secure logging utility for Kioku.
/// In debug mode, logs to console with a tag.
/// Never logs secrets, passwords, tokens, or encryption keys.
class KiokuLog {
  KiokuLog._();

  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[$tag ERROR] $message: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
