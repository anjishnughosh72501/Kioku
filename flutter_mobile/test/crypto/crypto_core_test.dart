import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/encrypted_envelope.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/crypto/recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  group('CryptoCore Primitives', () {
    test('generateRandomKey returns 32 random bytes', () {
      final key1 = CryptoCore.instance.generateRandomKey();
      final key2 = CryptoCore.instance.generateRandomKey();
      expect(key1.length, equals(32));
      expect(key2.length, equals(32));
      expect(key1, isNot(equals(key2)));
    });

    test('generateKeyPair returns valid X25519 public and secret keys', () {
      final kp = CryptoCore.instance.generateKeyPair();
      expect(kp.publicKey.length, equals(32));
      expect(kp.secretKey.length, equals(32));
    });

    test('wrapKey and unwrapKey roundtrip cleanly', () {
      final plainKey = CryptoCore.instance.generateRandomKey();
      final wrappingKey = CryptoCore.instance.generateRandomKey();

      final wrapped = CryptoCore.instance.wrapKey(plainKey, wrappingKey);
      expect(wrapped.cipherText.length, greaterThan(32)); // 32 + 16 auth tag
      expect(wrapped.nonce.length, equals(24));

      final unwrapped = CryptoCore.instance.unwrapKey(
        wrapped.cipherText,
        wrapped.nonce,
        wrappingKey,
      );
      expect(unwrapped, equals(plainKey));
    });

    test('unwrapKey fails with wrong wrapping key', () {
      final plainKey = CryptoCore.instance.generateRandomKey();
      final key1 = CryptoCore.instance.generateRandomKey();
      final key2 = CryptoCore.instance.generateRandomKey();

      final wrapped = CryptoCore.instance.wrapKey(plainKey, key1);
      expect(
        () => CryptoCore.instance.unwrapKey(wrapped.cipherText, wrapped.nonce, key2),
        throwsA(isA<Exception>()),
      );
    });

    test('sealForPublicKey and unsealWithPrivateKey roundtrip cleanly', () {
      final recipientKp = CryptoCore.instance.generateKeyPair();
      final message = Uint8List.fromList(utf8.encode('Secret Album Key (AEK)'));

      final sealed = CryptoCore.instance.sealForPublicKey(message, recipientKp.publicKey);
      final unsealed = CryptoCore.instance.unsealWithPrivateKey(
        sealed,
        recipientKp.publicKey,
        recipientKp.secretKey,
      );

      expect(utf8.decode(unsealed), equals('Secret Album Key (AEK)'));
    });

    test('encryptStream and decryptStream streamingly encrypt chunks', () async {
      final fileKey = CryptoCore.instance.generateRandomKey();
      final chunk1 = Uint8List.fromList(utf8.encode('Photo Header Chunk 1'));
      final chunk2 = Uint8List.fromList(utf8.encode('Photo Body Chunk 2'));
      final chunk3 = Uint8List.fromList(utf8.encode('Photo Tail Chunk 3'));

      final inStream = Stream.fromIterable([chunk1, chunk2, chunk3]);
      final encryptedStream = CryptoCore.instance.encryptStream(inStream, fileKey);
      final encryptedChunks = await encryptedStream.toList();

      expect(encryptedChunks.length, greaterThanOrEqualTo(3));

      final decryptedStream = CryptoCore.instance.decryptStream(
        Stream.fromIterable(encryptedChunks),
        fileKey,
      );
      final decryptedChunks = await decryptedStream.toList();

      expect(decryptedChunks.length, equals(3));
      expect(utf8.decode(decryptedChunks[0]), equals('Photo Header Chunk 1'));
      expect(utf8.decode(decryptedChunks[1]), equals('Photo Body Chunk 2'));
      expect(utf8.decode(decryptedChunks[2]), equals('Photo Tail Chunk 3'));
    });

    test('encryptMetadata and decryptMetadata preserve full map structure', () {
      final fileKey = CryptoCore.instance.generateRandomKey();
      final meta = {
        'caption': 'Sunset over Kyoto',
        'taken_at': '2026-09-15T22:30:00Z',
        'uploader_name': 'Rick',
        'width': 4032,
        'height': 3024,
      };

      final enc = CryptoCore.instance.encryptMetadata(meta, fileKey);
      final dec = CryptoCore.instance.decryptMetadata(
        enc.cipherText,
        enc.nonce,
        fileKey,
      );

      expect(dec['caption'], equals('Sunset over Kyoto'));
      expect(dec['taken_at'], equals('2026-09-15T22:30:00Z'));
      expect(dec['uploader_name'], equals('Rick'));
      expect(dec['width'], equals(4032));
    });

    test('deriveVerificationId generates 12-word mnemonic for public key', () {
      final kp = CryptoCore.instance.generateKeyPair();
      final vid = CryptoCore.instance.deriveVerificationId(kp.publicKey);
      final words = vid.split(' ');
      expect(words.length, equals(12));
    });
  });

  group('EncryptedEnvelope Serialization', () {
    test('toBlob and fromBlob preserve all envelope components', () {
      final envelope = EncryptedEnvelope(
        objectId: 'media_test_123',
        wrappedFileKey: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        fileKeyNonce: Uint8List(24)..fillRange(0, 24, 9),
        encryptedMetadata: Uint8List.fromList([10, 11, 12, 13]),
        metadataNonce: Uint8List(24)..fillRange(0, 24, 14),
        encryptedThumbnail: Uint8List.fromList([20, 21, 22]),
        thumbnailNonce: Uint8List(24)..fillRange(0, 24, 23),
        cipherChunks: [
          Uint8List.fromList([30, 31, 32]),
          Uint8List.fromList([33, 34, 35]),
        ],
      );

      final blob = envelope.toBlob();
      expect(blob.length, greaterThan(100));

      final restored = EncryptedEnvelope.fromBlob(blob, objectId: 'media_test_123');
      expect(restored.objectId, equals('media_test_123'));
      expect(restored.wrappedFileKey, equals(envelope.wrappedFileKey));
      expect(restored.fileKeyNonce, equals(envelope.fileKeyNonce));
      expect(restored.encryptedMetadata, equals(envelope.encryptedMetadata));
      expect(restored.metadataNonce, equals(envelope.metadataNonce));
      expect(restored.encryptedThumbnail, equals(envelope.encryptedThumbnail));
      expect(restored.thumbnailNonce, equals(envelope.thumbnailNonce));
      expect(restored.cipherChunks.length, equals(2));
      expect(restored.cipherChunks[0], equals(envelope.cipherChunks[0]));
      expect(restored.cipherChunks[1], equals(envelope.cipherChunks[1]));
    });
  });

  group('RecoveryService & KeyStore', () {
    test('RecoveryService generates valid 24-word phrase and recovers master key', () {
      final masterKey = CryptoCore.instance.generateRandomKey();
      final phrase = RecoveryService.instance.generateRecoveryPhrase();
      expect(RecoveryService.instance.validatePhrase(phrase), isTrue);

      final recoveryKey = RecoveryService.instance.phraseToKey(phrase);
      final recoveryBlob = RecoveryService.instance.createRecoveryBlob(masterKey, recoveryKey);

      final recovered = RecoveryService.instance.recoverMasterKey(
        phrase: phrase,
        encryptedMasterKey: recoveryBlob.encryptedMasterKey,
        nonce: recoveryBlob.nonce,
      );

      expect(recovered, equals(masterKey));
    });

    test('KeyStore initialize and collectionKey management', () async {
      final inMemoryStorage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: inMemoryStorage);

      expect(await keyStore.hasMasterKey(), isFalse);

      await keyStore.initialize();
      expect(await keyStore.hasMasterKey(), isTrue);

      final masterKey = await keyStore.getMasterKey();
      expect(masterKey.length, equals(32));

      final devPubKey = await keyStore.getDevicePublicKey();
      final devSecKey = await keyStore.getDevicePrivateKey();
      expect(devPubKey.length, equals(32));
      expect(devSecKey.length, equals(32));

      // Collection key for album
      final aek1 = await keyStore.getOrCreateCollectionKey('album_japan_trip');
      expect(aek1.length, equals(32));

      // Same album returns same collection key
      final aek1Again = await keyStore.getOrCreateCollectionKey('album_japan_trip');
      expect(aek1Again, equals(aek1));

      // Different album gets distinct key
      final aek2 = await keyStore.getOrCreateCollectionKey('album_cafe_walks');
      expect(aek2, isNot(equals(aek1)));

      // Durable persistence across KeyStore instances
      final secondKeyStore = KeyStore(storage: inMemoryStorage);
      final restoredMasterKey = await secondKeyStore.getMasterKey();
      expect(restoredMasterKey, equals(masterKey));
    });
  });
}
