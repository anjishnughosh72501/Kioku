import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../drive/app_drive.dart';
import 'storage_provider.dart';

class DriveStorageProvider implements StorageProvider {
  const DriveStorageProvider();

  @override
  StorageProviderType get type => StorageProviderType.drive;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(
        displayName: 'Google Drive',
        supportsResumableUpload: true,
      );

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    final driveApi = await AppDrive.instance.api();
    final request = drive.File(
      name: '$objectId.enc',
      parents: [containerId],
      mimeType: 'application/octet-stream',
    );

    final mediaStream = Stream.value(ciphertext);
    final created = await driveApi.files.create(
      request,
      uploadMedia: drive.Media(
        mediaStream,
        ciphertext.length,
        contentType: 'application/octet-stream',
      ),
      $fields: 'id,name',
    );

    return created.id ?? objectId;
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    final token = await AppDrive.instance.accessToken();
    final client = http.Client();
    try {
      final resp = await client.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$objectId?alt=media',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode != 200) {
        throw http.ClientException('Drive fetch failed ($objectId): ${resp.statusCode}');
      }
      return resp.bodyBytes;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {
    final driveApi = await AppDrive.instance.api();
    await driveApi.files.delete(objectId);
  }

  @override
  Future<List<String>> listBlobs(String containerId) async {
    final driveApi = await AppDrive.instance.api();
    final List<String> allIds = [];
    String? pageToken;

    do {
      final res = await driveApi.files.list(
        q: "'$containerId' in parents and trashed=false",
        orderBy: 'createdTime desc',
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name)',
      );
      for (final f in res.files ?? []) {
        if (f.id != null) {
          allIds.add(f.id!);
        }
      }
      pageToken = res.nextPageToken;
    } while (pageToken != null);

    return allIds;
  }
}
