import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import '../domain/i_memory_repository.dart';

class MemoryRepository implements IMemoryRepository {
  const MemoryRepository();

  @override
  Future<List<Album>> getAlbums() async {
    if (AppDrive.instance.isBound) {
      try {
        final driveAlbums = await AppDrive.instance.listAlbums();
        final localAlbums = await LocalStorageService.instance.getAlbums();
        // Return drive albums combined with any existing local albums (deduplicating by id)
        final seenIds = <String>{};
        final combined = <Album>[];
        for (final album in [...driveAlbums, ...localAlbums]) {
          if (seenIds.add(album.id)) {
            combined.add(album);
          }
        }
        if (combined.isNotEmpty) return combined;
      } catch (_) {
        // Fall back to local if Drive fails
      }
    }
    return LocalStorageService.instance.getAlbums();
  }

  @override
  Future<Album> createAlbum(String name) async {
    if (AppDrive.instance.isBound) {
      return AppDrive.instance.createAlbum(name);
    }
    return LocalStorageService.instance.createAlbum(name);
  }

  @override
  Future<void> shareAlbum(String albumId, String email, {String role = 'writer'}) async {
    if (AppDrive.instance.isBound) {
      return AppDrive.instance.shareAlbum(albumId, email, role: role);
    }
    throw UnsupportedError(
        'Please sign in to Google Drive from your Profile to share albums via cloud.');
  }

  @override
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async {
    if (AppDrive.instance.isBound && !albumId.startsWith('local_')) {
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
    if (AppDrive.instance.isBound && !albumId.startsWith('local_')) {
      return AppDrive.instance.listMemories(albumId);
    }
    return LocalStorageService.instance.getMemories(albumId);
  }

  @override
  Future<({List<KiokuMemory> items, String? nextPageToken})> getMemoriesPage(
    String albumId, {
    int pageSize = 30,
    String? pageToken,
  }) async {
    if (AppDrive.instance.isBound && !albumId.startsWith('local_')) {
      return AppDrive.instance.listMemoriesPage(
        albumId,
        pageSize: pageSize,
        pageToken: pageToken,
      );
    }
    final all = await LocalStorageService.instance.getMemories(albumId);
    final offset = pageToken != null ? int.tryParse(pageToken) ?? 0 : 0;
    final end = (offset + pageSize).clamp(0, all.length);
    final slice = offset < all.length ? all.sublist(offset, end) : <KiokuMemory>[];
    final next = end < all.length ? end.toString() : null;
    return (items: slice, nextPageToken: next);
  }

  @override
  Future<void> deleteMemory(String fileId) async {
    if (AppDrive.instance.isBound && !fileId.startsWith('local_mem_')) {
      return AppDrive.instance.deleteMemory(fileId);
    }
    return LocalStorageService.instance.deleteMemory(fileId);
  }
}
