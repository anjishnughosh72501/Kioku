import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'storage_provider.dart';

class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String basePath; // e.g. '/remote.php/dav/files/user/Kioku'

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.basePath = '/remote.php/dav/files',
  });

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'basePath': basePath,
      };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
        serverUrl: json['serverUrl'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        basePath: json['basePath'] as String? ?? '/remote.php/dav/files',
      );
}

class WebDavStorageProvider implements StorageProvider {
  final WebDavConfig config;
  final http.Client _client;

  WebDavStorageProvider({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  StorageProviderType get type => StorageProviderType.webdav;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(
        displayName: 'WebDAV / Nextcloud',
        supportsResumableUpload: false,
      );

  Map<String, String> get _authHeaders {
    final credentials = base64Encode(utf8.encode('${config.username}:${config.password}'));
    return {
      'Authorization': 'Basic $credentials',
    };
  }

  Uri _buildUri(String path) {
    final baseUri = Uri.parse(config.serverUrl);
    final cleanBase = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final cleanBasePath = config.basePath.startsWith('/') ? config.basePath : '/${config.basePath}';
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(path: '$cleanBase$cleanBasePath$cleanPath');
  }

  Future<void> _ensureDirectory(String containerId) async {
    final uri = _buildUri(containerId);
    final req = http.Request('MKCOL', uri)..headers.addAll(_authHeaders);
    try {
      await _client.send(req);
    } catch (_) {}
  }

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    await _ensureDirectory(containerId);
    final uri = _buildUri('$containerId/$objectId.enc');
    final res = await _client.put(
      uri,
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/octet-stream',
      },
      body: ciphertext,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
        'WebDAV putBlob failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }
    return objectId;
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    final uri = _buildUri('$containerId/$objectId.enc');
    final res = await _client.get(uri, headers: _authHeaders);

    if (res.statusCode != 200) {
      throw http.ClientException(
        'WebDAV getBlob failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }
    return res.bodyBytes;
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {
    final uri = _buildUri('$containerId/$objectId.enc');
    final res = await _client.delete(uri, headers: _authHeaders);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
        'WebDAV deleteBlob failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }
  }

  @override
  Future<List<String>> listBlobs(String containerId) async {
    final uri = _buildUri(containerId);
    final req = http.Request('PROPFIND', uri)
      ..headers.addAll({
        ..._authHeaders,
        'Depth': '1',
      });

    final streamedRes = await _client.send(req);
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 207 && (res.statusCode < 200 || res.statusCode >= 300)) {
      return [];
    }

    final keys = <String>[];
    try {
      final doc = XmlDocument.parse(res.body);
      final hrefNodes = doc.findAllElements('href', namespace: '*');
      for (final node in hrefNodes) {
        final href = Uri.decodeComponent(node.innerText);
        if (href.endsWith('.enc')) {
          final fileName = href.split('/').last;
          final objectId = fileName.substring(0, fileName.length - 4);
          keys.add(objectId);
        }
      }
    } catch (_) {}

    return keys;
  }
}
