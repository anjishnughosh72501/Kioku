import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:flutter_mobile/core/storage/local_storage_provider.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/storage/mesh_index.dart';
import 'package:flutter_mobile/core/storage/mesh_storage_provider.dart';

class MockMeshTransport implements IMeshNetworkTransport {
  final Map<String, Uint8List> networkBlobs = {};
  final List<String> broadcastedDeletes = [];

  @override
  Future<void> broadcastBlob({
    required String containerId,
    required String objectId,
    required Uint8List ciphertext,
  }) async {
    networkBlobs['$containerId/$objectId'] = ciphertext;
  }

  @override
  Future<Uint8List?> fetchFromPeer({
    required String containerId,
    required String objectId,
    required Set<String> candidatePeers,
  }) async {
    return networkBlobs['$containerId/$objectId'];
  }

  @override
  Future<void> broadcastDelete({
    required String containerId,
    required String objectId,
  }) async {
    broadcastedDeletes.add('$containerId/$objectId');
    networkBlobs.remove('$containerId/$objectId');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderWindows.registerWith();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MeshStorageProvider stores locally and resolves missing blobs from peers', () async {
    final transport = MockMeshTransport();
    final provider = MeshStorageProvider(
      localProvider: const LocalStorageProvider(),
      index: MeshIndex.instance,
      transport: transport,
    );

    const albumId = 'mesh_album_1';
    final payload = Uint8List.fromList([42, 43, 44, 45]);

    // 1. Put blob
    await provider.putBlob(payload, containerId: albumId, objectId: 'blob_mesh_101');
    expect(transport.networkBlobs['$albumId/blob_mesh_101'], equals(payload));

    // 2. Read back locally
    final readBack = await provider.getBlob('blob_mesh_101', containerId: albumId);
    expect(readBack, equals(payload));

    // 3. Simulate peer having a blob that is NOT yet on this device
    transport.networkBlobs['$albumId/blob_peer_202'] = Uint8List.fromList([99, 98, 97]);
    await MeshIndex.instance.saveEntry(
      MeshIndexEntry(
        objectId: 'blob_peer_202',
        containerId: albumId,
        hasFullRes: false,
        hasThumb: true,
        knownHolders: {'peer_alice'},
        lastSeen: DateTime.now(),
      ),
    );

    // List should see both blobs
    final blobs = await provider.listBlobs(albumId);
    expect(blobs, containsAll(['blob_mesh_101', 'blob_peer_202']));

    // Fetch peer blob -> transparently retrieves via transport and caches locally
    final fetchedPeerBlob = await provider.getBlob('blob_peer_202', containerId: albumId);
    expect(fetchedPeerBlob, equals([99, 98, 97]));

    // Delete blob
    await provider.deleteBlob('blob_mesh_101', containerId: albumId);
    expect(transport.broadcastedDeletes, contains('$albumId/blob_mesh_101'));

    // Clean up
    await LocalStorageService.instance.deleteAlbum(albumId);
  });
}
