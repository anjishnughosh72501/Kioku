/// Typed exception hierarchy for Kioku networking, storage, and invites.
library;

sealed class KiokuException implements Exception {
  final String message;
  final Object? cause;

  const KiokuException(this.message, {this.cause});

  @override
  String toString() => message;
}

enum NetworkErrorType {
  offline,
  timeout,
  unreachable,
  serverError,
  cancelled,
}

class NetworkException extends KiokuException {
  final NetworkErrorType type;
  final int? statusCode;

  const NetworkException(
    super.message, {
    this.type = NetworkErrorType.unreachable,
    this.statusCode,
    super.cause,
  });

  factory NetworkException.timeout([Object? cause]) => const NetworkException(
        'Connection timed out. Please check your internet connection.',
        type: NetworkErrorType.timeout,
      );

  factory NetworkException.offline([Object? cause]) => const NetworkException(
        'You appear to be offline. Please reconnect and try again.',
        type: NetworkErrorType.offline,
      );

  factory NetworkException.unreachable([Object? cause]) => const NetworkException(
        'Unable to reach the Kioku server. Please try again in a moment.',
        type: NetworkErrorType.unreachable,
      );

  factory NetworkException.server(int code, [String? message]) => NetworkException(
        message ?? 'Server error ($code). Please try again later.',
        type: NetworkErrorType.serverError,
        statusCode: code,
      );

  factory NetworkException.cancelled() => const NetworkException(
        'Request was cancelled.',
        type: NetworkErrorType.cancelled,
      );
}

enum StorageErrorType {
  authFailure,
  quotaExceeded,
  notFound,
  corrupted,
  providerError,
}

class StorageException extends KiokuException {
  final StorageErrorType type;

  const StorageException(
    super.message, {
    this.type = StorageErrorType.providerError,
    super.cause,
  });

  factory StorageException.authFailure([String? message]) => StorageException(
        message ?? 'Storage authentication failed. Please re-authenticate.',
        type: StorageErrorType.authFailure,
      );

  factory StorageException.quotaExceeded([String? message]) => StorageException(
        message ?? 'Storage quota exceeded. Please free up space.',
        type: StorageErrorType.quotaExceeded,
      );

  factory StorageException.notFound(String id) => StorageException(
        'File or container not found: $id',
        type: StorageErrorType.notFound,
      );

  factory StorageException.corrupted(String id) => StorageException(
        'Encrypted file is corrupted or could not be read: $id',
        type: StorageErrorType.corrupted,
      );
}

enum InviteErrorType {
  invalid,
  expired,
  alreadyClaimed,
  selfInvite,
}

class InviteException extends KiokuException {
  final InviteErrorType type;
  final String code;

  const InviteException(
    super.message, {
    required this.code,
    this.type = InviteErrorType.invalid,
    super.cause,
  });

  factory InviteException.invalid(String code) => InviteException(
        'Invalid invite code "$code". Please check the code and try again.',
        code: code,
        type: InviteErrorType.invalid,
      );

  factory InviteException.expired(String code) => InviteException(
        'This invite code has expired. Please request a new invite link.',
        code: code,
        type: InviteErrorType.expired,
      );

  factory InviteException.alreadyClaimed(String code) => InviteException(
        'This single-use invite has already been claimed.',
        code: code,
        type: InviteErrorType.alreadyClaimed,
      );

  factory InviteException.selfInvite(String code) => InviteException(
        'You cannot accept your own invite code.',
        code: code,
        type: InviteErrorType.selfInvite,
      );
}
