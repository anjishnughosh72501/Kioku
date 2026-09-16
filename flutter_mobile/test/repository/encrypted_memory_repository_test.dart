import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/storage/storage_provider.dart';
import 'package:flutter_mobile/features/feed/data/encrypted_memory_repository.dart';

class MockStorageProvider implements StorageProvider {
  final Map<String, Map<String, Uint8List>> containers = {};

  @override
  StorageProviderType get type => StorageProviderType.local;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(displayName: 'Mock');

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    containers.putIfAbsent(containerId, () => {})[objectId] = ciphertext;
    return objectId;
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    final container = containers[containerId];
    if (container == null || !container.containsKey(objectId)) {
      throw StateError('Blob not found: $objectId in $containerId');
    }
    return container[objectId]!;
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {
    containers[containerId]?.remove(objectId);
  }

  @override
  Future<List<String>> listBlobs(String containerId) async {
    return containers[containerId]?.keys.toList() ?? [];
  }
}

class MockFailingStorageProvider implements StorageProvider {
  @override
  StorageProviderType get type => StorageProviderType.local;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(displayName: 'FailingMock');

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    throw const HttpException('Simulated storage write error');
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    throw const HttpException('Simulated storage read error');
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {}

  @override
  Future<List<String>> listBlobs(String containerId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  late MockStorageProvider mockProvider;
  late KeyStore keyStore;
  late EncryptedMemoryRepository repository;
  late InMemorySecureStorage memorySecureStorage;

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockProvider = MockStorageProvider();
    memorySecureStorage = InMemorySecureStorage();
    keyStore = KeyStore(storage: memorySecureStorage);
    await keyStore.initialize();
    repository = EncryptedMemoryRepository(
      provider: () => mockProvider,
      keyStore: keyStore,
    );
  });

  group('EncryptedMemoryRepository deleteMemory tests', () {
    test('deleteMemory with albumId deletes blob from storage and evicts caches', () async {
      final tempDir = Directory.systemTemp.createTempSync('kioku_delete_test_');
      final tempFile = File('${tempDir.path}/test_del.jpg');
      final sampleBytes = Uint8List.fromList('Memory to be deleted'.codeUnits);
      tempFile.writeAsBytesSync(sampleBytes);

      const albumId = 'album_alpha';
      final memory = await repository.uploadMemory(
        albumId: albumId,
        file: tempFile,
        mimeType: 'image/jpeg',
        caption: 'Will be deleted',
        takenAt: '2026-09-16T12:00:00Z',
      );

      expect(memory.id, isNotEmpty);
      final storedBlobsBefore = await mockProvider.listBlobs(albumId);
      expect(storedBlobsBefore, contains(memory.id));

      // Warm caches
      final photoBytes = await repository.getPhotoBytes(memory.id, albumId: albumId);
      expect(photoBytes, equals(sampleBytes));

      // Execute deleteMemory with albumId
      await repository.deleteMemory(memory.id, albumId: albumId);

      // Verify blob is permanently removed from storage provider
      final storedBlobsAfter = await mockProvider.listBlobs(albumId);
      expect(storedBlobsAfter, isEmpty);
      expect(storedBlobsAfter.contains(memory.id), isFalse);

      tempDir.deleteSync(recursive: true);
    });

    test('deleteMemory without albumId does not delete blob from storage provider', () async {
      final tempDir = Directory.systemTemp.createTempSync('kioku_delete_test2_');
      final tempFile = File('${tempDir.path}/test_del2.jpg');
      tempFile.writeAsBytesSync(Uint8List.fromList('Memory blob'.codeUnits));

      const albumId = 'album_beta';
      final memory = await repository.uploadMemory(
        albumId: albumId,
        file: tempFile,
        mimeType: 'image/jpeg',
        caption: 'Blob remains if no albumId',
        takenAt: '2026-09-16T12:00:00Z',
      );

      // Calling deleteMemory without albumId (the previous bug)
      await repository.deleteMemory(memory.id);

      // Blob still exists in storage!
      final storedBlobs = await mockProvider.listBlobs(albumId);
      expect(storedBlobs, contains(memory.id));

      tempDir.deleteSync(recursive: true);
    });
  });

  group('KeyStore vault loss protection tests', () {
    test('fresh install generates master key and backs up recovery blob', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = InMemorySecureStorage();
      final ks = KeyStore(storage: storage);

      final phrase = await ks.initialize();
      expect(phrase, isNotNull);
      expect(await ks.hasMasterKey(), isTrue);
      expect(ks.needsRecovery, isFalse);

      // Verify backup recovery blob was written to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('kioku_sec_recovery_blob_backup'), isTrue);
      expect(prefs.containsKey('kioku_sec_recovery_nonce_backup'), isTrue);
    });

    test('secure storage wiped while vault exists throws VaultRecoveryRequiredException', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = InMemorySecureStorage();
      final ks = KeyStore(storage: storage);
      await ks.initialize();

      // Simulate OS clearing secure storage (wiping master key and recovery blob from keystore)
      storage.clear();

      // Now create a new KeyStore instance representing app restart
      final newKs = KeyStore(storage: storage);
      expect(await newKs.hasMasterKey(), isFalse);

      // Because recovery blob backup exists in SharedPreferences, initialize should NOT overwrite!
      await expectLater(
        newKs.initialize(),
        throwsA(isA<VaultRecoveryRequiredException>()),
      );
      expect(newKs.needsRecovery, isTrue);

      // getMasterKey should also throw VaultRecoveryRequiredException
      await expectLater(
        newKs.getMasterKey(),
        throwsA(isA<VaultRecoveryRequiredException>()),
      );
    });

    test('restoreFromRecoveryPhrase restores masterKey using SharedPreferences backup', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = InMemorySecureStorage();
      final ks = KeyStore(storage: storage);
      final phrase = await ks.initialize();
      final originalMasterKey = await ks.getMasterKey();

      // Simulate secure storage wipe
      storage.clear();

      final restoredKs = KeyStore(storage: storage);
      expect(await restoredKs.hasMasterKey(), isFalse);

      // Restore using phrase
      await restoredKs.restoreFromRecoveryPhrase(phrase!);
      expect(await restoredKs.hasMasterKey(), isTrue);
      expect(restoredKs.needsRecovery, isFalse);

      final recoveredMasterKey = await restoredKs.getMasterKey();
      expect(recoveredMasterKey, equals(originalMasterKey));
    });

    test('restoreFromRecoveryPhrase throws on invalid phrase word count', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = InMemorySecureStorage();
      final ks = KeyStore(storage: storage);
      await ks.initialize();

      // Clear keystore to simulate wipe
      storage.clear();
      final newKs = KeyStore(storage: storage);

      // 5 words instead of 24
      await expectLater(
        newKs.restoreFromRecoveryPhrase('apple banana cherry dog elephant'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('restoreFromRecoveryPhrase handles extra whitespace gracefully', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = InMemorySecureStorage();
      final ks = KeyStore(storage: storage);
      final phrase = await ks.initialize();
      final originalMasterKey = await ks.getMasterKey();

      storage.clear();
      final restoredKs = KeyStore(storage: storage);

      // Phrase with leading/trailing and duplicate whitespace
      final messyPhrase = '  ${phrase!.replaceAll(' ', '   ')}  ';
      await restoredKs.restoreFromRecoveryPhrase(messyPhrase);
      expect(await restoredKs.hasMasterKey(), isTrue);

      final recoveredMasterKey = await restoredKs.getMasterKey();
      expect(recoveredMasterKey, equals(originalMasterKey));
    });
  });

  group('EncryptedMemoryRepository pagination and failure tests', () {
    test('getMemoriesPage returns page slices and tracks nextPageToken', () async {
      final tempDir = Directory.systemTemp.createTempSync('kioku_page_test_');
      const albumId = 'album_pagination';

      for (var i = 1; i <= 5; i++) {
        final f = File('${tempDir.path}/img_$i.jpg');
        f.writeAsBytesSync(Uint8List.fromList('Photo $i'.codeUnits));
        await repository.uploadMemory(
          albumId: albumId,
          file: f,
          mimeType: 'image/jpeg',
          caption: 'Item $i',
          takenAt: '2026-09-16T12:0$i:00Z',
        );
      }

      // First page of 2 items
      final page1 = await repository.getMemoriesPage(albumId, pageSize: 2);
      expect(page1.items.length, equals(2));
      expect(page1.nextPageToken, equals('2'));

      // Second page of 2 items
      final page2 = await repository.getMemoriesPage(albumId, pageSize: 2, pageToken: page1.nextPageToken);
      expect(page2.items.length, equals(2));
      expect(page2.nextPageToken, equals('4'));

      // Third page of 1 item
      final page3 = await repository.getMemoriesPage(albumId, pageSize: 2, pageToken: page2.nextPageToken);
      expect(page3.items.length, equals(1));
      expect(page3.nextPageToken, isNull);

      tempDir.deleteSync(recursive: true);
    });

    test('uploadMemory failure on storage write propagates exception cleanly', () async {
      final tempDir = Directory.systemTemp.createTempSync('kioku_upload_fail_');
      final f = File('${tempDir.path}/img_fail.jpg');
      f.writeAsBytesSync(Uint8List.fromList('Photo data'.codeUnits));

      final failingProvider = MockFailingStorageProvider();
      final failingRepo = EncryptedMemoryRepository(
        provider: () => failingProvider,
        keyStore: keyStore,
      );

      await expectLater(
        failingRepo.uploadMemory(
          albumId: 'album_err',
          file: f,
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<HttpException>()),
      );

      tempDir.deleteSync(recursive: true);
    });
  });
}
