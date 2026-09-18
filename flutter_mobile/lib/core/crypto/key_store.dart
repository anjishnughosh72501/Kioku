import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

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
  static const _kDevicePubKey = 'kioku_sec_dev_pub_key';
  static const _kDeviceSecKey = 'kioku_sec_dev_sec_key';
  static const _kDeviceSecKeyNonce = 'kioku_sec_dev_sec_key_nonce';
  static const _kRecoveryBlob = 'kioku_sec_recovery_blob';
  static const _kRecoveryNonce = 'kioku_sec_recovery_nonce';
  static const _kRecoveryPhraseEncrypted = 'kioku_sec_rec_phrase_enc';
  static const _kRecoveryPhraseNonce = 'kioku_sec_rec_phrase_nonce';
  static const _kCollectionKeyPrefix = 'kioku_sec_coll_key_';
  static const _kCollectionNoncePrefix = 'kioku_sec_coll_nonce_';

  Uint8List? _cachedMasterKey;
  Uint8List? _cachedDevicePubKey;
  Uint8List? _cachedDeviceSecKey;
  bool get needsRecovery => false;

  /// Check if master key exists
  Future<bool> hasMasterKey() async {
    if (_cachedMasterKey != null) return true;
    return await _storage.containsKey(key: _kMasterKey);
  }

  /// Check whether prior encrypted vault data exists on device
  Future<bool> hasExistingEncryptedData() async => false;

  /// Initialize keystore: generates masterKey + device keypair if not present.
  Future<String?> initialize({String? recoveryPhrase}) async {
    await CryptoCore.instance.init();
    if (await hasMasterKey()) {
      await getMasterKey();
      return null;
    }

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

    return null;
  }

  /// Gets the recovery phrase (stubbed for compatibility)
  Future<String> getRecoveryPhrase() async => '';

  /// Gets the durable 32-byte master key (auto-initializes if not yet generated)
  Future<Uint8List> getMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey!;
    var raw = await _storage.read(key: _kMasterKey);

    if (raw == null || raw.isEmpty) {
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
    final enc = await _storage.read(key: _kCollectionKeyPrefix + albumId);
    final nonce = await _storage.read(key: _kCollectionNoncePrefix + albumId);

    final masterKey = await getMasterKey();

    if (enc != null && nonce != null) {
      try {
        return CryptoCore.instance.unwrapKey(
          base64Decode(enc),
          base64Decode(nonce),
          masterKey,
        );
      } catch (_) {}
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
  }

  /// Rotates the collection key for an album (e.g. after removing a member)
  Future<Uint8List> rotateCollectionKey(String albumId) async {
    final newCollectionKey = CryptoCore.instance.generateRandomKey();
    await saveCollectionKey(albumId, newCollectionKey);
    return newCollectionKey;
  }

  /// Gets the stored recovery blob (encryptedMasterKey, nonce)
  Future<RecoveryBlob?> getRecoveryBlob() async {
    final enc = await _storage.read(key: _kRecoveryBlob);
    final nonce = await _storage.read(key: _kRecoveryNonce);
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
  }

  /// Clears in-memory key cache (e.g. on sign out)
  void clearMemoryCache() {
    _cachedMasterKey = null;
    _cachedDevicePubKey = null;
    _cachedDeviceSecKey = null;
  }
}
