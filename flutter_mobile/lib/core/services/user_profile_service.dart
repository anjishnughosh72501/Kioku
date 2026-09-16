import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String username;
  final String friendCode;

  const UserProfile({
    required this.username,
    required this.friendCode,
  });
}

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const String _keyUsername = 'kioku_username';
  static const String _keyFriendCode = 'kioku_friend_code';
  static const String _keyConnectedFriends = 'kioku_connected_friends';

  UserProfile? _currentProfile;
  final List<void Function(UserProfile)> _listeners = [];

  void addListener(void Function(UserProfile) listener) => _listeners.add(listener);
  void removeListener(void Function(UserProfile) listener) => _listeners.remove(listener);

  UserProfile? get currentProfile => _currentProfile;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    var friendCode = prefs.getString(_keyFriendCode);

    if (friendCode == null || friendCode.isEmpty) {
      friendCode = _generateFriendCode();
      await prefs.setString(_keyFriendCode, friendCode);
    }

    if (username != null && username.isNotEmpty) {
      _currentProfile = UserProfile(
        username: username,
        friendCode: friendCode,
      );
    }
  }

  bool get hasUsername => _currentProfile != null && _currentProfile!.username.isNotEmpty;

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

  Future<bool> addFriend(String friendCode) async {
    final code = friendCode.trim().toUpperCase();
    if (code.isEmpty || code == _currentProfile?.friendCode) return false;

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyConnectedFriends) ?? [];
    if (!list.contains(code)) {
      list.add(code);
      await prefs.setStringList(_keyConnectedFriends, list);
      return true;
    }
    return false;
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
