import 'dart:io';
import 'package:flutter_mobile/core/models/memory.dart';

abstract interface class IUploadRepository {
  Future<KiokuMemory> uploadMemory({
    required String albumId,
    required File file,
    required String mimeType,
    String? caption,
    String? takenAt,
  });
}
