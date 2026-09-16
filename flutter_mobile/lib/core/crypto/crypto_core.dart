import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:sodium_libs/sodium_libs.dart';

class WrappedKey {
  final Uint8List cipherText;
  final Uint8List nonce;

  const WrappedKey({required this.cipherText, required this.nonce});
}

class CryptoCore {
  CryptoCore._();
  static final CryptoCore instance = CryptoCore._();

  Sodium? _sodium;

  Sodium get sodium {
    final s = _sodium;
    if (s == null) {
      throw StateError('CryptoCore not initialized. Call CryptoCore.instance.init() first.');
    }
    return s;
  }

  bool get isInitialized => _sodium != null;

  Future<void> init([Sodium? customSodium]) async {
    if (_sodium != null) return;
    _sodium = customSodium ?? await SodiumInit.init();
  }

  /// 256-bit random key (used for MasterKey, CollectionKey, FileKey, RecoveryKey)
  Uint8List generateRandomKey() {
    return sodium.randombytes.buf(32);
  }

  /// Generate X25519 keypair for anonymous public-key encryption (crypto_box_seal)
  ({Uint8List publicKey, Uint8List secretKey}) generateKeyPair() {
    final kp = sodium.crypto.box.keyPair();
    final pk = Uint8List.fromList(kp.publicKey);
    final sk = kp.secretKey.extractBytes();
    kp.dispose();
    return (publicKey: pk, secretKey: sk);
  }

  /// Wrap a symmetric key or secret using crypto_secretbox_easy (XSalsa20-Poly1305)
  WrappedKey wrapKey(Uint8List plainKey, Uint8List wrappingKey) {
    final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
    final secureWrappingKey = sodium.secureCopy(wrappingKey);
    try {
      final cipherText = sodium.crypto.secretBox.easy(
        message: plainKey,
        nonce: nonce,
        key: secureWrappingKey,
      );
      return WrappedKey(cipherText: cipherText, nonce: nonce);
    } finally {
      secureWrappingKey.dispose();
    }
  }

  /// Unwrap a symmetric key using crypto_secretbox_open_easy
  Uint8List unwrapKey(Uint8List cipherText, Uint8List nonce, Uint8List wrappingKey) {
    final secureWrappingKey = sodium.secureCopy(wrappingKey);
    try {
      return sodium.crypto.secretBox.openEasy(
        cipherText: cipherText,
        nonce: nonce,
        key: secureWrappingKey,
      );
    } finally {
      secureWrappingKey.dispose();
    }
  }

  /// Seal a key or message for a recipient's X25519 public key (crypto_box_seal)
  Uint8List sealForPublicKey(Uint8List message, Uint8List recipientPublicKey) {
    return sodium.crypto.box.seal(
      message: message,
      publicKey: recipientPublicKey,
    );
  }

  /// Unseal a message sealed with crypto_box_seal using own keypair
  Uint8List unsealWithPrivateKey(
    Uint8List cipherText,
    Uint8List recipientPublicKey,
    Uint8List recipientSecretKey,
  ) {
    final secureSk = sodium.secureCopy(recipientSecretKey);
    try {
      return sodium.crypto.box.sealOpen(
        cipherText: cipherText,
        publicKey: recipientPublicKey,
        secretKey: secureSk,
      );
    } finally {
      secureSk.dispose();
    }
  }

  /// Encrypt a stream of chunks via crypto_secretstream (chunked XChaCha20-Poly1305).
  /// Output stream contains secretstream header as the first chunk followed by cipher chunks.
  Stream<Uint8List> encryptStream(Stream<Uint8List> inputStream, Uint8List fileKey) {
    final secureKey = sodium.secureCopy(fileKey);
    // SecretStream.push handles streaming chunked encryption
    final outStream = sodium.crypto.secretStream.push(
      messageStream: inputStream,
      key: secureKey,
    );
    // Dispose key when stream completes or errors
    return outStream.transform(
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleDone: (sink) {
          secureKey.dispose();
          sink.close();
        },
        handleError: (error, stack, sink) {
          secureKey.dispose();
          sink.addError(error, stack);
        },
      ),
    );
  }

  /// Decrypt a stream of chunks via crypto_secretstream.
  /// Input stream must begin with the secretstream header as emitted by encryptStream.
  Stream<Uint8List> decryptStream(Stream<Uint8List> cipherStream, Uint8List fileKey) {
    final secureKey = sodium.secureCopy(fileKey);
    final outStream = sodium.crypto.secretStream.pull(
      cipherStream: cipherStream,
      key: secureKey,
    );
    return outStream.transform(
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleDone: (sink) {
          secureKey.dispose();
          sink.close();
        },
        handleError: (error, stack, sink) {
          secureKey.dispose();
          sink.addError(error, stack);
        },
      ),
    );
  }

  /// Encrypt small byte payloads (e.g. thumbnail) using crypto_secretbox_easy
  WrappedKey encryptBytes(Uint8List plainBytes, Uint8List key) {
    return wrapKey(plainBytes, key);
  }

  /// Decrypt small byte payloads using crypto_secretbox_open_easy
  Uint8List decryptBytes(Uint8List cipherBytes, Uint8List nonce, Uint8List key) {
    return unwrapKey(cipherBytes, nonce, key);
  }

  /// Encrypt arbitrary metadata JSON dictionary with fileKey
  WrappedKey encryptMetadata(Map<String, dynamic> metadata, Uint8List fileKey) {
    final jsonStr = jsonEncode(metadata);
    final plainBytes = Uint8List.fromList(utf8.encode(jsonStr));
    return wrapKey(plainBytes, fileKey);
  }

  /// Decrypt metadata back to Map
  Map<String, dynamic> decryptMetadata(
    Uint8List cipherText,
    Uint8List nonce,
    Uint8List fileKey,
  ) {
    final plainBytes = unwrapKey(cipherText, nonce, fileKey);
    final jsonStr = utf8.decode(plainBytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Derive a 12-word BIP39 mnemonic Safety Number / Verification ID from an X25519 public key.
  /// Used for Ente / Signal style out-of-band identity verification.
  String deriveVerificationId(Uint8List publicKey) {
    // Hash public key with genericHash (BLAKE2b) or SHA256 (16 bytes = 128 bit entropy = 12 words)
    final hash16 = sodium.crypto.genericHash(
      message: publicKey,
      outLen: 16,
    );
    final hexStr = hash16.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return bip39.entropyToMnemonic(hexStr);
  }
}
