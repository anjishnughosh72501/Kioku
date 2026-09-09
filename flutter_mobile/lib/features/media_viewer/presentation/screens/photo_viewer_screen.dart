/// PhotoViewerScreen — full-screen photo viewer with pinch-to-zoom.
/// The photo bytes are fetched privately with the signed-in user's token.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.mediaId, this.memory});

  final String mediaId;
  final KiokuMemory? memory;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    final mem = widget.memory;
    if (mem != null && mem.localPath != null && mem.localPath!.isNotEmpty) {
      _bytesFuture = File(mem.localPath!).readAsBytes();
    } else if (LocalStorageService.instance.isLocalMemory(widget.mediaId)) {
      _bytesFuture = LocalStorageService.instance
          .getPhotoBytes(widget.mediaId)
          .then((b) => b ?? (throw Exception('Photo not found on device')));
    } else {
      _bytesFuture = AppDrive.instance.photoBytes(widget.mediaId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final item = widget.memory;

    final caption = item?.caption;
    final meta =
        item != null ? '${item.postmarkDate} · ${item.uploaderLabel}' : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<Uint8List>(
            future: _bytesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: colors.primary),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 56, color: Colors.white38),
                      const SizedBox(height: 8),
                      Text('Could not load this memory',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              }
              return PhotoView(
                imageProvider: MemoryImage(snapshot.data!),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                initialScale: PhotoViewComputedScale.contained,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                heroAttributes: PhotoViewHeroAttributes(tag: widget.mediaId),
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption ?? 'Memory',
                      style: typography.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Fraunces',
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: typography.bodySmall?.copyWith(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}