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
import 'package:flutter_mobile/features/feed/data/encrypted_memory_repository.dart';

class DriveThumb extends ConsumerStatefulWidget {
  const DriveThumb({super.key, required this.memory});

  final KiokuMemory memory;

  @override
  ConsumerState<DriveThumb> createState() => _DriveThumbState();
}

class _DriveThumbState extends ConsumerState<DriveThumb> {
  late Future<Uint8List> _future;
  KiokuMemory? _forMemory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  void _ensureFuture() {
    final memory = widget.memory;
    if (_forMemory?.id != memory.id) {
      _forMemory = memory;
      final activeAlbum = ref.read(activeAlbumProvider) ?? 'default';
      final repo = ref.read(encryptedMemoryRepositoryProvider);
      if (memory.localPath != null && memory.localPath!.isNotEmpty) {
        _future = File(memory.localPath!).readAsBytes();
      } else {
        _future = _fetchBytes(repo, memory, activeAlbum);
      }
    }
  }

  Future<Uint8List> _fetchBytes(
    EncryptedMemoryRepository repo,
    KiokuMemory memory,
    String activeAlbum,
  ) async {
    try {
      final thumb = await repo.getThumbnailBytes(memory.id, albumId: activeAlbum);
      if (thumb != null) return thumb;
      return await repo.getPhotoBytes(memory.id, albumId: activeAlbum);
    } catch (_) {
      return await AppDrive.instance.photoBytes(memory.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final memory = widget.memory;

    if (memory.isVideo) {
      return Stack(
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

    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: colors.surfaceContainerLow,
            child: Center(
              child: Icon(Icons.image_outlined, size: 40, color: colors.inkSubtle),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            color: colors.surfaceContainerLow,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 40, color: colors.inkSubtle),
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          semanticLabel: memory.caption != null && memory.caption!.isNotEmpty
              ? memory.caption
              : 'Memory from ${memory.postmarkDate}',
        );
      },
    );
  }
}