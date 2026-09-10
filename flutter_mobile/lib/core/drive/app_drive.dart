/// AppDrive — thin wrapper around the Google Drive API, authenticated as the
/// signed-in Google user. Files stay private; every read uses the user's token.
library;

import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';

class _BudgetLRU {
  _BudgetLRU({required this.maxBytes});
  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap<String, Uint8List>();
  int _used = 0;

  Uint8List? get(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _map[key] = v; // promote to MRU
    }
    return v;
  }

  void put(String key, Uint8List bytes) {
    if (_map.containsKey(key)) {
      _used -= _map[key]!.length;
      _map.remove(key);
    }
    while (_used + bytes.length > maxBytes && _map.isNotEmpty) {
      final oldestKey = _map.keys.first;
      _used -= _map[oldestKey]!.length;
      _map.remove(oldestKey);
    }
    _map[key] = bytes;
    _used += bytes.length;
  }

  void remove(String key) {
    final v = _map.remove(key);
    if (v != null) {
      _used -= v.length;
    }
  }

  void clear() {
    _map.clear();
    _used = 0;
  }
}

class AppDrive {
  AppDrive._();

  static final AppDrive instance = AppDrive._();

  GoogleSignInAccount? _account;
  drive.DriveApi? _api;
  String? _accessToken;
  DateTime? _apiExpiry;

  final _BudgetLRU _bytesCache = _BudgetLRU(maxBytes: 50 * 1024 * 1024); // 50MB

  bool get isBound => _account != null;

  /// Attach the signed-in account. Subsequent Drive calls use its token.
  void bind(GoogleSignInAccount account) {
    _account = account;
    _api = null;
    _accessToken = null;
    _apiExpiry = null;
  }

  void clear() {
    _account = null;
    _api = null;
    _accessToken = null;
    _apiExpiry = null;
    _bytesCache.clear();
  }

  /// Returns a valid bearer token for the Drive scope, re-authorizing only
  /// when needed (Google caches this, so it is cheap).
  Future<String> accessToken() async {
    if (_account == null) throw StateError('Google account not signed in');
    final fresh =
        _apiExpiry != null && DateTime.now().isBefore(_apiExpiry!);
    if (_accessToken != null && fresh) return _accessToken!;
    final authz = await _account!.authorizationClient
        .authorizeScopes([drive.DriveApi.driveFileScope]);
    _accessToken = authz.accessToken;
    _apiExpiry = DateTime.now().add(const Duration(minutes: 50));
    _api = null;
    return _accessToken!;
  }

  Future<drive.DriveApi> api() async {
    final token = await accessToken();
    _api ??= drive.DriveApi(
      authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            token,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          null,
          [drive.DriveApi.driveFileScope],
        ),
      ),
    );
    return _api!;
  }

  // ===== Albums =====

  Future<List<Album>> listAlbums() async {
    final driveApi = await api();
    final res = await driveApi.files.list(
      q:
          "mimeType='application/vnd.google-apps.folder' "
          "and trashed=false and name contains '${Album.prefix}'",
      spaces: 'drive',
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
      orderBy: 'createdTime',
      $fields: 'files(id,name)',
    );
    return (res.files ?? []).map(Album.fromDriveFolder).toList();
  }

  Future<Album> createAlbum(String name) async {
    final driveApi = await api();
    final folder = drive.File(
      name: Album.driveName(name),
      mimeType: 'application/vnd.google-apps.folder',
    );
    final created = await driveApi.files.create(folder, $fields: 'id,name');
    return Album.fromDriveFolder(created);
  }

  Future<void> shareAlbum(
    String albumId,
    String email, {
    String role = 'writer',
  }) async {
    final driveApi = await api();
    await driveApi.permissions.create(
      drive.Permission(role: role, type: 'user', emailAddress: email),
      albumId,
    );
  }

  Future<List<AlbumMember>> albumMembers(String albumId) async {
    final driveApi = await api();
    final res = await driveApi.permissions.list(
      albumId,
      $fields: 'permissions(emailAddress,role,displayName,type)',
    );
    final perms = res.permissions ?? [];
    return perms
        .where((p) => p.type == 'user')
        .map(
          (p) => AlbumMember(
            email: p.emailAddress ?? '',
            role: p.role ?? 'reader',
            displayName: p.displayName,
          ),
        )
        .toList();
  }

  // ===== Memories =====

  Future<List<KiokuMemory>> listMemories(String albumId) async {
    final driveApi = await api();
    final List<drive.File> allFiles = [];
    String? pageToken;

    do {
      final res = await driveApi.files.list(
        q: "'$albumId' in parents and trashed=false",
        orderBy: 'createdTime desc',
        pageSize: 100,
        pageToken: pageToken,
        $fields:
            'nextPageToken,files(id,name,mimeType,size,createdTime,thumbnailLink,appProperties,'
            'owners(displayName,emailAddress))',
      );
      allFiles.addAll(res.files ?? []);
      pageToken = res.nextPageToken;
    } while (pageToken != null);

    return allFiles.map(KiokuMemory.fromDrive).toList();
  }

  Future<({List<KiokuMemory> items, String? nextPageToken})> listMemoriesPage(
    String albumId, {
    int pageSize = 30,
    String? pageToken,
  }) async {
    final driveApi = await api();
    final res = await driveApi.files.list(
      q: "'$albumId' in parents and trashed=false",
      orderBy: 'createdTime desc',
      pageSize: pageSize,
      pageToken: pageToken,
      $fields:
          'nextPageToken,files(id,name,mimeType,size,createdTime,thumbnailLink,appProperties,'
          'owners(displayName,emailAddress))',
    );
    final files = res.files ?? [];
    return (
      items: files.map(KiokuMemory.fromDrive).toList(),
      nextPageToken: res.nextPageToken,
    );
  }

  Future<void> deleteMemory(String fileId) async {
    final driveApi = await api();
    await driveApi.files.delete(fileId);
    evictBytes(fileId);
  }

  /// Uploads a photo/video and records caption + taken-at as Drive app
  /// properties so they travel with the file to friends' devices too.
  Future<KiokuMemory> uploadMemory({
    required String albumId,
    required File file,
    required String mimeType,
    String? caption,
    String? takenAt,
  }) async {
    final account = _account;
    if (account == null) throw StateError('Google account not signed in');
    final driveApi = await api();

    final customUsername = UserProfileService.instance.username;
    final displayName = (customUsername.isNotEmpty && customUsername != 'Storyteller')
        ? customUsername
        : (account.displayName ?? account.email.split('@').first);

    final props = <String, String>{
      'taken_at': takenAt ?? DateTime.now().toIso8601String(),
      'uploader_name': displayName,
      'uploader_email': account.email,
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim(),
    };

    final request = drive.File(
      name: file.uri.pathSegments.last,
      parents: [albumId],
      mimeType: mimeType,
      appProperties: props,
    );

    final created = await driveApi.files.create(
      request,
      uploadMedia: drive.Media(
        file.openRead(),
        file.lengthSync(),
        contentType: mimeType,
      ),
      $fields:
          'id,name,mimeType,size,createdTime,thumbnailLink,appProperties,'
          'owners(displayName,emailAddress)',
    );
    return KiokuMemory.fromDrive(created);
  }

  /// Fetches full media bytes for a photo with the user's bearer token.
  /// Results are cached in memory so feed scrolling stays smooth.
  Future<Uint8List> photoBytes(String fileId) async {
    final cached = _bytesCache.get(fileId);
    if (cached != null) return cached;
    final token = await accessToken();
    final client = http.Client();
    try {
      final resp = await client.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode != 200) {
        throw HttpException('Drive fetch failed ($fileId): ${resp.statusCode}');
      }
      final bytes = resp.bodyBytes;
      _bytesCache.put(fileId, bytes);
      return bytes;
    } finally {
      client.close();
    }
  }

  void evictBytes(String fileId) => _bytesCache.remove(fileId);
}