/// VideoPlayerScreen — full-screen video player streaming straight from the
/// signed-in user's Drive using an authorized `alt=media` request with the
/// bearer token in the header.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:path_provider/path_provider.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.mediaId, this.memory});

  final String mediaId;
  final KiokuMemory? memory;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final mem = widget.memory;
      final VideoPlayerController controller;
      final activeAlbum = ref.read(activeAlbumProvider) ?? '';

      final isEncrypted = (mem?.localPath != null && mem!.localPath!.endsWith('.enc')) ||
          (mem?.id != null && mem!.id.endsWith('.enc')) ||
          widget.mediaId.endsWith('.enc');

      if (isEncrypted && activeAlbum.isNotEmpty) {
        final repo = ref.read(encryptedMemoryRepositoryProvider);
        final bytes = await repo.getPhotoBytes(widget.mediaId, albumId: activeAlbum);
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/dec_${widget.mediaId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.mp4');
        await tempFile.writeAsBytes(bytes);
        controller = VideoPlayerController.file(tempFile);
      } else if (mem != null && mem.localPath != null && mem.localPath!.isNotEmpty) {
        controller = VideoPlayerController.file(File(mem.localPath!));
      } else if (LocalStorageService.instance.isLocalMemory(widget.mediaId)) {
        final path = LocalStorageService.instance.getLocalPath(widget.mediaId);
        if (path != null && File(path).existsSync()) {
          if (path.endsWith('.enc') && activeAlbum.isNotEmpty) {
            final repo = ref.read(encryptedMemoryRepositoryProvider);
            final bytes = await repo.getPhotoBytes(widget.mediaId, albumId: activeAlbum);
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/dec_${widget.mediaId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.mp4');
            await tempFile.writeAsBytes(bytes);
            controller = VideoPlayerController.file(tempFile);
          } else {
            controller = VideoPlayerController.file(File(path));
          }
        } else {
          throw Exception('Local video file not found');
        }
      } else {
        // Resolve the current Drive token, then stream with it in the header.
        final token = await ref.read(driveAuthTokenProvider.future);
        final uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${widget.mediaId}?alt=media',
        );

        controller = VideoPlayerController.networkUrl(
          uri,
          httpHeaders: {'Authorization': 'Bearer $token'},
        );
      }

      _videoController = controller;
      await controller.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: context.kiokuColors.primary),
          ),
        ),
        errorBuilder: (context, errorMessage) => Center(
          child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: context.kiokuColors.primary,
          handleColor: context.kiokuColors.primary,
          bufferedColor: context.kiokuColors.primary.withValues(alpha: 0.5),
          backgroundColor: Colors.white.withValues(alpha: 0.3),
        ),
      );

      setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load video');
      }
      _videoController?.dispose();
      _videoController = null;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined, size: 56, color: Colors.white38),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.brightness == Brightness.dark
                          ? const Color(0xFF140E0A)
                          : Colors.white,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _initialized = false;
                      });
                      _initializePlayer();
                    },
                  ),
                ],
              ),
            )
          else if (_initialized && _chewieController != null)
            Chewie(controller: _chewieController!)
          else
            Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  tooltip: 'Close video',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}