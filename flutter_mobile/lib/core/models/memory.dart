/// Local models for Kioku memories and albums, backed by Google Drive.
library;

import 'package:googleapis/drive/v3.dart' as drive;

/// An album is a folder in the signed-in user's (or a friend's) Drive.
/// Folder names are prefixed with [Album.prefix] so they are easy to find.
class Album {
  const Album({required this.id, required this.name});

  static const String prefix = 'Kioku · ';

  final String id;
  final String name;

  static Album fromDriveFolder(drive.File f) {
    final raw = f.name?.toString() ?? '';
    final name = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
    return Album(id: f.id ?? '', name: name);
  }

  /// Display name without the Kioku prefix.
  String get title => name;

  static String driveName(String albumName) => '$prefix$albumName';
}

/// A person the album folder is shared with.
class AlbumMember {
  const AlbumMember({
    required this.email,
    required this.role,
    this.displayName,
  });

  final String email;
  final String role; // 'writer' | 'reader' | 'owner'
  final String? displayName;
}

/// A single memory (photo/video file on Drive) with app metadata.
class KiokuMemory {
  const KiokuMemory({
    required this.id,
    required this.fileName,
    required this.mimeType,
    this.caption,
    required this.takenAtIso,
    this.uploaderName,
    this.uploaderEmail,
    required this.addedAt,
    this.thumbnailUrl,
    this.driveOwnerEmail,
    this.sizeBytes,
    this.localPath,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final String? caption;
  final String takenAtIso;
  final String? uploaderName;
  final String? uploaderEmail;
  final DateTime addedAt;
  final String? thumbnailUrl;
  final String? driveOwnerEmail;
  final int? sizeBytes;
  final String? localPath;

  bool get isLocal => localPath != null && localPath!.isNotEmpty;
  bool get isVideo => mimeType.startsWith('video/');
  bool get hasCaption => caption != null && caption!.trim().isNotEmpty;

  DateTime? get takenAt => DateTime.tryParse(takenAtIso);

  String get postmarkDate {
    final d = takenAt;
    if (d == null) return '';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}.$mm.$dd';
  }

  String get uploaderLabel {
    if (uploaderName != null && uploaderName!.isNotEmpty) return uploaderName!;
    final email = uploaderEmail ?? driveOwnerEmail;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Anon';
  }

  factory KiokuMemory.fromDrive(drive.File f) {
    final props = f.appProperties ?? const <String, String>{};
    final taken =
        props['taken_at'] ??
        f.createdTime?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    return KiokuMemory(
      id: f.id ?? '',
      fileName: f.name ?? '',
      mimeType: f.mimeType ?? 'application/octet-stream',
      caption: props['caption'],
      takenAtIso: taken,
      uploaderName: props['uploader_name'],
      uploaderEmail: props['uploader_email'],
      addedAt: DateTime.tryParse(f.createdTime?.toString() ?? '') ?? DateTime.now(),
      thumbnailUrl: f.thumbnailLink,
      driveOwnerEmail:
          (f.owners != null && f.owners!.isNotEmpty)
              ? f.owners!.first.emailAddress
              : null,
      sizeBytes: int.tryParse(f.size ?? ''),
    );
  }
}