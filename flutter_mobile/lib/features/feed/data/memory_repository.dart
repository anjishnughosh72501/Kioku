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
        if (driveAlbums.isNotEmpty) return driveAlbums;
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
  Future<void> deleteMemory(String fileId) async {
    if (AppDrive.instance.isBound && !fileId.startsWith('local_mem_')) {
      return AppDrive.instance.deleteMemory(fileId);
    }
    return LocalStorageService.instance.deleteMemory(fileId);
  }
}
