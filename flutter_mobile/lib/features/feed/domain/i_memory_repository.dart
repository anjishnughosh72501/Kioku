import 'dart:typed_data';
import 'package:flutter_mobile/core/models/memory.dart';

abstract interface class IMemoryRepository {
  Future<List<Album>> getAlbums();
  Future<Album> createAlbum(String name);
  Future<void> shareAlbum(String albumId, String email, {String role});
  Future<List<AlbumMember>> getAlbumMembers(String albumId);
  Future<List<KiokuMemory>> getMemories(String albumId);
  Future<({List<KiokuMemory> items, String? nextPageToken})> getMemoriesPage(
    String albumId, {
    int pageSize = 20,
    String? pageToken,
  });
  Future<Uint8List?> getThumbnailBytes(String memoryId, {required String albumId});
  Future<void> deleteMemory(String fileId, {String? albumId});
}
