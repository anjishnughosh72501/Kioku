// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/models/memory.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _kAlbumsKey = 'kioku_local_albums';
  static const String _kMemoriesPrefix = 'kioku_local_memories_';

  Directory? _baseDir;

  Future<Directory> get baseDirectory async {
    if (_baseDir != null) return _baseDir!;
    final appDocs = await getApplicationDocumentsDirectory();
    final dir = Directory(appDocs.path + '/Kioku/Albums');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _baseDir = dir;
    return dir;
  }

  /// Get or create physical folder for an album.
  Future<Directory> getAlbumDirectory(String albumId) async {
    final base = await baseDirectory;
    final albumDir = Directory(base.path + '/' + albumId);
    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }
    return albumDir;
  }

  /// Check if memory id is local
  bool isLocalMemory(String mediaId) {
    return mediaId.startsWith('local_');
  }

  /// Raw list of stored albums without side-effects or recursion.
  Future<List<Album>> _loadRawAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlbumsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final albums = <Album>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? '';
          final name = item['name']?.toString() ?? '';
          final thumb = item['thumbnailPath']?.toString();
          if (id.isNotEmpty && name.isNotEmpty) {
            albums.add(Album(id: id, name: name, thumbnailPath: thumb));
          }
        }
      }
      return albums;
    } catch (_) {
      return [];
    }
  }

  /// Updates the stored thumbnail path for an album in the metadata index.
  Future<void> updateAlbumThumbnail(String albumId, String? thumbnailPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlbumsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final updated = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? '';
          if (id == albumId) {
            final map = Map<String, dynamic>.from(item);
            if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
              map['thumbnailPath'] = thumbnailPath;
            } else {
              map.remove('thumbnailPath');
            }
            updated.add(map);
          } else {
            updated.add(item);
          }
        }
      }
      await prefs.setString(_kAlbumsKey, jsonEncode(updated));
    } catch (_) {}
  }

  /// Lists all local albums stored on device.
  Future<List<Album>> getAlbums() async {
    final albums = await _loadRawAlbums();

    // If no local albums exist yet, create a cozy default one on disk.
    if (albums.isEmpty) {
      final defaultAlbum = await createAlbum('My Memories');
      return [defaultAlbum];
    }

    for (final album in albums) {
      await getAlbumDirectory(album.id);
    }
    return albums;
  }

  /// Creates a real local folder on disk and saves album metadata.
  Future<Album> createAlbum(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await _loadRawAlbums();

    final albumId = 'local_' + DateTime.now().millisecondsSinceEpoch.toString();
    final newAlbum = Album(id: albumId, name: name.trim());

    // Create real folder on disk
    await getAlbumDirectory(albumId);

    final updated = [
      ...albums.map((a) => {'id': a.id, 'name': a.name}),
      {'id': newAlbum.id, 'name': newAlbum.name},
    ];

    await prefs.setString(_kAlbumsKey, jsonEncode(updated));
    return newAlbum;
  }

  /// Ensures an album exists by id and name (used when joining via invite link).
  Future<Album> ensureAlbum({
    required String id,
    required String name,
    String storageType = 'local',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await _loadRawAlbums();

    final existing = albums.where((a) => a.id == id).firstOrNull;
    if (existing != null) {
      return existing;
    }

    final newAlbum = Album(
      id: id,
      name: name.trim().isEmpty ? 'Shared Album' : name.trim(),
      storageType: storageType,
    );

    // Create folder on disk
    await getAlbumDirectory(id);

    final updated = [
      ...albums.map((a) => {'id': a.id, 'name': a.name}),
      {'id': newAlbum.id, 'name': newAlbum.name},
    ];

    await prefs.setString(_kAlbumsKey, jsonEncode(updated));
    await prefs.setString('album_storage_$id', storageType);
    return newAlbum;
  }

  /// Get stored members for an album (owners, joined friends)
  Future<List<AlbumMember>> getAlbumMembers(String albumId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('album_members_$albumId');
    if (raw == null || raw.isEmpty) {
      return [
        const AlbumMember(
          email: 'local@device',
          role: 'owner',
          displayName: 'You (Owner)',
        ),
      ];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return AlbumMember(
          email: map['email'] as String? ?? 'member',
          role: map['role'] as String? ?? 'member',
          displayName: map['displayName'] as String?,
        );
      }).toList();
    } catch (_) {
      return [
        const AlbumMember(
          email: 'local@device',
          role: 'owner',
          displayName: 'You (Owner)',
        ),
      ];
    }
  }

  /// Add a member to an album
  Future<void> addAlbumMember(
    String albumId,
    String friendCode, {
    String? displayName,
    String role = 'member',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final members = await getAlbumMembers(albumId);
    if (members.any((m) => m.email == friendCode || m.displayName == displayName)) {
      return;
    }

    final updated = [
      ...members,
      AlbumMember(
        email: friendCode,
        role: role,
        displayName: displayName ?? friendCode,
      ),
    ];

    await prefs.setString(
      'album_members_$albumId',
      jsonEncode(updated
          .map((m) => {
                'email': m.email,
                'role': m.role,
                'displayName': m.displayName,
              })
          .toList()),
    );
  }

  /// Deletes a local album and removes all its photos from disk.
  Future<void> deleteAlbum(String albumId) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await _loadRawAlbums();

    final filtered = albums.where((a) => a.id != albumId).toList();
    await prefs.setString(
      _kAlbumsKey,
      jsonEncode(filtered.map((a) => {'id': a.id, 'name': a.name}).toList()),
    );

    // Delete folder from disk
    final albumDir = await getAlbumDirectory(albumId);
    if (await albumDir.exists()) {
      await albumDir.delete(recursive: true);
    }

    // Clean up memories index
    await prefs.remove(_kMemoriesPrefix + albumId);
  }

  /// Saves a memory file to the local album directory and indexes it.
  Future<KiokuMemory> saveMemory({
    required String albumId,
    required File file,
    required String mimeType,
    String? caption,
    String? takenAt,
    String? uploaderName,
  }) async {
    final memories = await getMemories(albumId);
    final albumDir = await getAlbumDirectory(albumId);
    final id = 'local_mem_' + DateTime.now().millisecondsSinceEpoch.toString();

    final extension = file.path.contains('.') ? file.path.split('.').last : 'jpg';
    final destFile = File(albumDir.path + '/' + id + '.' + extension);

    // Copy file to permanent local album folder
    await file.copy(destFile.path);
    final size = await destFile.length();

    final now = DateTime.now();
    final memory = KiokuMemory(
      id: id,
      fileName: id + '.' + extension,
      mimeType: mimeType,
      caption: caption,
      takenAtIso: takenAt ?? now.toIso8601String(),
      uploaderName: uploaderName ?? 'You',
      addedAt: now,
      sizeBytes: size,
      localPath: destFile.path,
      albumId: albumId,
    );

    // Save to album index
    final updated = [...memories.where((m) => m.id != id), memory];
    await _saveMemoriesList(albumId, updated);

    return memory;
  }

  /// Lists memories for a given local album.
  Future<List<KiokuMemory>> getMemories(String albumId) async {
    final prefs = await SharedPreferences.getInstance();
    final albumDir = await getAlbumDirectory(albumId);
    final raw = prefs.getString(_kMemoriesPrefix + albumId);

    if (raw == null || raw.isEmpty) {
      // If index was wiped or absent, reconstruct from physical album directory on disk!
      if (!await albumDir.exists()) return [];
      try {
        final diskFiles = albumDir.listSync();
        final recovered = <KiokuMemory>[];
        for (final f in diskFiles) {
          if (f is File && !f.path.endsWith('.enc')) {
            final name = f.uri.pathSegments.last;
            final mime = name.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg';
            final stat = f.statSync();
            recovered.add(KiokuMemory(
              id: name.split('.').first,
              fileName: name,
              mimeType: mime,
              takenAtIso: stat.modified.toIso8601String(),
              uploaderName: 'You',
              addedAt: stat.modified,
              sizeBytes: stat.size,
              localPath: f.path,
              albumId: albumId,
            ));
          }
        }
        return recovered;
      } catch (_) {
        return [];
      }
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final memories = <KiokuMemory>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final localPath = item['localPath']?.toString() ?? '';
          final fileName = item['fileName']?.toString() ?? '';
          final fileInDir = File('${albumDir.path}/$fileName');
          final effectivePath = (fileName.isNotEmpty && fileInDir.existsSync())
              ? fileInDir.path
              : (localPath.isNotEmpty && File(localPath).existsSync() ? localPath : null);

          // Verify file still exists on disk
          if (effectivePath != null) {
            memories.add(KiokuMemory(
              id: item['id']?.toString() ?? '',
              fileName: fileName.isNotEmpty ? fileName : (item['id']?.toString() ?? ''),
              mimeType: item['mimeType']?.toString() ?? 'image/jpeg',
              caption: item['caption']?.toString(),
              takenAtIso: item['takenAtIso']?.toString() ?? DateTime.now().toIso8601String(),
              uploaderName: item['uploaderName']?.toString() ?? 'You',
              addedAt: DateTime.tryParse(item['addedAt']?.toString() ?? '') ?? DateTime.now(),
              sizeBytes: (item['sizeBytes'] as num?)?.toInt(),
              localPath: effectivePath,
              albumId: albumId,
            ));
          }
        }
      }
      return memories;
    } catch (_) {
      return [];
    }
  }

  /// Collects memories from all local albums (used for Flashbacks).
  Future<List<KiokuMemory>> getAllMemories() async {
    final albums = await _loadRawAlbums();
    final all = <KiokuMemory>[];
    for (final album in albums) {
      final mems = await getMemories(album.id);
      all.addAll(mems);
    }
    return all;
  }

  /// Deletes a local memory file from disk and updates album index.
  Future<void> deleteMemory(String memoryId) async {
    final albums = await _loadRawAlbums();
    for (final album in albums) {
      final mems = await getMemories(album.id);
      final matchIndex = mems.indexWhere((m) => m.id == memoryId);
      if (matchIndex != -1) {
        final match = mems[matchIndex];
        if (match.localPath != null) {
          final f = File(match.localPath!);
          if (await f.exists()) {
            await f.delete();
          }
        }
        final updated = List<KiokuMemory>.from(mems)..removeAt(matchIndex);
        await _saveMemoriesList(album.id, updated);
        break;
      }
    }
  }

  final Map<String, String> _memoryPathIndex = {};

  void _indexMemories(List<KiokuMemory> memories) {
    for (final m in memories) {
      if (m.localPath != null) {
        _memoryPathIndex[m.id] = m.localPath!;
      }
    }
  }

  /// Resolves the local path for a memory id if present
  String? getLocalPath(String memoryId) {
    if (File(memoryId).existsSync()) return memoryId;
    return _memoryPathIndex[memoryId];
  }

  /// Reads bytes for a local memory file.
  Future<Uint8List?> getPhotoBytes(String memoryId, {String? albumId}) async {
    final indexedPath = _memoryPathIndex[memoryId];
    if (indexedPath != null) {
      final f = File(indexedPath);
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    }

    if (albumId != null) {
      final albumMemories = await getMemories(albumId);
      _indexMemories(albumMemories);
      final match = albumMemories.where((m) => m.id == memoryId).firstOrNull;
      if (match != null && match.localPath != null) {
        final f = File(match.localPath!);
        if (await f.exists()) {
          return await f.readAsBytes();
        }
      }
    }

    final all = await getAllMemories();
    _indexMemories(all);
    final match = all.where((m) => m.id == memoryId).firstOrNull;
    if (match != null && match.localPath != null) {
      final f = File(match.localPath!);
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    }
    return null;
  }

  Future<void> _saveMemoriesList(String albumId, List<KiokuMemory> memories) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = memories.map((m) => {
      'id': m.id,
      'fileName': m.fileName,
      'mimeType': m.mimeType,
      'caption': m.caption,
      'takenAtIso': m.takenAtIso,
      'uploaderName': m.uploaderName,
      'addedAt': m.addedAt.toIso8601String(),
      'sizeBytes': m.sizeBytes,
      'localPath': m.localPath,
    }).toList();
    await prefs.setString(_kMemoriesPrefix + albumId, jsonEncode(jsonList));
  }
}
