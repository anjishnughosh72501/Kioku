import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mobile/core/config.dart';
import 'package:flutter_mobile/core/services/invite_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';

class UserProfile {
  final String username;
  final String friendCode;

  const UserProfile({
    required this.username,
    required this.friendCode,
  });
}

enum FriendRequestResult {
  sent,
  alreadySent,
  alreadyFriends,
  sameUser,
  error,
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
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const String _keyUsername = 'kioku_username';
  static const String _keyFriendCode = 'kioku_friend_code';
  static const String _keyFriendSecret = 'kioku_friend_device_secret';
  static const String _keyConnectedFriends = 'kioku_connected_friends';
  static const String _keyPendingSent = 'kioku_pending_sent_requests';
  static const String _keyIncomingRequests = 'kioku_cached_incoming_requests';
  static const String _keyIncomingAlbumInvites = 'kioku_cached_album_invites';

  http.Client httpClient = http.Client();

  UserProfile? _currentProfile;
  String? _cachedToken;
  final List<void Function(UserProfile)> _listeners = [];

  void addListener(void Function(UserProfile) listener) => _listeners.add(listener);
  void removeListener(void Function(UserProfile) listener) => _listeners.remove(listener);

  UserProfile? get currentProfile => _currentProfile;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    var friendCode = prefs.getString(_keyFriendCode);
    var deviceSecret = prefs.getString(_keyFriendSecret);

    if (friendCode == null || friendCode.isEmpty) {
      friendCode = _generateFriendCode();
      await prefs.setString(_keyFriendCode, friendCode);
    }

    if (deviceSecret == null || deviceSecret.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      deviceSecret = base64UrlEncode(values);
      await prefs.setString(_keyFriendSecret, deviceSecret);
    }

    if (username != null && username.isNotEmpty) {
      _currentProfile = UserProfile(
        username: username,
        friendCode: friendCode,
      );
    }
  }

  /// Request or retrieve a cached signed JWT authorization token for this device's friend code
  Future<String?> getAuthToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken != null) {
      return _cachedToken;
    }

    final prefs = await SharedPreferences.getInstance();
    var secret = prefs.getString(_keyFriendSecret);
    if (secret == null || secret.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      secret = base64UrlEncode(values);
      await prefs.setString(_keyFriendSecret, secret);
    }

    final myCode = friendCode.trim().toUpperCase();
    try {
      final res = await httpClient.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'friendCode': myCode,
          'secret': secret,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedToken = data['token'] as String?;
        return _cachedToken;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await getAuthToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
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

    final profile = UserProfile(
      username: trimmed,
      friendCode: friendCode,
    );
    _currentProfile = profile;
    for (final listener in List.of(_listeners)) {
      listener(profile);
    }
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
    return prefs.getString('kioku_friend_name_${friendCode.trim().toUpperCase()}');
  }

  Future<bool> removeFriend(String friendCode) async {
    final code = friendCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyConnectedFriends) ?? [];
    await prefs.remove('kioku_friend_name_$code');
    if (list.remove(code)) {
      await prefs.setStringList(_keyConnectedFriends, list);
      _notifyFriendListeners();
      return true;
    }
    return false;
  }

  Future<List<String>> getPendingSentRequests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyPendingSent) ?? [];
  }

  Future<FriendRequestResult> sendFriendRequest(String toCode, {String? myName}) async {
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
      final headers = await _authHeaders();
      final res = await httpClient.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/request'),
        headers: headers,
        body: jsonEncode({
          'toCode': cleanTo,
          'fromName': myName ?? username,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_keyPendingSent) ?? [];
        if (!list.contains(cleanTo)) {
          list.add(cleanTo);
          await prefs.setStringList(_keyPendingSent, list);
        }
        if (data['alreadySent'] == true) {
          return FriendRequestResult.alreadySent;
        }
        _notifyFriendListeners();
        return FriendRequestResult.sent;
      }
    } catch (_) {
      // Fallback for offline or direct mode: still track pending locally
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyPendingSent) ?? [];
      if (!list.contains(cleanTo)) {
        list.add(cleanTo);
        await prefs.setStringList(_keyPendingSent, list);
        _notifyFriendListeners();
        return FriendRequestResult.sent;
      }
    }
    return FriendRequestResult.error;
  }

  Future<List<FriendRequest>> getCachedIncomingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_keyIncomingRequests) ?? [];
    return rawList
        .map((str) {
          try {
            return FriendRequest.fromJson(jsonDecode(str) as Map<String, dynamic>);
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
      final headers = await _authHeaders();
      final res = await httpClient.get(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/requests/$myCode'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

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
                  final ackHeaders = await _authHeaders();
                  await httpClient.post(
                    Uri.parse('${AppConfig.backendBaseUrl}/friends/ack'),
                    headers: ackHeaders,
                    body: jsonEncode({'requestId': reqId}),
                  ).timeout(const Duration(seconds: 4));
                } catch (_) {}
              }
            }
          }
        }

        // 2. Process incoming pending requests
        final parsed = list
            .map((item) => FriendRequest.fromJson(item as Map<String, dynamic>))
            .where((req) => !friends.contains(req.fromCode.trim().toUpperCase()))
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
      final headers = await _authHeaders();
      await httpClient.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/accept'),
        headers: headers,
        body: jsonEncode({
          'requestId': req.id,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

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
      await httpClient.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/decline'),
        headers: headers,
        body: jsonEncode({
          'requestId': req.id,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

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
        final claim = await InviteService.instance.createInviteClaim(albumId: albumId);
        if (claim != null) {
          claimToken = claim.claimToken;
          pubKey = claim.inviterPubKey;
        }
      } catch (_) {}

      // 2. Post album invite to backend
      final headers = await _authHeaders();
      final res = await httpClient.post(
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
      ).timeout(const Duration(seconds: 4));

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
            return AlbumInvite.fromJson(jsonDecode(str) as Map<String, dynamic>);
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
      final res = await httpClient.get(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/invites/$myCode'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

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
      await httpClient.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/accept'),
        headers: headers,
        body: jsonEncode({
          'inviteId': invite.id,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

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
      await httpClient.post(
        Uri.parse('${AppConfig.backendBaseUrl}/friends/albums/decline'),
        headers: headers,
        body: jsonEncode({
          'inviteId': invite.id,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

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

  final List<void Function()> _friendListeners = [];
  void addFriendListener(void Function() listener) => _friendListeners.add(listener);
  void removeFriendListener(void Function() listener) => _friendListeners.remove(listener);

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
