import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/recovery_service.dart';
import 'package:flutter_mobile/core/services/app_lock_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  group('P2-9: E2EE Crypto Round-Trip & Key Rotation Verification', () {
    test('Envelope crypto round-trip encrypts and decrypts stream byte-for-byte', () async {
      final crypto = CryptoCore.instance;
      final fileKey = crypto.generateRandomKey();

      // Create a 128KB pseudo-random payload (multiple chunks)
      final originalData = Uint8List(128 * 1024);
      for (int i = 0; i < originalData.length; i++) {
        originalData[i] = (i * 31 + 7) % 256;
      }

      // Chunk inputStream in 16KB blocks
      final chunkList = <Uint8List>[];
      const chunkSize = 16 * 1024;
      for (int i = 0; i < originalData.length; i += chunkSize) {
        final end = (i + chunkSize < originalData.length) ? i + chunkSize : originalData.length;
        chunkList.add(originalData.sublist(i, end));
      }

      final inStream = Stream.fromIterable(chunkList);
      final cipherStream = crypto.encryptStream(inStream, fileKey);

      // Collect ciphertext chunks (simulating cloud storage upload/download)
      final cipherChunks = await cipherStream.toList();
      expect(cipherChunks.isNotEmpty, isTrue);

      // Decrypt stream
      final downloadStream = Stream.fromIterable(cipherChunks);
      final decryptedStream = crypto.decryptStream(downloadStream, fileKey);
      final decryptedChunks = await decryptedStream.toList();

      // Assemble decrypted bytes
      final totalLen = decryptedChunks.fold<int>(0, (sum, c) => sum + c.length);
      final assembled = Uint8List(totalLen);
      int offset = 0;
      for (final c in decryptedChunks) {
        assembled.setAll(offset, c);
        offset += c.length;
      }

      expect(assembled.length, equals(originalData.length));
      expect(assembled, equals(originalData));
    });

    test('Key rotation prevents old album keys from decrypting new content', () async {
      final crypto = CryptoCore.instance;
      final oldAlbumKey = crypto.generateRandomKey();
      final newAlbumKey = crypto.generateRandomKey(); // Rotated key

      final photoBytes = Uint8List.fromList(utf8.encode('Top-Secret Intimate Memory Photo'));
      final inStream = Stream.value(photoBytes);

      // Encrypted with new rotated album key
      final cipherStream = crypto.encryptStream(inStream, newAlbumKey);
      final cipherChunks = await cipherStream.toList();

      // Attempt decryption with revoked old album key
      final downloadStream = Stream.fromIterable(cipherChunks);
      final attemptDecrypt = crypto.decryptStream(downloadStream, oldAlbumKey);

      expect(
        () async => await attemptDecrypt.toList(),
        throwsA(isA<Exception>()),
        reason: 'Revoked old key must fail AEAD MAC verification against new ciphertext',
      );
    });

    test('Three-tier key wrapping and BIP-39 recovery round-trip', () {
      final crypto = CryptoCore.instance;
      final recovery = RecoveryService.instance;

      // Tier 1: Master Key
      final masterKey = crypto.generateRandomKey();
      // Tier 2: Album Key
      final albumKey = crypto.generateRandomKey();

      // Master wraps Album key
      final wrappedAlbumKey = crypto.wrapKey(albumKey, masterKey);
      final unwrappedAlbumKey = crypto.unwrapKey(
        wrappedAlbumKey.cipherText,
        wrappedAlbumKey.nonce,
        masterKey,
      );
      expect(unwrappedAlbumKey, equals(albumKey));

      // BIP-39 Recovery phrase generation and validation
      final phrase = recovery.generateRecoveryPhrase();
      expect(recovery.validatePhrase(phrase), isTrue);

      final recoveryKey = recovery.phraseToKey(phrase);
      final recoveryBlob = recovery.createRecoveryBlob(masterKey, recoveryKey);

      final recoveredMasterKey = recovery.recoverMasterKey(
        phrase: phrase,
        encryptedMasterKey: recoveryBlob.encryptedMasterKey,
        nonce: recoveryBlob.nonce,
      );

      expect(recoveredMasterKey, equals(masterKey));
    });
  });

  group('P1-8: AppLockService Verification', () {
    test('Setting PIN and verifying matches properly', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final lockService = AppLockService.instance;
      await lockService.init();

      expect(lockService.isEnabled, isFalse);
      await lockService.setPin('1234');
      expect(lockService.isEnabled, isTrue);

      // Invalid PIN
      final fail = await lockService.verifyPin('9999');
      expect(fail, isFalse);

      // Valid PIN
      final ok = await lockService.verifyPin('1234');
      expect(ok, isTrue);
      expect(lockService.isLocked, isFalse);

      // Reset with recovery phrase
      final phrase = RecoveryService.instance.generateRecoveryPhrase();
      final resetOk = await lockService.resetWithRecoveryPhrase(
        phrase: phrase,
        newPin: '5678',
      );
      expect(resetOk, isTrue);

      // Old PIN fails, new PIN succeeds
      expect(await lockService.verifyPin('1234'), isFalse);
      expect(await lockService.verifyPin('5678'), isTrue);

      // Disable lock
      final disabled = await lockService.disableLock('5678');
      expect(disabled, isTrue);
      expect(lockService.isEnabled, isFalse);
    });
  });
}
