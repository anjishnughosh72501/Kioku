/// UploadScreen — Add a new memory (photo or video) to the active album.
/// Files are uploaded to the signed-in user's own Google Drive.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exif/exif.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/washi_tape.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();

  XFile? _pickedFile;
  bool _isVideo = false;
  bool _uploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file == null) return;
    setState(() {
      _pickedFile = file;
      _isVideo = false;
    });
  }

  Future<void> _capturePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file == null) return;
    setState(() {
      _pickedFile = file;
      _isVideo = false;
    });
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _pickedFile = file;
      _isVideo = true;
    });
  }

  /// Read the camera timestamp from EXIF when present, so flashbacks and day
  /// grouping reflect when the memory was actually taken.
  Future<String> _readTakenAt(File file) async {
    try {
      final tag = await readExifFromFile(file).then(
        (m) => m['EXIF DateTimeOriginal'],
      );
      final raw = tag?.printable;
      if (raw != null && raw.length >= 19) {
        return '${raw.substring(0, 4)}-${raw.substring(5, 7)}-'
            '${raw.substring(8, 10)}T${raw.substring(11, 19)}';
      }
    } catch (_) {
      // Fall through to fileModified.
    }
    return file.lastModifiedSync().toIso8601String();
  }

  Future<File> _compressPhoto(File original) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/kioku_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        targetPath,
        quality: 82,
        minWidth: 1920,
        minHeight: 1920,
        keepExif: true,
      );
      if (compressed != null) {
        return File(compressed.path);
      }
    } catch (_) {
      // Fall through to original
    }
    return original;
  }

  Future<void> _submit() async {
    final file = _pickedFile;
    final albumId = ref.read(activeAlbumProvider);
    if (file == null) {
      _showMessage('Choose a photo or video first');
      return;
    }
    if (albumId == null) {
      _showMessage('Create or pick an album first');
      return;
    }
    if (!AppDrive.instance.isBound) {
      _showMessage('Please sign in with Google first');
      return;
    }

    setState(() => _uploading = true);
    try {
      final detectedMime = lookupMimeType(file.path);
      final mime = detectedMime ?? (_isVideo ? 'video/mp4' : 'image/jpeg');
      final caption = _captionController.text.trim();
      final originalFile = File(file.path);
      final takenAt = await _readTakenAt(originalFile);

      final fileToUpload = _isVideo ? originalFile : await _compressPhoto(originalFile);

      await AppDrive.instance.uploadMemory(
        albumId: albumId,
        file: fileToUpload,
        mimeType: mime,
        caption: caption.isNotEmpty ? caption : null,
        takenAt: takenAt,
      );

      if (!mounted) return;
      ref.read(memoriesProvider.notifier).refresh();
      _showMessage('Memory saved to your album');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage('Upload failed: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final colors = context.kiokuColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.accentDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final albumsAsync = ref.watch(albumsProvider);
    final activeAlbumId = ref.watch(activeAlbumProvider);
    final albums = albumsAsync.value ?? <Album>[];
    final targetAlbum = albums.where((a) => a.id == activeAlbumId).firstOrNull;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.ink,
        elevation: 0,
        title: Text(
          'Add Memory',
          style: typography.headlineSmall?.copyWith(
            fontSize: 20,
            color: colors.accentDark,
            fontFamily: 'Fraunces',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClayCard(
                variant: ClayVariant.defaultCard,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    WashiTape(variant: WashiVariant.peach, angle: -2.5, width: 60)
                        .animate().fadeIn(delay: 100.ms, duration: 300.ms),
                    const SizedBox(height: AppTheme.spacingSm),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPhoto),
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPhoto),
                        ),
                        child: _pickedFile == null
                            ? _buildDropzone(colors, typography)
                            : _isVideo
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        color: colors.surfaceContainer,
                                        child: Center(
                                          child: Icon(Icons.movie_outlined,
                                              size: 56, color: colors.inkMuted),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.55),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.play_arrow,
                                              color: Colors.white, size: 36),
                                        ),
                                      ),
                                    ],
                                  )
                                : Image.file(
                                    File(_pickedFile!.path),
                                    fit: BoxFit.cover,
                                  ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      _pickLabel(),
                      style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: AppTheme.spacingMd),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.photo_library_outlined, size: 17, color: colors.ink),
                      label: Text('Choose from Library',
                          style: typography.bodyMedium?.copyWith(fontSize: 13, color: colors.ink)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
                        side: BorderSide(color: colors.divider),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _capturePhoto,
                      icon: Icon(Icons.camera_alt_outlined, size: 17, color: colors.ink),
                      label: Text('Take a Photo',
                          style: typography.bodyMedium?.copyWith(fontSize: 13, color: colors.ink)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
                        side: BorderSide(color: colors.divider),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: AppTheme.spacingSm),
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: Icon(Icons.videocam_outlined, size: 17, color: colors.ink),
                label: Text('Choose a Video',
                    style: typography.bodyMedium?.copyWith(fontSize: 13, color: colors.ink)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
                  side: BorderSide(color: colors.divider),
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingMd),

              // Target album
              ClayCard(
                variant: ClayVariant.defaultCard,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Row(
                  children: [
                    Icon(Icons.folder_open_outlined, size: 16, color: colors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Album: ${targetAlbum?.title ?? '—'}',
                        style: typography.bodyMedium?.copyWith(color: colors.ink),
                      ),
                    ),
                    if (activeAlbumId == null)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Pick an album',
                            style: typography.bodySmall?.copyWith(color: colors.accentDark)),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 180.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              ClayCard(
                variant: ClayVariant.defaultCard,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: TextField(
                  controller: _captionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'What you felt, the conversation, the scent of the wind...',
                    hintStyle: typography.bodyMedium?.copyWith(color: colors.inkSubtle),
                    border: InputBorder.none,
                  ),
                  style: typography.bodyMedium?.copyWith(color: colors.ink),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              ClayButton(
                label: _uploading ? 'Saving...' : 'Save Memory to Album',
                variant: ClayButtonVariant.primary,
                onPressed: _uploading ? null : _submit,
                loading: _uploading,
                fullWidth: true,
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingXl),
            ],
          ),
        ),
      ),
    );
  }

  String _pickLabel() {
    if (_pickedFile == null) return 'Tap to choose from library';
    return _isVideo ? 'Video ready to save' : 'Photo ready to save';
  }

  Widget _buildDropzone(AppColors colors, TextTheme typography) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(Icons.camera_alt_outlined, size: 24, color: colors.ink),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            'Drop a photo here',
            style: typography.headlineSmall?.copyWith(
                fontSize: 18, color: colors.ink, fontFamily: 'Fraunces'),
          ),
          const SizedBox(height: 8),
          Text(
            'Film scans, instant photos, or brief everyday scenes',
            style: typography.bodySmall?.copyWith(color: colors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}