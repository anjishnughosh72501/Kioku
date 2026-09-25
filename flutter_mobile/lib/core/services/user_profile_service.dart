import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mobile/core/config.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/network/http_client_helper.dart';
import 'package:flutter_mobile/core/services/invite_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/util/kioku_log.dart';

enum FriendAuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  authFailed,
  notAuthorized,
  serverError,
  timeout,
  offline,
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;
  const AuthException(this.message, {this.statusCode, this.endpoint});

  @override
  String toString() =>
      'AuthException: $message (statusCode: $statusCode, endpoint: $endpoint)';
}

class FriendException implements Exception {
  final String message;
  final String? code;
  const FriendException(this.message, {this.code});

  @override
  String toString() => 'FriendException: $message ($code)';
}

class FriendLookupResult {
  final bool exists;
  final String friendCode;
  final String? username;

  const FriendLookupResult({
    required this.exists,
    required this.friendCode,
    this.username,
  });

  String get displayName =>
      (username != null && username!.isNotEmpty) ? username! : friendCode;
}

class UserProfile {
  final String username;
  final String friendCode;

  const UserProfile({required this.username, required this.friendCode});
}

enum FriendRequestResult {
  sent,
  alreadySent,
  alreadyFriends,
  sameUser,
  notFound,
  unauthorized,
  networkOffline,
  timeout,
  error,
}

extension FriendRequestResultExt on FriendRequestResult {
  bool get isSuccess =>
      this == FriendRequestResult.sent ||
      this == FriendRequestResult.alreadySent;

  String get userMessage {
    switch (this) {
      case FriendRequestResult.sent:
        return 'Friend request sent!';
      case FriendRequestResult.alreadySent:
        return 'Friend request already sent and pending.';
      case FriendRequestResult.alreadyFriends:
        return 'Already in your friends list.';
      case FriendRequestResult.sameUser:
        return 'Cannot send a friend request to yourself.';
      case FriendRequestResult.notFound:
        return 'Friend code not found. Please verify spelling.';
      case FriendRequestResult.unauthorized:
        return 'Authentication rejected. Please check connection and retry.';
      case FriendRequestResult.networkOffline:
        return 'You appear to be offline. Please check your internet connection.';
      case FriendRequestResult.timeout:
        return 'Connection timed out. Please try again.';
      case FriendRequestResult.error:
        return 'Could not send request. Please check code and try again.';
    }
  }
}

class FriendRequest {
  final String id;
  final String fromCode;
  final String toCode;
  final String? fromName;
  final int? createdAt;

  const FriendRequest({
    required this.id,
    required this.fromCode,
    required this.toCode,
    this.fromName,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromCode': fromCode,
    'toCode': toCode,
    'fromName': fromName,
    'createdAt': createdAt,
  };

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    fromCode: json['fromCode'] as String,
    toCode: (json['toCode'] as String?) ?? '',
    fromName: json['fromName'] as String?,
    createdAt: json['createdAt'] as int?,
  );
}

class FriendUser {
  final String friendCode;
  final String? username;
  final int? createdAt;
  final int? updatedAt;
  final String status;

  const FriendUser({
    required this.friendCode,
    this.username,
    this.createdAt,
    this.updatedAt,
    this.status = 'accepted',
  });

  String get displayName =>
      (username != null && username!.isNotEmpty) ? username! : friendCode;
  int? get connectedAt => createdAt;

  Map<String, dynamic> toJson() => {
    'friendCode': friendCode,
    'username': username,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'status': status,
  };

  factory FriendUser.fromJson(Map<String, dynamic> json) => FriendUser(
    friendCode: json['friendCode'] as String,
    username: json['username'] as String?,
    createdAt: (json['createdAt'] ?? json['connectedAt']) as int?,
    updatedAt:
        (json['updatedAt'] ?? json['createdAt'] ?? json['connectedAt']) as int?,
    status: (json['status'] as String?) ?? 'accepted',
  );
}

class SentFriendRequest {
  final String id;
  final String fromCode;
  final String toCode;
  final String? toName;
  final String status;
  final int createdAt;
  final int updatedAt;

  const SentFriendRequest({
    required this.id,
    required this.fromCode,
    required this.toCode,
    this.toName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => status == 'expired';
  bool get isPending => status == 'pending';

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromCode': fromCode,
    'toCode': toCode,
    'toName': toName,
    'status': status,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory SentFriendRequest.fromJson(Map<String, dynamic> json) =>
      SentFriendRequest(
        id: json['id'] as String,
        fromCode: (json['fromCode'] as String?) ?? '',
        toCode: json['toCode'] as String,
        toName: json['toName'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        createdAt: (json['createdAt'] as int?) ?? 0,
        updatedAt: (json['updatedAt'] as int?) ?? 0,
      );
}

class InviteResolution {
  final String status;
  final String? username;
  final String? friendCode;
  final int? expiresAt;
  final String? code;

  const InviteResolution({
    required this.status,
    this.username,
    this.friendCode,
    this.expiresAt,
    this.code,
  });

  factory InviteResolution.fromJson(
    Map<String, dynamic> json, {
    String? code,
  }) => InviteResolution(
    status: (json['status'] as String?) ?? 'invalid',
    username: json['username'] as String?,
    friendCode: json['friendCode'] as String?,
    expiresAt: json['expiresAt'] as int?,
    code: (json['code'] as String?) ?? code,
  );

  factory InviteResolution.invalid([String? code]) =>
      InviteResolution(status: 'invalid', code: code);

  bool get isValid => status == 'valid';
  bool get isExpired => status == 'expired';
  bool get isInvalid => status == 'invalid';
}

class InviteCreation {
  final String code;
  final String url;
  final int? expiresAt;

  const InviteCreation({required this.code, required this.url, this.expiresAt});

  factory InviteCreation.fromJson(Map<String, dynamic> json) => InviteCreation(
    code: (json['code'] as String?) ?? '',
    url: (json['url'] as String?) ?? '',
    expiresAt: json['expiresAt'] as int?,
  );

  bool get isExpired {
    if (expiresAt == null) return false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs >= expiresAt!;
  }
}

class AlbumInvite {
  final String id;
  final String albumId;
  final String albumName;
  final String fromCode;
  final String toCode;
  final String? fromName;
  final String? claimToken;
  final String? inviterPubKey;
  final int? createdAt;

  const AlbumInvite({
    required this.id,
    required this.albumId,
    required this.albumName,
    required this.fromCode,
    required this.toCode,
    this.fromName,
    this.claimToken,
    this.inviterPubKey,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'albumId': albumId,
    'albumName': albumName,
    'fromCode': fromCode,
    'toCode': toCode,
    'fromName': fromName,
    'claimToken': claimToken,
    'inviterPubKey': inviterPubKey,
    'createdAt': createdAt,
  };

  factory AlbumInvite.fromJson(Map<String, dynamic> json) => AlbumInvite(
    id: json['id'] as String,
    albumId: json['albumId'] as String,
    albumName: (json['albumName'] as String?) ?? 'Shared Album',
    fromCode: json['fromCode'] as String,
    toCode: (json['toCode'] as String?) ?? '',
    fromName: json['fromName'] as String?,
    claimToken: json['claimToken'] as String?,
    inviterPubKey: json['inviterPubKey'] as String?,
    createdAt: json['createdAt'] as int?,
  );
}

class UserProfileService {
  UserProfileService._() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      secureStorage = InMemorySecureStorage();
    }
  }
  static final UserProfileService instance = UserProfileService._();

  static const String _keyUsername = 'kioku_username';
  static const String _keyFriendCode = 'kioku_friend_code';
  static const String _keyFriendSecret = 'kioku_friend_device_secret';
  static const String _keyConnectedFriends = 'kioku_connected_friends';
  static const String _keyPendingSent = 'kioku_pending_sent_requests';
  static const String _keyIncomingRequests = 'kioku_cached_incoming_requests';
  static const String _keyIncomingAlbumInvites = 'kioku_cached_album_invites';

  static const String _kSecBackendToken = 'kioku_sec_backend_token';
  static const String _kSecDeviceSecret = 'kioku_sec_device_secret';

  ISecureStorageProvider secureStorage = FlutterSecureStorageWrapper();

  HttpClientHelper clientHelper = HttpClientHelper.instance;
  http.Client get httpClient => clientHelper.innerClient;
  set httpClient(http.Client client) {
    clientHelper = HttpClientHelper(client: client);
  }

  UserProfile? _currentProfile;
  String? _cachedToken;
  final List<void Function(UserProfile)> _listeners = [];

  void addListener(void Function(UserProfile) listener) =>
      _listeners.add(listener);
  void removeListener(void Function(UserProfile) listener) =>
      _listeners.remove(listener);

  FriendAuthStatus _authStatus = FriendAuthStatus.unauthenticated;
  FriendAuthStatus get authStatus => _authStatus;
  String? _canonicalUserId;
  String? get canonicalUserId => _canonicalUserId;

  final List<void Function(FriendAuthStatus)> _authStatusListeners = [];
  void addAuthStatusListener(void Function(FriendAuthStatus) listener) =>
      _authStatusListeners.add(listener);
  void removeAuthStatusListener(void Function(FriendAuthStatus) listener) =>
      _authStatusListeners.remove(listener);

  void _setAuthStatus(FriendAuthStatus status) {
    if (_authStatus != status) {
      _authStatus = status;
      KiokuLog.d('UserProfileService', 'FriendAuthStatus changed to: $status');
      for (final listener in List.of(_authStatusListeners)) {
        listener(status);
      }
    }
  }

  void setAuthStatusForTesting(FriendAuthStatus status) =>
      _setAuthStatus(status);

  UserProfile? get currentProfile => _currentProfile;

  static bool _isJwtValid(String token) {
    try {
      if (token.startsWith('mock_')) return true;
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payloadJson) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is num) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return nowSec < (exp - 60);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    var friendCode = prefs.getString(_keyFriendCode);

    if (friendCode == null || friendCode.isEmpty) {
      friendCode = _generateFriendCode();
      await prefs.setString(_keyFriendCode, friendCode);
    }

    // Securely retrieve or migrate device secret
    var deviceSecret = await secureStorage.read(key: _kSecDeviceSecret);
    if (deviceSecret == null || deviceSecret.isEmpty) {
      final legacySecret = prefs.getString(_keyFriendSecret);
      if (legacySecret != null && legacySecret.isNotEmpty) {
        deviceSecret = legacySecret;
        await secureStorage.write(key: _kSecDeviceSecret, value: deviceSecret);
        await prefs.remove(_keyFriendSecret);
      } else {
        final random = Random.secure();
        final values = List<int>.generate(32, (i) => random.nextInt(256));
        deviceSecret = base64UrlEncode(values);
        await secureStorage.write(key: _kSecDeviceSecret, value: deviceSecret);
      }
    }

    if (username != null && username.isNotEmpty) {
      _currentProfile = UserProfile(username: username, friendCode: friendCode);
    }

    // Restore cached bearer token if unexpired
    final savedToken = await secureStorage.read(key: _kSecBackendToken);
    if (savedToken != null &&
        savedToken.isNotEmpty &&
        _isJwtValid(savedToken)) {
      _cachedToken = savedToken;
      _setAuthStatus(FriendAuthStatus.authenticated);
    }
  }

  /// Ensures the user is bootstrapped and authenticated with the backend.
  /// If JWT is missing or expired, calls bootstrap/token endpoint.
  Future<String?> ensureBootstrapped({bool forceRefresh = false}) async {
    return getAuthToken(forceRefresh: forceRefresh);
  }

  /// Request or retrieve a cached signed JWT authorization token for this device's friend code
  Future<String?> getAuthToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken != null && _isJwtValid(_cachedToken!)) {
      return _cachedToken;
    }

    _setAuthStatus(FriendAuthStatus.authenticating);

    var secret = await secureStorage.read(key: _kSecDeviceSecret);
    if (secret == null || secret.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_keyFriendSecret);
      if (legacy != null && legacy.isNotEmpty) {
        secret = legacy;
        await secureStorage.write(key: _kSecDeviceSecret, value: secret);
        await prefs.remove(_keyFriendSecret);
      } else {
        final random = Random.secure();
        final values = List<int>.generate(32, (i) => random.nextInt(256));
        secret = base64UrlEncode(values);
        await secureStorage.write(key: _kSecDeviceSecret, value: secret);
      }
    }

    final myCode = friendCode.trim().toUpperCase();
    try {
      final res = await clientHelper.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'friendCode': myCode,
          'secret': secret,
          'deviceSecret': secret,
          'username': username,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedToken = data['token'] as String?;
        if (_cachedToken != null) {
          await secureStorage.write(
            key: _kSecBackendToken,
            value: _cachedToken!,
          );
        }
        if (data['user'] is Map) {
          _canonicalUserId = data['user']['id'] as String?;
        }
        _setAuthStatus(FriendAuthStatus.authenticated);
        return _cachedToken;
      } else if (res.statusCode == 401) {
        _cachedToken = null;
        await secureStorage.delete(key: _kSecBackendToken);
        _setAuthStatus(FriendAuthStatus.authFailed);
        KiokuLog.e(
          'UserProfileService',
          'Auth rejected with status 401 on /friends/token',
        );
        throw const AuthException(
          'Authentication rejected by server (401)',
          statusCode: 401,
          endpoint: '/friends/token',
        );
      } else if (res.statusCode == 403) {
        _cachedToken = null;
        await secureStorage.delete(key: _kSecBackendToken);
        _setAuthStatus(FriendAuthStatus.notAuthorized);
        KiokuLog.e(
          'UserProfileService',
          'Auth forbidden with status 403 on /friends/token',
        );
        throw const AuthException(
          'Access forbidden by server (403)',
          statusCode: 403,
          endpoint: '/friends/token',
        );
      } else {
        _cachedToken = null;
        _setAuthStatus(FriendAuthStatus.serverError);
        KiokuLog.e(
          'UserProfileService',
          'Server error (${res.statusCode}) during auth on /friends/token',
        );
        throw AuthException(
          'Server error (${res.statusCode}) during auth',
          statusCode: res.statusCode,
          endpoint: '/friends/token',
        );
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        _setAuthStatus(FriendAuthStatus.timeout);
        KiokuLog.e(
          'UserProfileService',
          'Auth request timed out on /friends/token',
        );
        throw AuthException(
          'Connection timed out on /friends/token: $e',
          endpoint: '/friends/token',
        );
      } else if (msg.contains('socket') ||
          msg.contains('offline') ||
          msg.contains('failed host lookup') ||
          msg.contains('network') ||
          msg.contains('unreachable') ||
          msg.contains('connection refused')) {
        _setAuthStatus(FriendAuthStatus.offline);
        KiokuLog.e(
          'UserProfileService',
          'Network unreachable / offline on /friends/token: $e',
        );
        throw AuthException(
          'Network unreachable / offline: $e',
          endpoint: '/friends/token',
        );
      } else {
        _setAuthStatus(FriendAuthStatus.serverError);
        KiokuLog.e('UserProfileService', 'Failed to reach auth server: $e');
        throw AuthException(
          'Server error during auth: $e',
          endpoint: '/friends/token',
        );
      }
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('No authentication token available');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Executes an authenticated HTTP request. If the server returns 401 or 403 (JWT expired/invalid),
  /// automatically bootstraps/refreshes the token and retries the original request once.
  Future<http.Response> authedRequest(
    Future<http.Response> Function(Map<String, String> headers) sendFn,
  ) async {
    var headers = await _authHeaders();
    var res = await sendFn(headers);

    if (res.statusCode == 401 || res.statusCode == 403) {
      KiokuLog.d(
        'UserProfileService',
        'Token rejected with ${res.statusCode}. Auto-refreshing JWT bootstrap and retrying...',
      );
      try {
        _cachedToken = null;
        await secureStorage.delete(key: _kSecBackendToken);
        await getAuthToken(forceRefresh: true);
        headers = await _authHeaders();
        res = await sendFn(headers);
      } catch (e) {
        KiokuLog.e('UserProfileService', 'Auto-refresh bootstrap failed', e);
      }
    }

    return res;
  }

  bool get hasUsername =>
      _currentProfile != null &&
      _currentProfile!.username.isNotEmpty &&
      _currentProfile!.username.trim() != 'Storyteller';

  String get friendCode {
    return _currentProfile?.friendCode ?? 'KIOKU-START';
  }

  String get username {
    return _currentProfile?.username ?? 'Storyteller';
  }

  Future<UserProfile> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    var friendCode = prefs.getString(_keyFriendCode);
    if (friendCode == null || friendCode.isEmpty) {
      friendCode = _generateFriendCode();
      await prefs.setString(_keyFriendCode, friendCode);
    }

    final trimmed = username.trim();
    await prefs.setString(_keyUsername, trimmed);

    final profile = UserProfile(username: trimmed, friendCode: friendCode);
    _currentProfile = profile;
    for (final listener in List.of(_listeners)) {
      listener(profile);
    }

    try {
      await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/profile'),
          headers: headers,
          body: jsonEncode({'username': trimmed}),
        ),
      );
    } catch (_) {}

    return profile;
  }

  Future<List<String>> getConnectedFriends() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyConnectedFriends) ?? [];
  }

  Future<bool> addFriend(String friendCode, {String? displayName}) async {
    final code = friendCode.trim().toUpperCase();
    if (code.isEmpty || code == _currentProfile?.friendCode) return false;

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyConnectedFriends) ?? [];
    if (displayName != null && displayName.trim().isNotEmpty) {
      await prefs.setString('kioku_friend_name_$code', displayName.trim());
    }
    if (!list.contains(code)) {
      list.add(code);
      await prefs.setStringList(_keyConnectedFriends, list);
      _notifyFriendListeners();
      return true;
    }
    return false;
  }

  Future<String?> getFriendName(String friendCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      'kioku_friend_name_${friendCode.trim().toUpperCase()}',
    );
  }

  Future<bool> removeFriend(String friendCode) async {
    final code = friendCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyConnectedFriends) ?? [];
    await prefs.remove('kioku_friend_name_$code');
    bool removedLocally = false;
    if (list.remove(code)) {
      await prefs.setStringList(_keyConnectedFriends, list);
      _notifyFriendListeners();
      removedLocally = true;
    }

    try {
      await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/remove'),
          headers: headers,
          body: jsonEncode({'friendCode': code}),
        ),
      );
    } catch (_) {}

    return removedLocally;
  }

  /// Create a short universal invite link (e.g. kioku.app/i/8F3KD2)
  Future<InviteCreation?> createUniversalInvite({String? myName}) async {
    try {
      final res = await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/invite'),
          headers: headers,
          body: jsonEncode({'fromName': myName ?? username}),
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return InviteCreation.fromJson(data);
      } else {
        final err = jsonDecode(res.body);
        throw FriendException(
          err['error'] ?? 'Server error (${res.statusCode}) creating invite',
          code: err['code'],
        );
      }
    } catch (e) {
      KiokuLog.e('UserProfileService', 'Failed to create universal invite', e);
      if (e is FriendException || e is AuthException) rethrow;
      throw FriendException('Unable to create invite: $e');
    }
  }

  /// Resolve a short invite code publicly
  Future<InviteResolution> resolveInvite(String code) async {
    final clean = code.trim().toUpperCase();
    try {
      final res = await clientHelper.get(
        Uri.parse(
          '${AppConfig.backendBaseUrl}/friends/invite/$clean?format=json',
        ),
        headers: {'Accept': 'application/json'},
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return InviteResolution.fromJson(data, code: clean);
    } catch (_) {
      return InviteResolution.invalid(clean);
    }
  }

  /// Confirm/claim an invite code: Device B confirms invite from Device A,
  /// creating a friend request from Device A to Device B.
  Future<Map<String, dynamic>?> confirmInvite(String inviteCode) async {
    final clean = inviteCode.trim().toUpperCase();
    if (clean.isEmpty) return null;
    try {
      final res = await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/invite/confirm'),
          headers: headers,
          body: jsonEncode({'inviteCode': clean}),
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _notifyFriendListeners();
        return data;
      } else {
        final err = jsonDecode(res.body);
        throw FriendException(
          err['error'] ?? 'Could not confirm invite',
          code: err['code'],
        );
      }
    } catch (e) {
      KiokuLog.e('UserProfileService', 'Failed to confirm invite', e);
      if (e is FriendException) rethrow;
      throw FriendException('Unable to confirm invite: $e');
    }
  }

  /// Method A pre-send lookup: inspect recipient identity before sending request
  Future<FriendLookupResult?> lookupFriendCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return null;
    try {
      final res = await authedRequest(
        (headers) => clientHelper.get(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/lookup/$clean'),
          headers: headers,
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return FriendLookupResult(
          exists: data['exists'] == true,
          friendCode: data['friendCode'] as String? ?? clean,
          username: data['username'] as String?,
        );
      } else if (res.statusCode == 404) {
        return null;
      } else {
        final err = jsonDecode(res.body);
        throw FriendException(
          err['error'] ?? 'Friend lookup failed',
          code: err['code'],
        );
      }
    } catch (e) {
      KiokuLog.e('UserProfileService', 'Lookup friend code failed', e);
      if (e is FriendException) rethrow;
      throw FriendException('Network error during lookup: $e');
    }
  }

  static const String _keyCachedFriendsJson = 'kioku_cached_friends_json';

  /// Reconcile local friend state with remote server (server is source of truth).
  /// Never overwrites newer server data with stale local data.
  Future<List<FriendUser>> reconcileFriends() async {
    return getRemoteFriends();
  }

  /// Fetch remote normalized friends list and update local cache with reconciliation
  Future<List<FriendUser>> getRemoteFriends() async {
    final myCode = friendCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();

    // Load existing cached friends map
    final cachedMap = <String, FriendUser>{};
    final cachedRaw = prefs.getString(_keyCachedFriendsJson);
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedRaw) as List;
        for (final item in decoded) {
          final f = FriendUser.fromJson(item as Map<String, dynamic>);
          cachedMap[f.friendCode] = f;
        }
      } catch (_) {}
    }

    try {
      final res = await authedRequest(
        (headers) => clientHelper.get(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/list/$myCode'),
          headers: headers,
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final remoteList =
            (data['friends'] as List?)
                ?.map((e) => FriendUser.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        KiokuLog.d(
          'UserProfileService',
          'Fetched ${remoteList.length} remote friends for $myCode',
        );
        final codes = remoteList.map((f) => f.friendCode).toList();
        await prefs.setStringList(_keyConnectedFriends, codes);
        await prefs.setString(
          _keyCachedFriendsJson,
          jsonEncode(remoteList.map((f) => f.toJson()).toList()),
        );
        for (final f in remoteList) {
          if (f.username != null && f.username!.isNotEmpty) {
            await prefs.setString(
              'kioku_friend_name_${f.friendCode}',
              f.username!,
            );
          }
        }
        return remoteList;
      }
    } catch (e) {
      KiokuLog.e('UserProfileService', 'getRemoteFriends offline or failed', e);
    }

    // Offline fallback: use cached JSON records or local friend codes
    if (cachedMap.isNotEmpty) {
      return cachedMap.values.toList();
    }

    final localCodes = await getConnectedFriends();
    final localFriends = <FriendUser>[];
    for (final c in localCodes) {
      final name = await getFriendName(c);
      localFriends.add(FriendUser(friendCode: c, username: name));
    }
    return localFriends;
  }

  /// Fetch sent friend requests (both pending and expired)
  Future<List<SentFriendRequest>> getSentFriendRequests() async {
    final myCode = friendCode.trim().toUpperCase();
    try {
      final res = await authedRequest(
        (headers) => clientHelper.get(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/sent/$myCode'),
          headers: headers,
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['requests'] as List?)
                ?.map(
                  (e) => SentFriendRequest.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [];
      }
    } catch (_) {}
    return [];
  }

  /// Cancel a sent pending request
  Future<bool> cancelSentRequest(String requestId) async {
    try {
      final res = await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/cancel'),
          headers: headers,
          body: jsonEncode({'requestId': requestId}),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Resend an expired or cancelled friend request
  Future<bool> resendSentRequest(String requestId) async {
    try {
      final res = await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/resend'),
          headers: headers,
          body: jsonEncode({'requestId': requestId}),
        ),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getPendingSentRequests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyPendingSent) ?? [];
  }

  Future<FriendRequestResult> sendFriendRequest(
    String toCode, {
    String? myName,
  }) async {
    final cleanTo = toCode.trim().toUpperCase();
    final myCode = friendCode.trim().toUpperCase();

    if (cleanTo.isEmpty || cleanTo == myCode) {
      return FriendRequestResult.sameUser;
    }

    final friends = await getConnectedFriends();
    if (friends.contains(cleanTo)) {
      return FriendRequestResult.alreadyFriends;
    }

    final pending = await getPendingSentRequests();
    if (pending.contains(cleanTo)) {
      return FriendRequestResult.alreadySent;
    }

    try {
      final res = await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/request'),
          headers: headers,
          body: jsonEncode({'toCode': cleanTo, 'fromName': myName ?? username}),
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_keyPendingSent) ?? [];
        if (!list.contains(cleanTo)) {
          list.add(cleanTo);
          await prefs.setStringList(_keyPendingSent, list);
        }
        if (data['autoAccepted'] == true) {
          await addFriend(cleanTo, displayName: data['fromName'] as String?);
        }
        if (data['alreadySent'] == true) {
          return FriendRequestResult.alreadySent;
        }
        _notifyFriendListeners();
        return FriendRequestResult.sent;
      } else if (res.statusCode == 400) {
        final body = res.body.toLowerCase();
        if (body.contains('yourself') || cleanTo == myCode) {
          return FriendRequestResult.sameUser;
        }
        return FriendRequestResult.error;
      } else if (res.statusCode == 404) {
        return FriendRequestResult.notFound;
      } else if (res.statusCode == 409) {
        return FriendRequestResult.alreadyFriends;
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        return FriendRequestResult.unauthorized;
      } else {
        return FriendRequestResult.error;
      }
    } catch (e) {
      KiokuLog.e('UserProfileService', 'sendFriendRequest failed', e);
      if (e is AuthException) {
        return FriendRequestResult.unauthorized;
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        return FriendRequestResult.timeout;
      }
      if (msg.contains('socket') ||
          msg.contains('offline') ||
          msg.contains('network') ||
          msg.contains('failed host lookup')) {
        return FriendRequestResult.networkOffline;
      }
      return FriendRequestResult.error;
    }
  }

  Future<List<FriendRequest>> getCachedIncomingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyIncomingRequests) ?? [];
    return rawList
        .map((str) {
          try {
            return FriendRequest.fromJson(
              jsonDecode(str) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<FriendRequest>()
        .toList();
  }

  Future<List<FriendRequest>> pollIncomingRequests() async {
    final myCode = friendCode.trim().toUpperCase();
    if (myCode.isEmpty) return getCachedIncomingRequests();

    try {
      final res = await authedRequest(
        (headers) => clientHelper.get(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/requests/$myCode'),
          headers: headers,
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['requests'] as List? ?? []);
        final acceptedList = (data['accepted'] as List? ?? []);
        final friends = await getConnectedFriends();

        // 1. Process accepted requests (User A learning User B accepted)
        for (final item in acceptedList) {
          if (item is Map<String, dynamic>) {
            final toCode = (item['toCode'] as String?)?.trim().toUpperCase();
            final toName = item['fromName'] as String?;
            final reqId = item['id'] as String?;
            if (toCode != null && toCode.isNotEmpty) {
              await addFriend(toCode, displayName: toName);
              final prefs = await SharedPreferences.getInstance();
              final pending = prefs.getStringList(_keyPendingSent) ?? [];
              if (pending.remove(toCode)) {
                await prefs.setStringList(_keyPendingSent, pending);
              }
              if (reqId != null) {
                try {
                  await authedRequest(
                    (ackHeaders) => clientHelper.post(
                      Uri.parse('${AppConfig.backendBaseUrl}/friends/ack'),
                      headers: ackHeaders,
                      body: jsonEncode({'requestId': reqId}),
                    ),
                  );
                } catch (_) {}
              }
            }
          }
        }

        // 2. Process incoming pending requests
        final parsed = list
            .map((item) => FriendRequest.fromJson(item as Map<String, dynamic>))
            .where(
              (req) => !friends.contains(req.fromCode.trim().toUpperCase()),
            )
            .toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _keyIncomingRequests,
          parsed.map((r) => jsonEncode(r.toJson())).toList(),
        );
        _notifyFriendListeners();
        return parsed;
      }
    } catch (_) {}

    return getCachedIncomingRequests();
  }

  Future<bool> acceptRequest(FriendRequest req) async {
    try {
      final res = await authedRequest(
        (headers) => clientHelper.post(
          Uri.parse('${AppConfig.backendBaseUrl}/friends/accept'),
          headers: headers,
          body: jsonEncode({'requestId': req.id}),
        ),
      );

      if (res.statusCode != 200) {
        return false;
      }
    } catch (_) {
      return false;
    }

    final added = await addFriend(req.fromCode, displayName: req.fromName);

    // Remove from cached incoming requests
    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedIncomingRequests();
    final updated = cached.where((r) => r.id != req.id).toList();
    await prefs.setStringList(
      _keyIncomingRequests,
      updated.map((r) => jsonEncode(r.toJson())).toList(),
    );

    // Also remove from pending sent if mutual
    final pending = prefs.getStringList(_keyPendingSent) ?? [];
    if (pending.remove(req.fromCode.trim().toUpperCase())) {
      await prefs.setStringList(_keyPendingSent, pending);
    }

    _notifyFriendListeners();
    return added;
  }

  Future<bool> declineRequest(FriendRequest req) async {
    try {
      final headers = await _authHeaders();
      final res = await clientHelper.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/decline'),
        headers: headers,
        body: jsonEncode({'requestId': req.id}),
      );

      if (res.statusCode != 200) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // Remove from cached incoming requests
    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedIncomingRequests();
    final updated = cached.where((r) => r.id != req.id).toList();
    await prefs.setStringList(
      _keyIncomingRequests,
      updated.map((r) => jsonEncode(r.toJson())).toList(),
    );

    _notifyFriendListeners();
    return true;
  }

  // --- SOCIAL ALBUM INVITATIONS & SYNC ---

  Future<bool> sendAlbumInvite({
    required String albumId,
    required String albumName,
    required String toFriendCode,
  }) async {
    final cleanTo = toFriendCode.trim().toUpperCase();
    final myCode = friendCode.trim().toUpperCase();
    if (cleanTo.isEmpty || cleanTo == myCode) return false;

    try {
      // 1. Create claim token for ZK key exchange
      String? claimToken;
      String? pubKey;
      try {
        final claim = await InviteService.instance.createInviteClaim(
          albumId: albumId,
        );
        if (claim != null) {
          claimToken = claim.claimToken;
          pubKey = claim.inviterPubKey;
        }
      } catch (_) {}

      // 2. Post album invite to backend
      final headers = await _authHeaders();
      final res = await clientHelper.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/invite'),
        headers: headers,
        body: jsonEncode({
          'albumId': albumId,
          'albumName': albumName,
          'toCode': cleanTo,
          'fromName': username,
          'claimToken': claimToken,
          'inviterPubKey': pubKey,
        }),
      );

      if (res.statusCode == 200) {
        // Track as invited member on local album
        final friendName = await getFriendName(cleanTo);
        await LocalStorageService.instance.addAlbumMember(
          albumId,
          cleanTo,
          displayName: friendName ?? cleanTo,
          role: 'invited',
        );
        _notifyFriendListeners();
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<List<AlbumInvite>> getCachedIncomingAlbumInvites() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyIncomingAlbumInvites) ?? [];
    return rawList
        .map((str) {
          try {
            return AlbumInvite.fromJson(
              jsonDecode(str) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AlbumInvite>()
        .toList();
  }

  Future<List<AlbumInvite>> pollIncomingAlbumInvites() async {
    final myCode = friendCode.trim().toUpperCase();
    if (myCode.isEmpty) return getCachedIncomingAlbumInvites();

    try {
      final headers = await _authHeaders();
      final res = await clientHelper.get(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/invites/$myCode'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['invites'] as List? ?? []);

        final parsed = list
            .map((item) => AlbumInvite.fromJson(item as Map<String, dynamic>))
            .toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _keyIncomingAlbumInvites,
          parsed.map((r) => jsonEncode(r.toJson())).toList(),
        );
        _notifyFriendListeners();
        return parsed;
      }
    } catch (_) {}

    return getCachedIncomingAlbumInvites();
  }

  Future<bool> acceptAlbumInvite(AlbumInvite invite) async {
    try {
      final headers = await _authHeaders();
      final res = await clientHelper.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/accept'),
        headers: headers,
        body: jsonEncode({'inviteId': invite.id}),
      );

      if (res.statusCode != 200) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // Ensure album exists in local store
    await LocalStorageService.instance.ensureAlbum(
      id: invite.albumId,
      name: invite.albumName,
    );

    // Track inviter as owner/member and myself as member
    await LocalStorageService.instance.addAlbumMember(
      invite.albumId,
      invite.fromCode,
      displayName: invite.fromName ?? invite.fromCode,
      role: 'owner',
    );
    await LocalStorageService.instance.addAlbumMember(
      invite.albumId,
      friendCode.trim().toUpperCase(),
      displayName: username,
      role: 'member',
    );

    // If claim token is present, unseal the collection key
    if (invite.claimToken != null && invite.claimToken!.isNotEmpty) {
      try {
        await InviteService.instance.fetchAndUnsealCollectionKey(
          claimToken: invite.claimToken!,
          albumId: invite.albumId,
        );
      } catch (_) {}
    }

    // Remove from cached incoming album invites
    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedIncomingAlbumInvites();
    final updated = cached.where((i) => i.id != invite.id).toList();
    await prefs.setStringList(
      _keyIncomingAlbumInvites,
      updated.map((i) => jsonEncode(i.toJson())).toList(),
    );

    _notifyFriendListeners();
    return true;
  }

  Future<bool> declineAlbumInvite(AlbumInvite invite) async {
    try {
      final headers = await _authHeaders();
      final res = await clientHelper.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/decline'),
        headers: headers,
        body: jsonEncode({'inviteId': invite.id}),
      );

      if (res.statusCode != 200) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // Remove from cached incoming album invites
    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedIncomingAlbumInvites();
    final updated = cached.where((i) => i.id != invite.id).toList();
    await prefs.setStringList(
      _keyIncomingAlbumInvites,
      updated.map((i) => jsonEncode(i.toJson())).toList(),
    );

    _notifyFriendListeners();
    return true;
  }

  /// Fetch all active server-backed albums for this authenticated account from D1
  Future<List<Map<String, dynamic>>> fetchServerAlbums() async {
    try {
      final headers = await _authHeaders();
      final res = await clientHelper.get(
        Uri.parse('${AppConfig.backendBaseUrl}/albums'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['albums'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// Register an album on the canonical D1 backend
  Future<bool> registerAlbumOnServer({
    required String albumId,
    required String title,
    String? storageType,
    String? storageReference,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await clientHelper.post(
        Uri.parse('${AppConfig.backendBaseUrl}/albums'),
        headers: headers,
        body: jsonEncode({
          'id': albumId,
          'title': title,
          'name': title,
          'storageType': storageType ?? 'local',
          'storageReference': storageReference,
        }),
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  final List<void Function()> _friendListeners = [];
  void addFriendListener(void Function() listener) =>
      _friendListeners.add(listener);
  void removeFriendListener(void Function() listener) =>
      _friendListeners.remove(listener);

  void _notifyFriendListeners() {
    for (final listener in List.of(_friendListeners)) {
      listener();
    }
  }

  static String _generateFriendCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final buffer = StringBuffer('KIOKU-');
    for (var i = 0; i < 4; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}
