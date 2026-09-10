/// PhotoViewerScreen — full-screen photo viewer with pinch-to-zoom.
/// The photo bytes are fetched privately with the signed-in user's token.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
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
  late String? _currentCaption;

  @override
  void initState() {
    super.initState();
    _currentCaption = widget.memory?.caption;
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

  void _showMoreMenu(BuildContext context, KiokuMemory? item) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: colors.ink),
              title: Text('Share', style: typography.bodyMedium?.copyWith(color: colors.ink)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  final bytes = await _bytesFuture;
                  final fileName = item?.fileName ?? '${widget.mediaId}.jpg';
                  await Share.shareXFiles(
                    [XFile.fromData(bytes, mimeType: item?.mimeType ?? 'image/jpeg', name: fileName)],
                    text: _currentCaption,
                  );
                } catch (e) {
                  final text = _currentCaption ?? 'A memory from ${item?.postmarkDate ?? 'Kioku'}';
                  Share.share(text);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colors.ink),
              title: Text('Edit Caption', style: typography.bodyMedium?.copyWith(color: colors.ink)),
              onTap: () {
                Navigator.of(ctx).pop();
                _promptEditCaption(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.danger),
              title: Text('Delete', style: typography.bodyMedium?.copyWith(color: colors.danger)),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeleteAndPop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _promptEditCaption(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final controller = TextEditingController(text: _currentCaption);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        title: Text(
          'Edit Caption',
          style: typography.headlineSmall?.copyWith(color: colors.ink, fontFamily: 'Fraunces'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Add a cozy note or caption...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _currentCaption = controller.text.trim());
              Navigator.of(dialogContext).pop();
            },
            child: Text('Save', style: typography.bodyMedium?.copyWith(color: colors.accentDark)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAndPop(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainer,
        title: Text(
          'Delete this memory?',
          style: typography.headlineSmall?.copyWith(color: colors.ink, fontFamily: 'Fraunces'),
        ),
        content: Text(
          'This will permanently remove it from your album. This action cannot be undone.',
          style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: typography.bodyMedium?.copyWith(color: colors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        try {
          await ref.read(memoriesProvider.notifier).delete(widget.mediaId);
          if (context.mounted) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Memory deleted')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete memory: $e'), backgroundColor: colors.danger),
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final item = widget.memory;

    final caption = _currentCaption;
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
                    tooltip: 'Close viewer',
                    onPressed: () => context.pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                    tooltip: 'More options',
                    onPressed: () => _showMoreMenu(context, item),
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
                    if (caption != null && caption.isNotEmpty) ...[
                      Text(
                        caption,
                        style: typography.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Fraunces',
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: typography.bodySmall?.copyWith(color: Colors.white70, fontSize: 11),
                      ),
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