import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mobile/core/crypto/recovery_service.dart';

/// Service responsible for managing app-resume lock, PIN authentication,
/// and recovery phrase fallback for intimate privacy protection.
class AppLockService with WidgetsBindingObserver {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const String _keyLockEnabled = 'kioku_app_lock_enabled';
  static const String _keyPinHash = 'kioku_app_lock_pin_hash';
  static const String _keyPinSalt = 'kioku_app_lock_pin_salt';
  static const String _keyGraceSeconds = 'kioku_app_lock_grace_seconds';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _initialized = false;
  bool _isEnabled = false;
  int _graceSeconds = 0;
  DateTime? _backgroundedTime;

  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  bool get isEnabled => _isEnabled;
  bool get isLocked => isLockedNotifier.value;
  int get graceSeconds => _graceSeconds;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_keyLockEnabled) ?? false;
    _graceSeconds = prefs.getInt(_keyGraceSeconds) ?? 0;

    // Check if PIN actually exists
    final pinHash = await _secureStorage.read(key: _keyPinHash);
    if (_isEnabled && (pinHash == null || pinHash.isEmpty)) {
      _isEnabled = false;
      await prefs.setBool(_keyLockEnabled, false);
    }

    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedTime != null) {
        final elapsed = DateTime.now().difference(_backgroundedTime!).inSeconds;
        _backgroundedTime = null;
        if (elapsed >= _graceSeconds) {
          lock();
        }
      }
    }
  }

  void lock() {
    if (_isEnabled) {
      isLockedNotifier.value = true;
    }
  }

  void unlock() {
    isLockedNotifier.value = false;
  }

  Future<bool> hasPin() async {
    final hash = await _secureStorage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (i) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = _hashPin(pin, salt);

    await _secureStorage.write(key: _keyPinSalt, value: salt);
    await _secureStorage.write(key: _keyPinHash, value: hash);

    final prefs = await SharedPreferences.getInstance();
    _isEnabled = true;
    await prefs.setBool(_keyLockEnabled, true);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _secureStorage.read(key: _keyPinSalt);
    final storedHash = await _secureStorage.read(key: _keyPinHash);

    if (salt == null || storedHash == null) return false;

    final computedHash = _hashPin(pin, salt);
    final matches = computedHash == storedHash;
    if (matches) {
      unlock();
    }
    return matches;
  }

  Future<bool> disableLock(String currentPin) async {
    final valid = await verifyPin(currentPin);
    if (!valid) return false;

    final prefs = await SharedPreferences.getInstance();
    _isEnabled = false;
    await prefs.setBool(_keyLockEnabled, false);
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.delete(key: _keyPinSalt);
    unlock();
    return true;
  }

  Future<bool> resetWithRecoveryPhrase({
    required String phrase,
    required String newPin,
  }) async {
    final isValidPhrase = RecoveryService.instance.validatePhrase(phrase);
    if (!isValidPhrase) return false;

    await setPin(newPin);
    unlock();
    return true;
  }

  Future<void> setGraceSeconds(int seconds) async {
    _graceSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGraceSeconds, seconds);
  }
}
