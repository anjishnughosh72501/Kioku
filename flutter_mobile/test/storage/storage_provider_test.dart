import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
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
      throw StateError('Blob not found: $objectId');
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();

  late MockStorageProvider mockProvider;
  late KeyStore keyStore;
  late EncryptedMemoryRepository repository;

  setUpAll(() async {
    await CryptoCore.instance.init();
  });

  setUp(() async {
    mockProvider = MockStorageProvider();
    keyStore = KeyStore(storage: InMemorySecureStorage());
    await keyStore.initialize();
    repository = EncryptedMemoryRepository(
      provider: () => mockProvider,
      keyStore: keyStore,
    );
  });

  test('EncryptedMemoryRepository uploads encrypted opaque blob', () async {
    final tempDir = Directory.systemTemp.createTempSync('kioku_test_');
    final tempFile = File('${tempDir.path}/test_photo.jpg');
    final sampleBytes = Uint8List.fromList('Original High Resolution Photo Bytes 12345'.codeUnits);
    tempFile.writeAsBytesSync(sampleBytes);

    const albumId = 'test_album_1';
    final memory = await repository.uploadMemory(
      albumId: albumId,
      file: tempFile,
      mimeType: 'image/jpeg',
      caption: 'Secret Sunset in Tokyo',
      takenAt: '2026-09-15T12:00:00Z',
    );

    expect(memory.id, isNotEmpty);
    expect(memory.caption, equals('Secret Sunset in Tokyo'));

    // Verify what is stored in the storage provider
    final storedBlobs = await mockProvider.listBlobs(albumId);
    expect(storedBlobs.length, equals(1));
    expect(storedBlobs.first, equals(memory.id));

    final rawBlob = await mockProvider.getBlob(memory.id, containerId: albumId);

    // Verify blob starts with 'KIO1' magic header
    expect(rawBlob[0], equals(0x4B)); // 'K'
    expect(rawBlob[1], equals(0x49)); // 'I'
    expect(rawBlob[2], equals(0x4F)); // 'O'
    expect(rawBlob[3], equals(0x31)); // '1'

    // Verify raw blob does NOT contain plaintext caption or media bytes!
    final rawString = String.fromCharCodes(rawBlob);
    expect(rawString.contains('Secret Sunset in Tokyo'), isFalse);
    expect(rawString.contains('Original High Resolution Photo Bytes'), isFalse);

    // Now test retrieval and decryption via repository
    final memories = await repository.getMemories(albumId);
    expect(memories.length, equals(1));
    expect(memories.first.id, equals(memory.id));
    expect(memories.first.caption, equals('Secret Sunset in Tokyo'));

    // Decrypt full photo bytes
    final decryptedBytes = await repository.getPhotoBytes(memory.id, albumId: albumId);
    expect(decryptedBytes, equals(sampleBytes));

    // Delete memory
    await repository.deleteMemory(memory.id, albumId: albumId);
    final remainingBlobs = await mockProvider.listBlobs(albumId);
    expect(remainingBlobs.isEmpty, isTrue);

    tempDir.deleteSync(recursive: true);
  });
}
