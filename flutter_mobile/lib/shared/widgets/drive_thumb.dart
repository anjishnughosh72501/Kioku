/// DriveThumb — renders a memory tile (photo bytes or video badge) using the
/// signed-in user's Drive access token. Every read is private and authorized.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/core/providers.dart';

class DriveThumb extends ConsumerStatefulWidget {
  const DriveThumb({super.key, required this.memory});

  final KiokuMemory memory;

  @override
  ConsumerState<DriveThumb> createState() => _DriveThumbState();
}

class _DriveThumbState extends ConsumerState<DriveThumb> {
  static final Map<String, Uint8List> _thumbCache = {};

  Uint8List? _bytes;
  bool _isLoading = false;
  bool _hasError = false;
  String? _loadedMemoryId;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(covariant DriveThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memory.id != widget.memory.id ||
        oldWidget.memory.localPath != widget.memory.localPath) {
      _loadBytes();
    }
  }

  void _loadBytes() {
    final memory = widget.memory;
    _loadedMemoryId = memory.id;

    // 1. Check in-memory cache
    final cached = _thumbCache[memory.id];
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    // 2. Immediately clear stale image from previous memory item
    setState(() {
      _bytes = null;
      _isLoading = true;
      _hasError = false;
    });

    final targetId = memory.id;
    _fetchBytes(memory).then((bytes) {
      if (!mounted || _loadedMemoryId != targetId) return;
      _thumbCache[targetId] = bytes;
      setState(() {
        _bytes = bytes;
        _isLoading = false;
        _hasError = false;
      });
    }).catchError((_) {
      if (!mounted || _loadedMemoryId != targetId) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  Future<Uint8List> _fetchBytes(KiokuMemory memory) async {
    if (memory.localPath != null && memory.localPath!.isNotEmpty) {
      final file = File(memory.localPath!);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }

    final albumId = memory.albumId ?? ref.read(activeAlbumProvider) ?? 'default';
    final repo = ref.read(encryptedMemoryRepositoryProvider);
    try {
      final thumb = await repo.getThumbnailBytes(memory.id, albumId: albumId);
      if (thumb != null) return thumb;
      return await repo.getPhotoBytes(memory.id, albumId: albumId);
    } catch (_) {
      if (!memory.id.startsWith('mem_') && !memory.id.endsWith('.enc')) {
        return await AppDrive.instance.photoBytes(memory.id);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final memory = widget.memory;

    if (memory.isVideo) {
      return Stack(
        key: ValueKey('video_${memory.id}'),
        fit: StackFit.expand,
        children: [
          Container(
            color: colors.surfaceContainerLow,
            child: Center(
              child: Icon(Icons.movie_outlined, size: 40, color: colors.inkSubtle),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Container(
        key: ValueKey('loading_${memory.id}'),
        color: colors.surfaceContainerLow,
        child: Center(
          child: Icon(Icons.image_outlined, size: 40, color: colors.inkSubtle),
        ),
      );
    }

    if (_hasError || _bytes == null) {
      return Container(
        key: ValueKey('error_${memory.id}'),
        color: colors.surfaceContainerLow,
        child: Center(
          child: Icon(Icons.broken_image_outlined, size: 40, color: colors.inkSubtle),
        ),
      );
    }

    return Image.memory(
      _bytes!,
      key: ValueKey('img_${memory.id}'),
      fit: BoxFit.cover,
      gaplessPlayback: false,
      filterQuality: FilterQuality.medium,
      semanticLabel: memory.caption != null && memory.caption!.isNotEmpty
          ? memory.caption
          : 'Memory from ${memory.postmarkDate}',
    );
  }
}