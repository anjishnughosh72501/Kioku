import 'dart:typed_data';
import 'local_storage_provider.dart';
import 'mesh_index.dart';
import 'storage_provider.dart';

abstract class IMeshNetworkTransport {
  Future<void> broadcastBlob({
    required String containerId,
    required String objectId,
    required Uint8List ciphertext,
  });

  Future<Uint8List?> fetchFromPeer({
    required String containerId,
    required String objectId,
    required Set<String> candidatePeers,
  });

  Future<void> broadcastDelete({
    required String containerId,
    required String objectId,
  });
}

class MeshStorageProvider implements StorageProvider {
  final LocalStorageProvider _localProvider;
  final MeshIndex _index;
  final IMeshNetworkTransport? _transport;

  MeshStorageProvider({
    LocalStorageProvider? localProvider,
    MeshIndex? index,
    IMeshNetworkTransport? transport,
  })  : _localProvider = localProvider ?? const LocalStorageProvider(),
        _index = index ?? MeshIndex.instance,
        _transport = transport;

  @override
  StorageProviderType get type => StorageProviderType.mesh;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(
        displayName: 'Peer-to-Peer Mesh Storage',
        isPeerToPeer: true,
      );

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    // 1. Store on local device first
    await _localProvider.putBlob(
      ciphertext,
      containerId: containerId,
      objectId: objectId,
    );

    // 2. Update mesh index
    await _index.saveEntry(
      MeshIndexEntry(
        objectId: objectId,
        containerId: containerId,
        hasFullRes: true,
        hasThumb: true,
        knownHolders: {'local_device'},
        lastSeen: DateTime.now(),
      ),
    );

    // 3. Broadcast to connected peers if transport is active
    if (_transport != null) {
      await _transport.broadcastBlob(
        containerId: containerId,
        objectId: objectId,
        ciphertext: ciphertext,
      );
    }

    return objectId;
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    // Check if we have the blob locally
    try {
      return await _localProvider.getBlob(objectId, containerId: containerId);
    } catch (_) {
      // Not present locally, try to fetch from peers
      final entry = await _index.getEntry(objectId);
      if (entry != null && _transport != null && entry.knownHolders.isNotEmpty) {
        final peerBytes = await _transport.fetchFromPeer(
          containerId: containerId,
          objectId: objectId,
          candidatePeers: entry.knownHolders,
        );
        if (peerBytes != null) {
          // Cache locally
          await _localProvider.putBlob(
            peerBytes,
            containerId: containerId,
            objectId: objectId,
          );
          await _index.saveEntry(entry.copyWith(hasFullRes: true));
          return peerBytes;
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {
    await _localProvider.deleteBlob(objectId, containerId: containerId);
    await _index.deleteEntry(objectId);
    if (_transport != null) {
      await _transport.broadcastDelete(containerId: containerId, objectId: objectId);
    }
  }

  @override
  Future<List<String>> listBlobs(String containerId) async {
    final localBlobs = await _localProvider.listBlobs(containerId);
    final indexedBlobs = await _index.listBlobIds(containerId);
    return {...localBlobs, ...indexedBlobs}.toList();
  }
}
