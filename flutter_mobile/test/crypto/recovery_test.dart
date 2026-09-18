import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/crypto/recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 1 — Vault Recovery System Tests', () {
    test('RecoveryService generates valid 24-word BIP39 mnemonic and validates checksum', () {
      final phrase = RecoveryService.instance.generateRecoveryPhrase();
      final words = phrase.split(' ');
      expect(words.length, equals(24));
      expect(RecoveryService.instance.validatePhrase(phrase), isTrue);

      // Incomplete phrase rejected
      final incomplete = words.sublist(0, 23).join(' ');
      expect(RecoveryService.instance.validatePhrase(incomplete), isFalse);

      // Corrupted word checksum rejected
      final corrupted = '${words.sublist(0, 23).join(' ')} abandon';
      expect(RecoveryService.instance.validatePhrase(corrupted), isFalse);
    });

    test('KeyStore initialize generates recovery phrase and stores it encrypted', () async {
      final storage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: storage);

      final initResult = await keyStore.initialize();
      expect(initResult, isNull);

      final phrase = await keyStore.getRecoveryPhrase();
      expect(phrase.split(' ').length, equals(24));

      expect(await keyStore.hasMasterKey(), isTrue);
      expect(keyStore.needsRecovery, isFalse);
    });

    test('KeyStore throws VaultRecoveryRequiredException when data exists without master key', () async {
      final storage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: storage);

      // Simulate existing encrypted data
      keyStore.hasExistingDataOverride = () => true;

      expect(await keyStore.checkNeedsRecovery(), isTrue);
      expect(keyStore.needsRecovery, isTrue);

      // getMasterKey must throw rather than silently generating fresh keys
      expect(
        () async => await keyStore.getMasterKey(),
        throwsA(isA<VaultRecoveryRequiredException>()),
      );

      // initialize without phrase must throw rather than overwriting
      expect(
        () async => await keyStore.initialize(),
        throwsA(isA<VaultRecoveryRequiredException>()),
      );

      // Master key was NOT generated
      expect(await keyStore.hasMasterKey(), isFalse);
    });

    test('Wrong recovery phrase throws VaultDecryptionException and preserves vault', () async {
      final storage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: storage);

      // Initialize initial vault
      await keyStore.initialize();
      final albumKey = await keyStore.getOrCreateCollectionKey('album_private');
      expect(albumKey.length, equals(32));

      // Simulate app reinstall / storage wipe of master key only
      await storage.delete(key: 'kioku_sec_master_key');
      keyStore.clearMemoryCache();

      // Ensure recovery is needed because collection key exists
      expect(await keyStore.checkNeedsRecovery(), isTrue);

      // Generate a different valid 24-word phrase (wrong phrase for this vault)
      final wrongPhrase = RecoveryService.instance.generateRecoveryPhrase();

      // Attempting restore with wrong phrase must throw VaultDecryptionException
      expect(
        () async => await keyStore.restoreFromRecoveryPhrase(wrongPhrase),
        throwsA(isA<VaultDecryptionException>()),
      );

      // Master key remains unrestored
      expect(await keyStore.hasMasterKey(), isFalse);
    });

    test('Full Integration Recovery Flow: wipe master key -> restore phrase -> decrypt albums', () async {
      final storage = InMemorySecureStorage();
      final initialKeyStore = KeyStore(storage: storage);

      // 1. Initial vault setup
      await initialKeyStore.initialize();
      final originalPhrase = await initialKeyStore.getRecoveryPhrase();
      expect(originalPhrase.isNotEmpty, isTrue);

      final albumId = 'album_family_trip';
      final initialAlbumKey = await initialKeyStore.getOrCreateCollectionKey(albumId);

      // Encrypt some album metadata with this collection key
      final metadata = {'title': 'Kyoto Trip', 'count': 42};
      final encryptedMeta = CryptoCore.instance.encryptMetadata(metadata, initialAlbumKey);

      // 2. Wipe master key from secure storage (simulating device migration or secure storage reset)
      await storage.delete(key: 'kioku_sec_master_key');
      initialKeyStore.clearMemoryCache();

      // Set SharedPreferences local album
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'kioku_local_albums',
        jsonEncode([{'id': albumId, 'name': 'Kyoto Trip'}]),
      );

      // 3. Launch fresh KeyStore instance
      final freshKeyStore = KeyStore(storage: storage);
      expect(await freshKeyStore.hasMasterKey(), isFalse);
      expect(await freshKeyStore.checkNeedsRecovery(), isTrue);

      // Invariant: attempting to access master key fails closed
      expect(
        () async => await freshKeyStore.getMasterKey(),
        throwsA(isA<VaultRecoveryRequiredException>()),
      );

      // 4. User provides original 24-word phrase to recover
      await freshKeyStore.restoreFromRecoveryPhrase(originalPhrase);

      // Invariant: recovery successful
      expect(freshKeyStore.needsRecovery, isFalse);
      expect(await freshKeyStore.hasMasterKey(), isTrue);

      // 5. Verify restored collection key decrypts album metadata perfectly
      final restoredAlbumKey = await freshKeyStore.getOrCreateCollectionKey(albumId);
      expect(restoredAlbumKey, equals(initialAlbumKey));

      final decrypted = CryptoCore.instance.decryptMetadata(
        encryptedMeta.cipherText,
        encryptedMeta.nonce,
        restoredAlbumKey,
      );
      expect(decrypted['title'], equals('Kyoto Trip'));
      expect(decrypted['count'], equals(42));
    });
  });
}
