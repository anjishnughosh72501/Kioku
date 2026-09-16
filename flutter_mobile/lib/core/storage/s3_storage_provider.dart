import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'storage_provider.dart';

class S3StorageConfig {
  final String endpoint; // e.g. 'https://s3.us-east-1.amazonaws.com' or Cloudflare R2 / B2 URL
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String region;

  const S3StorageConfig({
    required this.endpoint,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.region = 'us-east-1',
  });

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'bucket': bucket,
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        'region': region,
      };

  factory S3StorageConfig.fromJson(Map<String, dynamic> json) => S3StorageConfig(
        endpoint: json['endpoint'] as String,
        bucket: json['bucket'] as String,
        accessKeyId: json['accessKeyId'] as String,
        secretAccessKey: json['secretAccessKey'] as String,
        region: json['region'] as String? ?? 'us-east-1',
      );
}

class S3StorageProvider implements StorageProvider {
  final S3StorageConfig config;
  final http.Client _client;

  S3StorageProvider({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  StorageProviderType get type => StorageProviderType.s3;

  @override
  StorageCapabilities get capabilities => const StorageCapabilities(
        displayName: 'S3-Compatible Cloud Storage',
        supportsResumableUpload: true,
      );

  // AWS SigV4 implementation
  Map<String, String> _signRequest({
    required String method,
    required Uri uri,
    required Uint8List payload,
    Map<String, String>? extraHeaders,
  }) {
    final now = DateTime.now().toUtc();
    final dateStamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final amzDate =
        '${dateStamp}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';

    final payloadHash = sha256.convert(payload).toString();

    final host = uri.host + (uri.hasPort ? ':${uri.port}' : '');
    final headers = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      ...?extraHeaders,
    };

    final sortedKeys = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
    final canonicalHeaders =
        sortedKeys.map((k) => '$k:${headers[k]!.trim()}\n').join('');
    final signedHeaders = sortedKeys.join(';');

    final canonicalUri = uri.path.isEmpty ? '/' : uri.path;
    final canonicalQuery = uri.query;

    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final canonicalRequestHash =
        sha256.convert(utf8.encode(canonicalRequest)).toString();

    final credentialScope = '$dateStamp/${config.region}/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    // Key derivation
    List<int> hmacSha256(List<int> key, String data) {
      final hmac = Hmac(sha256, key);
      return hmac.convert(utf8.encode(data)).bytes;
    }

    final kSecret = utf8.encode('AWS4${config.secretAccessKey}');
    final kDate = hmacSha256(kSecret, dateStamp);
    final kRegion = hmacSha256(kDate, config.region);
    final kService = hmacSha256(kRegion, 's3');
    final kSigning = hmacSha256(kService, 'aws4_request');

    final signature = Hmac(sha256, kSigning)
        .convert(utf8.encode(stringToSign))
        .toString();

    final authHeader =
        'AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return {
      ...headers,
      'Authorization': authHeader,
    };
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final baseUri = Uri.parse(config.endpoint);
    final cleanBase = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(
      path: '$cleanBase/${config.bucket}$cleanPath',
      queryParameters: queryParams,
    );
  }

  @override
  Future<String> putBlob(
    Uint8List ciphertext, {
    required String containerId,
    required String objectId,
  }) async {
    final uri = _buildUri('$containerId/$objectId.enc');
    final headers = _signRequest(
      method: 'PUT',
      uri: uri,
      payload: ciphertext,
      extraHeaders: {'content-type': 'application/octet-stream'},
    );

    final res = await _client.put(uri, headers: headers, body: ciphertext).timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
        'S3 putBlob failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }
    return objectId;
  }

  @override
  Future<Uint8List> getBlob(String objectId, {required String containerId}) async {
    final uri = _buildUri('$containerId/$objectId.enc');
    final headers = _signRequest(
      method: 'GET',
      uri: uri,
      payload: Uint8List(0),
    );

    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw http.ClientException(
        'S3 getBlob failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }
    return res.bodyBytes;
  }

  @override
  Future<void> deleteBlob(String objectId, {required String containerId}) async {
    final uri = _buildUri('$containerId/$objectId.enc');
    final headers = _signRequest(
      method: 'DELETE',
      uri: uri,
      payload: Uint8List(0),
    );

    final res = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
        'S3 deleteBlob failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }
  }

  @override
  Future<List<String>> listBlobs(String containerId) async {
    final prefix = '$containerId/';
    final uri = _buildUri('', {'prefix': prefix});
    final headers = _signRequest(
      method: 'GET',
      uri: uri,
      payload: Uint8List(0),
    );

    final res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw http.ClientException(
        'S3 listBlobs failed (${res.statusCode}): ${res.body}',
        uri,
      );
    }

    final doc = XmlDocument.parse(res.body);
    final keys = <String>[];
    for (final node in doc.findAllElements('Key')) {
      final text = node.innerText;
      if (text.startsWith(prefix) && text.endsWith('.enc')) {
        final filename = text.substring(prefix.length);
        final objectId = filename.substring(0, filename.length - 4);
        keys.add(objectId);
      }
    }
    return keys;
  }
}
