import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_mobile/core/crypto/crypto_core.dart';
import 'package:flutter_mobile/core/crypto/encrypted_envelope.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/storage/storage_provider.dart';
import 'package:flutter_mobile/features/feed/domain/i_memory_repository.dart';
import 'package:flutter_mobile/features/upload/domain/i_upload_repository.dart';

class _DecryptedLRUCache {
  _DecryptedLRUCache({required this.maxBytes});
  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap<String, Uint8List>();
  int _used = 0;

  Uint8List? get(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _map[key] = v;
    }
    return v;
  }

  void put(String key, Uint8List bytes) {
    if (_map.containsKey(key)) {
      _used -= _map[key]!.length;
      _map.remove(key);
    }
    while (_used + bytes.length > maxBytes && _map.isNotEmpty) {
      final oldestKey = _map.keys.first;
      _used -= _map[oldestKey]!.length;
      _map.remove(oldestKey);
    }
    _map[key] = bytes;
    _used += bytes.length;
  }

  void remove(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _used -= v.length;
    }
  }

  void clear() {
    _map.clear();
    _used = 0;
  }
}

class EncryptedMemoryRepository implements IMemoryRepository, IUploadRepository {
  final StorageProvider Function() _providerGetter;
  final KeyStore _keyStore;

  EncryptedMemoryRepository({
    required StorageProvider Function() provider,
    KeyStore? keyStore,
  })  : _providerGetter = provider,
        _keyStore = keyStore ?? KeyStore.instance;

  StorageProvider get provider => _providerGetter();

  // In-memory decrypted cache (50MB for full media, 20MB for thumbnails)
  final _DecryptedLRUCache _mediaCache = _DecryptedLRUCache(maxBytes: 50 * 1024 * 1024);
  final _DecryptedLRUCache _thumbCache = _DecryptedLRUCache(maxBytes: 20 * 1024 * 1024);

  // Metadata cache per objectId to avoid re-decrypting envelope headers on every scroll
  final Map<String, KiokuMemory> _metadataCache = {};

  // ===== IMemoryRepository Implementation =====

  @override
  Future<List<Album>> getAlbums() async {
    if (provider.type == StorageProviderType.drive && AppDrive.instance.isBound) {
      try {
        final driveAlbums = await AppDrive.instance.listAlbums();
        final localAlbums = await LocalStorageService.instance.getAlbums();
        final seenIds = <String>{};
        final combined = <Album>[];
        for (final album in [...driveAlbums, ...localAlbums]) {
          if (seenIds.add(album.id)) {
            combined.add(album);
          }
        }
        if (combined.isNotEmpty) return combined;
      } catch (_) {
        // Fall back to local
      }
    }
    return LocalStorageService.instance.getAlbums();
  }

  @override
  Future<Album> createAlbum(String name) async {
    if (provider.type == StorageProviderType.drive && AppDrive.instance.isBound) {
      return AppDrive.instance.createAlbum(name);
    }
    return LocalStorageService.instance.createAlbum(name);
  }

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {
    if (provider.type == StorageProviderType.drive && AppDrive.instance.isBound) {
      return AppDrive.instance.shareAlbum(albumId, email, role: role);
    }
    throw UnsupportedError(
      'Sharing is supported when signed in to Google Drive or in peer mesh mode.',
    );
  }

  @override
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async {
    if (provider.type == StorageProviderType.drive &&
        AppDrive.instance.isBound &&
        !albumId.startsWith('local_')) {
      return AppDrive.instance.albumMembers(albumId);
    }
    return [
      const AlbumMember(
        email: 'local@device',
        role: 'owner',
        displayName: 'You (Device Storage)',
      ),
    ];
  }

  @override
  Future<List<KiokuMemory>> getMemories(String albumId) async {
    await CryptoCore.instance.init();
    final blobIds = await provider.listBlobs(albumId);
    final collectionKey = await _keyStore.getOrCreateCollectionKey(albumId);

    final memories = <KiokuMemory>[];
    for (final objectId in blobIds) {
      // Check metadata cache first
      final cached = _metadataCache[objectId];
      if (cached != null) {
        memories.add(cached);
        continue;
      }

      try {
        final blob = await provider.getBlob(objectId, containerId: albumId);
        final envelope = EncryptedEnvelope.fromBlob(blob, objectId: objectId);

        // Unwrap fileKey using collectionKey (AEK)
        final fileKey = CryptoCore.instance.unwrapKey(
          envelope.wrappedFileKey,
          envelope.fileKeyNonce,
          collectionKey,
        );

        // Decrypt metadata JSON
        final meta = CryptoCore.instance.decryptMetadata(
          envelope.encryptedMetadata,
          envelope.metadataNonce,
          fileKey,
        );

        // Cache decrypted thumbnail if available
        if (envelope.encryptedThumbnail != null && envelope.thumbnailNonce != null) {
          final thumbBytes = CryptoCore.instance.decryptBytes(
            envelope.encryptedThumbnail!,
            envelope.thumbnailNonce!,
            fileKey,
          );
          _thumbCache.put(objectId, thumbBytes);
        }

        final memory = KiokuMemory.fromDecryptedMetadata(
          id: objectId,
          metadata: meta,
        );
        _metadataCache[objectId] = memory;
        memories.add(memory);
      } catch (_) {
        // Skip unreadable or corrupted blobs
      }
    }

    memories.sort((a, b) => (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)));
    return memories;
  }

  @override
  Future<({List<KiokuMemory> items, String? nextPageToken})> getMemoriesPage(
    String albumId, {
    int pageSize = 30,
    String? pageToken,
  }) async {
    final all = await getMemories(albumId);
    final offset = pageToken != null ? int.tryParse(pageToken) ?? 0 : 0;
    final end = (offset + pageSize).clamp(0, all.length);
    final slice = offset < all.length ? all.sublist(offset, end) : <KiokuMemory>[];
    final next = end < all.length ? end.toString() : null;
    return (items: slice, nextPageToken: next);
  }

  @override
  Future<void> deleteMemory(String fileId, {String? albumId}) async {
    if (albumId != null) {
      await provider.deleteBlob(fileId, containerId: albumId);
    }
    _metadataCache.remove(fileId);
    _mediaCache.remove(fileId);
    _thumbCache.remove(fileId);
  }

  // ===== IUploadRepository Implementation =====

  @override
  Future<KiokuMemory> uploadMemory({
    required String albumId,
    required File file,
    required String mimeType,
    String? caption,
    String? takenAt,
  }) async {
    await CryptoCore.instance.init();

    // 1. Read file bytes and compress if image
    Uint8List mediaBytes = await file.readAsBytes();
    Uint8List? thumbBytes;

    if (mimeType.startsWith('image/')) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          mediaBytes,
          minHeight: 1920,
          minWidth: 1080,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          mediaBytes = compressed;
        }

        // Generate thumbnail
        final thumb = await FlutterImageCompress.compressWithList(
          mediaBytes,
          minHeight: 400,
          minWidth: 400,
          quality: 75,
          format: CompressFormat.jpeg,
        );
        if (thumb.isNotEmpty) {
          thumbBytes = thumb;
        }
      } catch (_) {
        // Fallback: use raw bytes if compression fails
      }
    }

    // 2. Fresh random fileKey (DEK)
    final fileKey = CryptoCore.instance.generateRandomKey();

    // 3. Encrypt media stream with fileKey (SecretStream chunked XChaCha20-Poly1305)
    final encryptedStream = CryptoCore.instance.encryptStream(
      Stream.value(mediaBytes),
      fileKey,
    );
    final encryptedChunks = await encryptedStream.toList();

    // 4. Encrypt thumbnail if present
    WrappedKey? encThumb;
    if (thumbBytes != null) {
      encThumb = CryptoCore.instance.encryptBytes(thumbBytes, fileKey);
    }

    // 5. Encrypt metadata JSON
    final customUsername = UserProfileService.instance.username;
    final nowIso = DateTime.now().toIso8601String();
    final metadataMap = {
      'file_name': file.uri.pathSegments.last,
      'mime_type': mimeType,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      'taken_at': takenAt ?? nowIso,
      'uploader_name': customUsername,
      'added_at': nowIso,
      'size_bytes': mediaBytes.length,
    };
    final encMeta = CryptoCore.instance.encryptMetadata(metadataMap, fileKey);

    // 6. Wrap fileKey with album's collectionKey (AEK)
    final collectionKey = await _keyStore.getOrCreateCollectionKey(albumId);
    final wrappedFileKey = CryptoCore.instance.wrapKey(fileKey, collectionKey);

    // 7. Assemble EncryptedEnvelope and serialize to opaque binary blob
    final randomSuffix = fileKey.sublist(0, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final objectId = 'mem_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';
    final envelope = EncryptedEnvelope(
      objectId: objectId,
      wrappedFileKey: wrappedFileKey.cipherText,
      fileKeyNonce: wrappedFileKey.nonce,
      encryptedMetadata: encMeta.cipherText,
      metadataNonce: encMeta.nonce,
      encryptedThumbnail: encThumb?.cipherText,
      thumbnailNonce: encThumb?.nonce,
      cipherChunks: encryptedChunks,
    );

    final blobBytes = envelope.toBlob();

    // 8. Store blob in the active StorageProvider
    final storedId = await provider.putBlob(
      blobBytes,
      containerId: albumId,
      objectId: objectId,
    );

    // 9. Cache in-memory
    _mediaCache.put(storedId, mediaBytes);
    if (thumbBytes != null) {
      _thumbCache.put(storedId, thumbBytes);
    }

    final memory = KiokuMemory.fromDecryptedMetadata(
      id: storedId,
      metadata: metadataMap,
    );
    _metadataCache[storedId] = memory;
    return memory;
  }

  // ===== Decrypted Bytes Retrieval (LRU in-memory cached) =====

  Future<Uint8List> getPhotoBytes(String memoryId, {required String albumId}) async {
    final cached = _mediaCache.get(memoryId);
    if (cached != null) return cached;

    await CryptoCore.instance.init();
    final blob = await provider.getBlob(memoryId, containerId: albumId);
    final envelope = EncryptedEnvelope.fromBlob(blob, objectId: memoryId);

    final collectionKey = await _keyStore.getOrCreateCollectionKey(albumId);
    final fileKey = CryptoCore.instance.unwrapKey(
      envelope.wrappedFileKey,
      envelope.fileKeyNonce,
      collectionKey,
    );

    final decStream = CryptoCore.instance.decryptStream(
      Stream.fromIterable(envelope.cipherChunks),
      fileKey,
    );
    final chunks = await decStream.toList();
    final totalLen = chunks.fold(0, (acc, c) => acc + c.length);
    final plainBytes = Uint8List(totalLen);
    int offset = 0;
    for (final c in chunks) {
      plainBytes.setRange(offset, offset + c.length, c);
      offset += c.length;
    }

    _mediaCache.put(memoryId, plainBytes);
    return plainBytes;
  }

  Future<Uint8List?> getThumbnailBytes(String memoryId, {required String albumId}) async {
    final cached = _thumbCache.get(memoryId);
    if (cached != null) return cached;

    try {
      final plain = await getPhotoBytes(memoryId, albumId: albumId);
      return plain;
    } catch (_) {
      return null;
    }
  }

  void evictMemory(String memoryId) {
    _mediaCache.remove(memoryId);
    _thumbCache.remove(memoryId);
    _metadataCache.remove(memoryId);
  }
}
