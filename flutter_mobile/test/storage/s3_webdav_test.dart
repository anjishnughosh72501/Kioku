import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_mobile/core/storage/s3_storage_provider.dart';
import 'package:flutter_mobile/core/storage/webdav_storage_provider.dart';

void main() {
  group('S3StorageProvider', () {
    test('putBlob and getBlob sign requests with AWS4-HMAC-SHA256', () async {
      String? capturedAuthHeader;
      String? capturedAmzDate;

      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['authorization'];
        capturedAmzDate = request.headers['x-amz-date'];

        if (request.method == 'PUT') {
          return http.Response('', 200);
        } else if (request.method == 'GET' && request.url.path.contains('.enc')) {
          return http.Response.bytes([1, 2, 3, 4], 200);
        } else if (request.method == 'GET' && request.url.queryParameters.containsKey('prefix')) {
          const xmlResponse = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>test-bucket</Name>
  <Prefix>album_1/</Prefix>
  <Contents>
    <Key>album_1/photo_101.enc</Key>
    <Size>12345</Size>
  </Contents>
  <Contents>
    <Key>album_1/photo_102.enc</Key>
    <Size>67890</Size>
  </Contents>
</ListBucketResult>''';
          return http.Response(xmlResponse, 200);
        } else if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final provider = S3StorageProvider(
        config: const S3StorageConfig(
          endpoint: 'https://s3.us-east-1.amazonaws.com',
          bucket: 'test-bucket',
          accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
          secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
          region: 'us-east-1',
        ),
        client: mockClient,
      );

      // 1. Put blob
      final payload = Uint8List.fromList([10, 20, 30, 40]);
      final putId = await provider.putBlob(payload, containerId: 'album_1', objectId: 'photo_101');
      expect(putId, equals('photo_101'));
      expect(capturedAuthHeader, isNotNull);
      expect(capturedAuthHeader!.startsWith('AWS4-HMAC-SHA256 Credential='), isTrue);
      expect(capturedAmzDate, isNotNull);

      // 2. Get blob
      final fetched = await provider.getBlob('photo_101', containerId: 'album_1');
      expect(fetched, equals([1, 2, 3, 4]));

      // 3. List blobs
      final list = await provider.listBlobs('album_1');
      expect(list.length, equals(2));
      expect(list, containsAll(['photo_101', 'photo_102']));

      // 4. Delete blob
      await provider.deleteBlob('photo_101', containerId: 'album_1');
    });
  });

  group('WebDavStorageProvider', () {
    test('putBlob and listBlobs parse PROPFIND responses', () async {
      String? capturedAuth;

      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['authorization'];

        if (request.method == 'MKCOL' || request.method == 'PUT' || request.method == 'DELETE') {
          return http.Response('', 201);
        } else if (request.method == 'GET') {
          return http.Response.bytes([9, 8, 7], 200);
        } else if (request.method == 'PROPFIND') {
          const xmlResponse = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/Kioku/album_99/</d:href>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/Kioku/album_99/item_alpha.enc</d:href>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/Kioku/album_99/item_beta.enc</d:href>
  </d:response>
</d:multistatus>''';
          return http.Response(xmlResponse, 207);
        }
        return http.Response('Not Found', 404);
      });

      final provider = WebDavStorageProvider(
        config: const WebDavConfig(
          serverUrl: 'https://nextcloud.example.com',
          username: 'user',
          password: 'secretpassword',
          basePath: '/remote.php/dav/files/user/Kioku',
        ),
        client: mockClient,
      );

      // Put
      await provider.putBlob(
        Uint8List.fromList([1, 2]),
        containerId: 'album_99',
        objectId: 'item_alpha',
      );
      expect(capturedAuth, isNotNull);
      expect(capturedAuth!.startsWith('Basic '), isTrue);

      // Get
      final data = await provider.getBlob('item_alpha', containerId: 'album_99');
      expect(data, equals([9, 8, 7]));

      // List
      final blobs = await provider.listBlobs('album_99');
      expect(blobs.length, equals(2));
      expect(blobs, containsAll(['item_alpha', 'item_beta']));

      // Delete
      await provider.deleteBlob('item_alpha', containerId: 'album_99');
    });
  });
}
