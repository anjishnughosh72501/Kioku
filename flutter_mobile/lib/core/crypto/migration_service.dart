import 'dart:async';
import 'dart:io';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/encrypted_envelope.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/utils/secure_delete.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationProgress {
  final String status;
  final int processedFiles;
  final int totalFiles;
  final double progress; // 0.0 to 1.0

  const MigrationProgress({
    required this.status,
    required this.processedFiles,
    required this.totalFiles,
    required this.progress,
  });
}

class MigrationService {
  MigrationService({
    KeyStore? keyStore,
    LocalStorageService? localStorageService,
  })  : _keyStore = keyStore ?? KeyStore.instance,
        _localStorage = localStorageService ?? LocalStorageService.instance;

  static final MigrationService instance = MigrationService();

  final KeyStore _keyStore;
  final LocalStorageService _localStorage;

  static const _kMigrationKey = 'kioku_e2ee_migration_v1_complete';

  Future<bool> isMigrationNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kMigrationKey) == true) {
      return false;
    }
    // Check if any legacy local memories exist
    final albums = await _localStorage.getAlbums();
    for (final album in albums) {
      final mems = await _localStorage.getMemories(album.id);
      if (mems.any((m) => m.localPath != null && !m.localPath!.endsWith('.enc'))) {
        return true;
      }
    }
    return false;
  }

  /// Runs the migration process, emitting progress updates
  Stream<MigrationProgress> migrate() async* {
    await CryptoCore.instance.init();
    await _keyStore.initialize();

    final albums = await _localStorage.getAlbums();
    int totalCount = 0;
    final List<({String albumId, File file, String id, String? caption, String? takenAt, String mimeType})>
        itemsToMigrate = [];

    for (final album in albums) {
      final mems = await _localStorage.getMemories(album.id);
      for (final m in mems) {
        if (m.localPath != null && !m.localPath!.endsWith('.enc')) {
          final f = File(m.localPath!);
          if (f.existsSync()) {
            itemsToMigrate.add((
              albumId: album.id,
              file: f,
              id: m.id,
              caption: m.caption,
              takenAt: m.takenAtIso,
              mimeType: m.mimeType,
            ));
            totalCount++;
          }
        }
      }
    }

    if (totalCount == 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMigrationKey, true);
      yield const MigrationProgress(
        status: 'Everything is already encrypted',
        processedFiles: 0,
        totalFiles: 0,
        progress: 1.0,
      );
      return;
    }

    yield MigrationProgress(
      status: 'Starting encryption of existing memories...',
      processedFiles: 0,
      totalFiles: totalCount,
      progress: 0.0,
    );

    int processed = 0;
    for (final item in itemsToMigrate) {
      yield MigrationProgress(
        status: 'Encrypting ${item.file.uri.pathSegments.last}...',
        processedFiles: processed,
        totalFiles: totalCount,
        progress: processed / totalCount,
      );

      try {
        final mediaBytes = await item.file.readAsBytes();
        final fileKey = CryptoCore.instance.generateRandomKey();

        // 1. Encrypt media stream
        final encryptedStream = CryptoCore.instance.encryptStream(
          Stream.value(mediaBytes),
          fileKey,
        );
        final encryptedChunks = await encryptedStream.toList();

        // 2. Encrypt metadata
        final metadataMap = {
          'file_name': item.file.uri.pathSegments.last,
          'mime_type': item.mimeType,
          if (item.caption != null) 'caption': item.caption,
          'taken_at': item.takenAt ?? DateTime.now().toIso8601String(),
          'uploader_name': 'You',
          'added_at': DateTime.now().toIso8601String(),
          'size_bytes': mediaBytes.length,
        };
        final encMeta = CryptoCore.instance.encryptMetadata(metadataMap, fileKey);

        // 3. Wrap fileKey with album's collectionKey
        final collectionKey = await _keyStore.getOrCreateCollectionKey(item.albumId);
        final wrappedFileKey = CryptoCore.instance.wrapKey(fileKey, collectionKey);

        // 4. Create EncryptedEnvelope
        final envelope = EncryptedEnvelope(
          objectId: item.id,
          wrappedFileKey: wrappedFileKey.cipherText,
          fileKeyNonce: wrappedFileKey.nonce,
          encryptedMetadata: encMeta.cipherText,
          metadataNonce: encMeta.nonce,
          cipherChunks: encryptedChunks,
        );

        final blobBytes = envelope.toBlob();

        // 5. Write encrypted blob to album directory
        final albumDir = await _localStorage.getAlbumDirectory(item.albumId);
        final encFile = File('${albumDir.path}/${item.id}.enc');
        await encFile.writeAsBytes(blobBytes, flush: true);

        // 6. Safely delete old plaintext file with overwrite before unlink
        if (item.file.path != encFile.path && item.file.existsSync()) {
          await SecureDelete.secureDeleteFile(item.file);
        }
      } catch (e) {
        // Skip on individual file error so migration doesn't stall completely
      }

      processed++;
      yield MigrationProgress(
        status: 'Encrypted $processed of $totalCount',
        processedFiles: processed,
        totalFiles: totalCount,
        progress: processed / totalCount,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMigrationKey, true);

    yield MigrationProgress(
      status: 'Migration completed successfully!',
      processedFiles: totalCount,
      totalFiles: totalCount,
      progress: 1.0,
    );
  }
}
