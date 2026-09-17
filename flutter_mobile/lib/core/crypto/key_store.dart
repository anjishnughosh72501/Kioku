import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_core.dart';
import 'recovery_service.dart';

class VaultRecoveryRequiredException implements Exception {
  final String message;
  const VaultRecoveryRequiredException([
    this.message = 'An existing vault was detected, but master encryption keys are missing from secure storage. '
        'Please restore your access using your 24-word recovery phrase.',
  ]);

  @override
  String toString() => message;
}

abstract class ISecureStorageProvider {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String? value});
  Future<void> delete({required String key});
  Future<bool> containsKey({required String key});
}

class FlutterSecureStorageWrapper implements ISecureStorageProvider {
  final FlutterSecureStorage _storage;

  const FlutterSecureStorageWrapper([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<bool> containsKey({required String key}) => _storage.containsKey(key: key);
}

class InMemorySecureStorage implements ISecureStorageProvider {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key}) async => _data[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async => _data.remove(key);

  @override
  Future<bool> containsKey({required String key}) async => _data.containsKey(key);

  void clear() => _data.clear();
}

class KeyStore {
  KeyStore({ISecureStorageProvider? storage})
      : _storage = storage ?? const FlutterSecureStorageWrapper();

  static final KeyStore instance = KeyStore();

  final ISecureStorageProvider _storage;

  static const _kMasterKey = 'kioku_sec_master_key';
  static const _kMasterKeyBackup = 'kioku_sec_master_key_durable_backup';
  static const _kDevicePubKey = 'kioku_sec_dev_pub_key';
  static const _kDeviceSecKey = 'kioku_sec_dev_sec_key';
  static const _kDeviceSecKeyNonce = 'kioku_sec_dev_sec_key_nonce';
  static const _kRecoveryBlob = 'kioku_sec_recovery_blob';
  static const _kRecoveryNonce = 'kioku_sec_recovery_nonce';
  static const _kRecoveryBlobBackup = 'kioku_sec_recovery_blob_backup';
  static const _kRecoveryNonceBackup = 'kioku_sec_recovery_nonce_backup';
  static const _kRecoveryPhraseEncrypted = 'kioku_sec_rec_phrase_enc';
  static const _kRecoveryPhraseNonce = 'kioku_sec_rec_phrase_nonce';
  static const _kCollectionKeyPrefix = 'kioku_sec_coll_key_';
  static const _kCollectionNoncePrefix = 'kioku_sec_coll_nonce_';

  Uint8List? _cachedMasterKey;
  Uint8List? _cachedDevicePubKey;
  Uint8List? _cachedDeviceSecKey;
  bool _needsRecovery = false;

  bool get needsRecovery => _needsRecovery;

  /// Check if master key exists
  Future<bool> hasMasterKey() async {
    if (_cachedMasterKey != null) return true;
    return await _storage.containsKey(key: _kMasterKey);
  }

  /// Check whether prior encrypted vault data exists on device
  Future<bool> hasExistingEncryptedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_kRecoveryBlobBackup)) return true;
      final albums = prefs.getString('kioku_local_albums');
      if (albums != null && albums.isNotEmpty && albums != '[]') return true;
      final keys = prefs.getKeys();
      if (keys.any((k) => k.startsWith('kioku_local_memories_'))) return true;
    } catch (_) {}
    return false;
  }

  /// Initialize keystore: generates masterKey + device keypair if not present.
  /// Throws [VaultRecoveryRequiredException] if previous vault data exists but keys were wiped.
  Future<String?> initialize({String? recoveryPhrase}) async {
    await CryptoCore.instance.init();
    if (await hasMasterKey()) {
      _needsRecovery = false;
      await getMasterKey();
      return null;
    }

    if (recoveryPhrase != null && recoveryPhrase.isNotEmpty) {
      await restoreFromRecoveryPhrase(recoveryPhrase);
      _needsRecovery = false;
      return recoveryPhrase;
    }

    // Safety guard: If no master key is in secure storage, check if prior vault data exists.
    // If so, do not silently generate an incompatible new master key!
    if (await hasExistingEncryptedData()) {
      _needsRecovery = true;
      throw const VaultRecoveryRequiredException();
    }

    _needsRecovery = false;

    // Generate fresh master key
    final masterKey = CryptoCore.instance.generateRandomKey();
    await _storage.write(key: _kMasterKey, value: base64Encode(masterKey));
    _cachedMasterKey = masterKey;

    // Generate device X25519 identity keypair
    final keyPair = CryptoCore.instance.generateKeyPair();
    _cachedDevicePubKey = keyPair.publicKey;
    _cachedDeviceSecKey = keyPair.secretKey;

    // Wrap device private key with masterKey
    final wrappedDeviceKey = CryptoCore.instance.wrapKey(keyPair.secretKey, masterKey);
    await _storage.write(key: _kDevicePubKey, value: base64Encode(keyPair.publicKey));
    await _storage.write(key: _kDeviceSecKey, value: base64Encode(wrappedDeviceKey.cipherText));
    await _storage.write(key: _kDeviceSecKeyNonce, value: base64Encode(wrappedDeviceKey.nonce));

    // Generate recovery phrase & mutual recovery blob
    final phrase = recoveryPhrase ?? RecoveryService.instance.generateRecoveryPhrase();
    final recoveryKey = RecoveryService.instance.phraseToKey(phrase);
    final recoveryBlob = RecoveryService.instance.createRecoveryBlob(masterKey, recoveryKey);

    await _storage.write(
      key: _kRecoveryBlob,
      value: base64Encode(recoveryBlob.encryptedMasterKey),
    );
    await _storage.write(
      key: _kRecoveryNonce,
      value: base64Encode(recoveryBlob.nonce),
    );

    // Defense-in-depth: Save secondary copy in SharedPreferences so masterKey can be recovered
    // even if secure storage is wiped by the OS or during updates.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMasterKeyBackup, base64Encode(masterKey));
      await prefs.setString(_kRecoveryBlobBackup, base64Encode(recoveryBlob.encryptedMasterKey));
      await prefs.setString(_kRecoveryNonceBackup, base64Encode(recoveryBlob.nonce));
    } catch (_) {}

    // Save phrase encrypted with masterKey for safe viewing in user settings
    final encPhrase = CryptoCore.instance.encryptMetadata({'phrase': phrase}, masterKey);
    await _storage.write(key: _kRecoveryPhraseEncrypted, value: base64Encode(encPhrase.cipherText));
    await _storage.write(key: _kRecoveryPhraseNonce, value: base64Encode(encPhrase.nonce));

    return phrase;
  }

  /// Gets the recovery phrase decrypted with masterKey
  Future<String> getRecoveryPhrase() async {
    final enc = await _storage.read(key: _kRecoveryPhraseEncrypted);
    final nonce = await _storage.read(key: _kRecoveryPhraseNonce);
    final masterKey = await getMasterKey();
    if (enc == null || nonce == null) {
      final phrase = RecoveryService.instance.generateRecoveryPhrase();
      final encPhrase = CryptoCore.instance.encryptMetadata({'phrase': phrase}, masterKey);
      await _storage.write(key: _kRecoveryPhraseEncrypted, value: base64Encode(encPhrase.cipherText));
      await _storage.write(key: _kRecoveryPhraseNonce, value: base64Encode(encPhrase.nonce));
      return phrase;
    }
    final meta = CryptoCore.instance.decryptMetadata(
      base64Decode(enc),
      base64Decode(nonce),
      masterKey,
    );
    return meta['phrase'] as String;
  }

  /// Gets the durable 32-byte master key (auto-initializes if not yet generated)
  Future<Uint8List> getMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey!;
    final raw = await _storage.read(key: _kMasterKey);
    if (raw == null || raw.isEmpty) {
      if (await hasExistingEncryptedData()) {
        _needsRecovery = true;
        throw const VaultRecoveryRequiredException();
      }
      await initialize();
      return _cachedMasterKey!;
    }
    final key = base64Decode(raw);
    _cachedMasterKey = key;
    return key;
  }

  /// Gets the device public key for sharing/receiving collection keys
  Future<Uint8List> getDevicePublicKey() async {
    if (_cachedDevicePubKey != null) return _cachedDevicePubKey!;
    final raw = await _storage.read(key: _kDevicePubKey);
    if (raw == null || raw.isEmpty) {
      await initialize();
      return _cachedDevicePubKey!;
    }
    final pk = base64Decode(raw);
    _cachedDevicePubKey = pk;
    return pk;
  }

  /// Gets the device secret key (unwrapped with masterKey)
  Future<Uint8List> getDevicePrivateKey() async {
    if (_cachedDeviceSecKey != null) return _cachedDeviceSecKey!;
    final enc = await _storage.read(key: _kDeviceSecKey);
    final nonceRaw = await _storage.read(key: _kDeviceSecKeyNonce);
    if (enc == null || nonceRaw == null) {
      await initialize();
      return _cachedDeviceSecKey!;
    }
    final masterKey = await getMasterKey();
    final sk = CryptoCore.instance.unwrapKey(
      base64Decode(enc),
      base64Decode(nonceRaw),
      masterKey,
    );
    _cachedDeviceSecKey = sk;
    return sk;
  }

  /// Gets or generates the Album Encryption Key (AEK) / collectionKey for an album
  Future<Uint8List> getOrCreateCollectionKey(String albumId) async {
    var enc = await _storage.read(key: _kCollectionKeyPrefix + albumId);
    var nonce = await _storage.read(key: _kCollectionNoncePrefix + albumId);
    if (enc == null || nonce == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        enc = prefs.getString(_kCollectionKeyPrefix + albumId);
        nonce = prefs.getString(_kCollectionNoncePrefix + albumId);
      } catch (_) {}
    }

    final masterKey = await getMasterKey();

    if (enc != null && nonce != null) {
      return CryptoCore.instance.unwrapKey(
        base64Decode(enc),
        base64Decode(nonce),
        masterKey,
      );
    }

    // Generate fresh collection key for new album
    final collectionKey = CryptoCore.instance.generateRandomKey();
    await saveCollectionKey(albumId, collectionKey);
    return collectionKey;
  }

  /// Saves a collection key (wrapped with masterKey)
  Future<void> saveCollectionKey(String albumId, Uint8List collectionKey) async {
    final masterKey = await getMasterKey();
    final wrapped = CryptoCore.instance.wrapKey(collectionKey, masterKey);
    await _storage.write(
      key: _kCollectionKeyPrefix + albumId,
      value: base64Encode(wrapped.cipherText),
    );
    await _storage.write(
      key: _kCollectionNoncePrefix + albumId,
      value: base64Encode(wrapped.nonce),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCollectionKeyPrefix + albumId, base64Encode(wrapped.cipherText));
      await prefs.setString(_kCollectionNoncePrefix + albumId, base64Encode(wrapped.nonce));
    } catch (_) {}
  }

  /// Gets the stored recovery blob (encryptedMasterKey, nonce), checking secure storage and backup
  Future<RecoveryBlob?> getRecoveryBlob() async {
    var enc = await _storage.read(key: _kRecoveryBlob);
    var nonce = await _storage.read(key: _kRecoveryNonce);
    if (enc == null || nonce == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        enc = prefs.getString(_kRecoveryBlobBackup);
        nonce = prefs.getString(_kRecoveryNonceBackup);
      } catch (_) {}
    }
    if (enc == null || nonce == null) return null;
    return RecoveryBlob(
      encryptedMasterKey: base64Decode(enc),
      nonce: base64Decode(nonce),
    );
  }

  /// Restores masterKey from recovery phrase
  Future<void> restoreFromRecoveryPhrase(String phrase) async {
    final trimmed = phrase.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!RecoveryService.instance.validatePhrase(trimmed)) {
      throw ArgumentError('Invalid 24-word recovery phrase');
    }
    final blob = await getRecoveryBlob();
    if (blob == null) {
      throw StateError('No recovery blob found to restore from');
    }
    final recoveredMasterKey = RecoveryService.instance.recoverMasterKey(
      phrase: trimmed,
      encryptedMasterKey: blob.encryptedMasterKey,
      nonce: blob.nonce,
    );
    await _storage.write(key: _kMasterKey, value: base64Encode(recoveredMasterKey));
    _cachedMasterKey = recoveredMasterKey;
    _needsRecovery = false;

    // Restore device keypair & recovery blobs
    final keyPair = CryptoCore.instance.generateKeyPair();
    _cachedDevicePubKey = keyPair.publicKey;
    _cachedDeviceSecKey = keyPair.secretKey;
    final wrappedDeviceKey = CryptoCore.instance.wrapKey(keyPair.secretKey, recoveredMasterKey);
    await _storage.write(key: _kDevicePubKey, value: base64Encode(keyPair.publicKey));
    await _storage.write(key: _kDeviceSecKey, value: base64Encode(wrappedDeviceKey.cipherText));
    await _storage.write(key: _kDeviceSecKeyNonce, value: base64Encode(wrappedDeviceKey.nonce));

    await _storage.write(
      key: _kRecoveryBlob,
      value: base64Encode(blob.encryptedMasterKey),
    );
    await _storage.write(
      key: _kRecoveryNonce,
      value: base64Encode(blob.nonce),
    );

    final encPhrase = CryptoCore.instance.encryptMetadata({'phrase': phrase}, recoveredMasterKey);
    await _storage.write(key: _kRecoveryPhraseEncrypted, value: base64Encode(encPhrase.cipherText));
    await _storage.write(key: _kRecoveryPhraseNonce, value: base64Encode(encPhrase.nonce));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRecoveryBlobBackup, base64Encode(blob.encryptedMasterKey));
      await prefs.setString(_kRecoveryNonceBackup, base64Encode(blob.nonce));
    } catch (_) {}
  }

  /// Clears in-memory key cache (e.g. on sign out)
  void clearMemoryCache() {
    _cachedMasterKey = null;
    _cachedDevicePubKey = null;
    _cachedDeviceSecKey = null;
  }
}
