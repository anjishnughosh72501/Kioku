import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  group('Revocation & Key Rotation Invariants', () {
    test('Revoked member with old collection key CANNOT decrypt new uploads after rotation', () async {
      final storage = InMemorySecureStorage();
      final keyStore = KeyStore(storage: storage);
      await keyStore.initialize();

      const albumId = 'summer_trip_2026';

      // 1. Initial collection key (Epoch 1)
      final epoch1Key = await keyStore.getOrCreateCollectionKey(albumId);

      // Simulate a member (Bob) receiving Epoch 1 key
      final bobHeldKey = Uint8List.fromList(epoch1Key);

      // 2. Upload 1 created under Epoch 1
      final fileKey1 = CryptoCore.instance.generateRandomKey();
      final wrappedKey1 = CryptoCore.instance.wrapKey(fileKey1, epoch1Key);
      final meta1 = CryptoCore.instance.encryptMetadata({'title': 'Photo 1'}, fileKey1);

      // Bob can decrypt Upload 1
      final bobUnwrapped1 = CryptoCore.instance.unwrapKey(
        wrappedKey1.cipherText,
        wrappedKey1.nonce,
        bobHeldKey,
      );
      expect(bobUnwrapped1, equals(fileKey1));
      final bobMeta1 = CryptoCore.instance.decryptMetadata(
        meta1.cipherText,
        meta1.nonce,
        bobUnwrapped1,
      );
      expect(bobMeta1['title'], equals('Photo 1'));

      // 3. Member Removal: Bob is removed -> collection key rotated (Epoch 2)
      final epoch2Key = await keyStore.rotateCollectionKey(albumId);
      expect(epoch2Key, isNot(equals(epoch1Key)));

      // 4. Upload 2 created under Epoch 2 (after Bob was removed)
      final fileKey2 = CryptoCore.instance.generateRandomKey();
      final wrappedKey2 = CryptoCore.instance.wrapKey(fileKey2, epoch2Key);
      final meta2 = CryptoCore.instance.encryptMetadata({'title': 'Secret Photo 2'}, fileKey2);

      // Invariant: Bob with his old Epoch 1 key CANNOT unwrap or decrypt Upload 2
      expect(
        () => CryptoCore.instance.unwrapKey(
          wrappedKey2.cipherText,
          wrappedKey2.nonce,
          bobHeldKey,
        ),
        throwsA(isA<Exception>()),
      );

      // Current active members with Epoch 2 key can decrypt Upload 2
      final activeUnwrapped2 = CryptoCore.instance.unwrapKey(
        wrappedKey2.cipherText,
        wrappedKey2.nonce,
        epoch2Key,
      );
      expect(activeUnwrapped2, equals(fileKey2));
      final activeMeta2 = CryptoCore.instance.decryptMetadata(
        meta2.cipherText,
        meta2.nonce,
        activeUnwrapped2,
      );
      expect(activeMeta2['title'], equals('Secret Photo 2'));
    });
  });
}
