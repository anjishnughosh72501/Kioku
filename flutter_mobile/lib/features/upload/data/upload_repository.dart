import 'dart:io';
import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import '../domain/i_upload_repository.dart';

class UploadRepository implements IUploadRepository {
  const UploadRepository();

  @override
  Future<KiokuMemory> uploadMemory({
    required String albumId,
    required File file,
    required String mimeType,
    String? caption,
    String? takenAt,
  }) {
    if (AppDrive.instance.isBound && !albumId.startsWith('local_')) {
      return AppDrive.instance.uploadMemory(
        albumId: albumId,
        file: file,
        mimeType: mimeType,
        caption: caption,
        takenAt: takenAt,
      );
    }
    return LocalStorageService.instance.saveMemory(
      albumId: albumId,
      file: file,
      mimeType: mimeType,
      caption: caption,
      takenAt: takenAt,
      uploaderName: UserProfileService.instance.username,
    );
  }
}
