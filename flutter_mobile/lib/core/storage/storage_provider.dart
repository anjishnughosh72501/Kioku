import 'dart:typed_data';

enum StorageProviderType {
  local,
  drive,
  s3,
  webdav,
  mesh,
}

class StorageCapabilities {
  final String displayName;
  final bool supportsResumableUpload;
  final int? quotaBytes;
  final int? usedBytes;
  final bool isPeerToPeer;

  const StorageCapabilities({
    required this.displayName,
    this.supportsResumableUpload = false,
    this.quotaBytes,
    this.usedBytes,
    this.isPeerToPeer = false,
  });
}

abstract class StorageProvider {
  /// Unique identifier for this provider type
  StorageProviderType get type;

  /// Capability hints for UI
  StorageCapabilities get capabilities;

  /// Store an opaque ciphertext blob. Returns the storage-specific object ID.
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  });

  /// Retrieve an opaque ciphertext blob by object ID.
  Future<Uint8List> getBlob(String objectId, {required String containerId});

  /// Delete an opaque blob by object ID.
  Future<void> deleteBlob(String objectId, {required String containerId});

  /// List all blob IDs stored within a container (e.g. album).
  Future<List<String>> listBlobs(String containerId);
}
