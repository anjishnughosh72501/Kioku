import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodium_libs/src/platforms/sodium_windows.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/encrypted_envelope.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/crypto/migration_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SodiumWindows.registerWith();
  PathProviderWindows.registerWith();

  setUpAll(() async {
    await CryptoCore.instance.init();
    SharedPreferences.setMockInitialValues({});
  });

  test('MigrationService converts plaintext photo into encrypted .enc envelope', () async {
    final keyStore = KeyStore(storage: InMemorySecureStorage());
    keyStore.hasExistingDataOverride = () => false;
    await keyStore.initialize();

    final localStorage = LocalStorageService.instance;
    final album = await localStorage.createAlbum('Pre-encryption Album');

    // Create plaintext file
    final tempDir = Directory.systemTemp.createTempSync('kioku_migration_');
    final plainPhoto = File('${tempDir.path}/raw_unencrypted.jpg');
    final rawBytes = Uint8List.fromList('Original Unencrypted Birthday Photo'.codeUnits);
    plainPhoto.writeAsBytesSync(rawBytes);

    // Save as legacy memory
    final legacyMem = await localStorage.saveMemory(
      albumId: album.id,
      file: plainPhoto,
      mimeType: 'image/jpeg',
      caption: 'Happy 25th Birthday!',
    );

    expect(File(legacyMem.localPath!).existsSync(), isTrue);
    expect(legacyMem.localPath!.endsWith('.enc'), isFalse);

    // Run migration
    final migrationService = MigrationService(
      keyStore: keyStore,
      localStorageService: localStorage,
    );

    final events = await migrationService.migrate().toList();
    expect(events.isNotEmpty, isTrue);
    expect(events.last.progress, equals(1.0));

    // Plaintext original file should be deleted
    expect(File(legacyMem.localPath!).existsSync(), isFalse);

    // Encrypted .enc file should exist in album directory
    final albumDir = await localStorage.getAlbumDirectory(album.id);
    final encFile = File('${albumDir.path}/${legacyMem.id}.enc');
    expect(encFile.existsSync(), isTrue);

    // Verify it is a valid EncryptedEnvelope
    final blob = await encFile.readAsBytes();
    final envelope = EncryptedEnvelope.fromBlob(blob, objectId: legacyMem.id);

    // Decrypt and verify contents
    final collectionKey = await keyStore.getOrCreateCollectionKey(album.id);
    final fileKey = CryptoCore.instance.unwrapKey(
      envelope.wrappedFileKey,
      envelope.fileKeyNonce,
      collectionKey,
    );

    final decMeta = CryptoCore.instance.decryptMetadata(
      envelope.encryptedMetadata,
      envelope.metadataNonce,
      fileKey,
    );
    expect(decMeta['caption'], equals('Happy 25th Birthday!'));

    final decStream = CryptoCore.instance.decryptStream(
      Stream.fromIterable(envelope.cipherChunks),
      fileKey,
    );
    final chunks = await decStream.toList();
    final plainDecrypted = Uint8List.fromList(chunks.expand((c) => c).toList());
    expect(String.fromCharCodes(plainDecrypted), equals('Original Unencrypted Birthday Photo'));

    // Clean up
    await localStorage.deleteAlbum(album.id);
    tempDir.deleteSync(recursive: true);
  });
}
