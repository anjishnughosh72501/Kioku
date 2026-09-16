import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 's3_storage_provider.dart';
import 'storage_provider.dart';
import 'webdav_storage_provider.dart';

class StorageSettingsService {
  final FlutterSecureStorage _storage;

  const StorageSettingsService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kActiveProviderType = 'kioku_storage_active_type';
  static const _kS3Config = 'kioku_storage_s3_config';
  static const _kWebDavConfig = 'kioku_storage_webdav_config';

  Future<StorageProviderType> getActiveProviderType() async {
    final raw = await _storage.read(key: _kActiveProviderType);
    if (raw == null) return StorageProviderType.local;
    return StorageProviderType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => StorageProviderType.local,
    );
  }

  Future<void> setActiveProviderType(StorageProviderType type) async {
    await _storage.write(key: _kActiveProviderType, value: type.name);
  }

  Future<S3StorageConfig?> getS3Config() async {
    final raw = await _storage.read(key: _kS3Config);
    if (raw == null) return null;
    try {
      return S3StorageConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveS3Config(S3StorageConfig config) async {
    await _storage.write(key: _kS3Config, value: jsonEncode(config.toJson()));
  }

  Future<WebDavConfig?> getWebDavConfig() async {
    final raw = await _storage.read(key: _kWebDavConfig);
    if (raw == null) return null;
    try {
      return WebDavConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWebDavConfig(WebDavConfig config) async {
    await _storage.write(key: _kWebDavConfig, value: jsonEncode(config.toJson()));
  }
}
