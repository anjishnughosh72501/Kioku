import 'dart:io';
import 'dart:typed_data';
import 'local_storage_service.dart';
import 'storage_provider.dart';

class LocalStorageProvider implements StorageProvider {
  const LocalStorageProvider();

  @override
  StorageProviderType get type => StorageProviderType.local;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(
        displayName: 'Device Storage',
        supportsResumableUpload: false,
      );

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    final albumDir = await LocalStorageService.instance.getAlbumDirectory(containerId);
    final file = File('${albumDir.path}/$objectId.enc');
    await file.writeAsBytes(ciphertext, flush: true);
    return objectId;
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    final albumDir = await LocalStorageService.instance.getAlbumDirectory(containerId);
    final file = File('${albumDir.path}/$objectId.enc');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    // Check without .enc suffix just in case
    final altFile = File('${albumDir.path}/$objectId');
    if (await altFile.exists()) {
      return await altFile.readAsBytes();
    }
    throw StateError('Local blob not found: $objectId in container $containerId');
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {
    final albumDir = await LocalStorageService.instance.getAlbumDirectory(containerId);
    final file = File('${albumDir.path}/$objectId.enc');
    if (await file.exists()) {
      await file.delete();
    }
    final altFile = File('${albumDir.path}/$objectId');
    if (await altFile.exists()) {
      await altFile.delete();
    }
  }

  @override
  Future<List<String>> listBlobs(String containerId) async {
    final albumDir = await LocalStorageService.instance.getAlbumDirectory(containerId);
    if (!await albumDir.exists()) return [];

    final entities = albumDir.listSync();
    final ids = <String>[];
    for (final entity in entities) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.enc')) {
          ids.add(name.substring(0, name.length - 4));
        }
      }
    }
    return ids;
  }
}
