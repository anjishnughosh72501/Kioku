/// PhotoViewerScreen — full-screen photo viewer with pinch-to-zoom,
/// swipe between album photos, auto-hiding controls, and swipe-down dismiss.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/design_system/encrypted_badge.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.mediaId,
    this.memory,
    this.albumMemories,
    this.initialIndex,
  });

  final String mediaId;
  final KiokuMemory? memory;
  final List<KiokuMemory>? albumMemories;
  final int? initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _springController;
  final Map<String, Future<Uint8List>> _bytesCache = {};

  late List<KiokuMemory> _memoriesList;
  late int _currentIndex;
  late String? _currentCaption;

  double _dragOffset = 0.0;
  bool _isZoomed = false;
  bool _showOverlay = true;
  Timer? _hideOverlayTimer;

  @override
  void initState() {
    super.initState();
    _currentCaption = widget.memory?.caption;

    _springController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {
          _dragOffset = _springController.value;
        });
      });

    // Populate initial memories list
    if (widget.albumMemories != null && widget.albumMemories!.isNotEmpty) {
      _memoriesList = widget.albumMemories!;
      _currentIndex = widget.initialIndex ??
          _memoriesList.indexWhere((m) => m.id == widget.mediaId).clamp(0, _memoriesList.length - 1);
    } else if (widget.memory != null) {
      _memoriesList = [widget.memory!];
      _currentIndex = 0;
    } else {
      _memoriesList = [];
      _currentIndex = 0;
    }

    _pageController = PageController(initialPage: _currentIndex);
    _startOverlayTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If we only had a single memory, check if all memories from provider are available
    if (_memoriesList.length <= 1) {
      final allMemories = ref.read(memoriesProvider).valueOrNull ?? [];
      final activeAlbum = widget.memory?.albumId ?? ref.read(activeAlbumProvider);
      final filtered = allMemories.where((m) {
        if (activeAlbum != null && activeAlbum.isNotEmpty) {
          return m.albumId == activeAlbum;
        }
        return true;
      }).toList();

      if (filtered.isNotEmpty) {
        final foundIndex = filtered.indexWhere((m) => m.id == widget.mediaId);
        if (foundIndex >= 0) {
          setState(() {
            _memoriesList = filtered;
            _currentIndex = foundIndex;
            _pageController.jumpToPage(_currentIndex);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _hideOverlayTimer?.cancel();
    _pageController.dispose();
    _springController.dispose();
    super.dispose();
  }

  void _startOverlayTimer() {
    _hideOverlayTimer?.cancel();
    _hideOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isZoomed) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
      if (_showOverlay) {
        _startOverlayTimer();
      } else {
        _hideOverlayTimer?.cancel();
      }
    });
  }

  KiokuMemory? get _activeMemory {
    if (_memoriesList.isNotEmpty && _currentIndex < _memoriesList.length) {
      return _memoriesList[_currentIndex];
    }
    return widget.memory;
  }

  String get _activeMediaId {
    return _activeMemory?.id ?? widget.mediaId;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;
      if (_dragOffset < 0) _dragOffset = 0;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffset > 130 || velocity > 650) {
      HapticFeedback.lightImpact();
      context.pop();
    } else {
      const spring = SpringDescription(
        mass: 1.0,
        stiffness: 320.0,
        damping: 25.0,
      );
      final simulation = SpringSimulation(spring, _dragOffset, 0.0, velocity);
      _springController.animateWith(simulation);
    }
  }

  Future<Uint8List> _getBytesForMemory(KiokuMemory? mem, String mediaId) {
    return _bytesCache.putIfAbsent(mediaId, () => _loadBytes(mem, mediaId));
  }

  Future<Uint8List> _loadBytes(KiokuMemory? mem, String mediaId) async {
    final activeAlbum = mem?.albumId ?? ref.read(activeAlbumProvider) ?? '';
    if (activeAlbum.isNotEmpty) {
      try {
        final repo = ref.read(encryptedMemoryRepositoryProvider);
        return await repo.getPhotoBytes(mediaId, albumId: activeAlbum);
      } catch (e) {
        if (mediaId.startsWith('mem_') || mediaId.endsWith('.enc')) {
          rethrow;
        }
      }
    }

    if (mem != null && mem.localPath != null && mem.localPath!.isNotEmpty) {
      final f = File(mem.localPath!);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        if (bytes.length >= 4 && bytes[0] == 0x4B && bytes[1] == 0x49 && bytes[2] == 0x4F) {
          if (activeAlbum.isNotEmpty) {
            final repo = ref.read(encryptedMemoryRepositoryProvider);
            return await repo.getPhotoBytes(mediaId, albumId: activeAlbum);
          }
        }
        return bytes;
      }
    }

    if (LocalStorageService.instance.isLocalMemory(mediaId)) {
      final b = await LocalStorageService.instance.getPhotoBytes(mediaId);
      if (b != null) return b;
      throw Exception('Photo not found on device');
    }

    return await AppDrive.instance.photoBytes(mediaId);
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
                _shareCurrentMemory(item);
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

  Future<void> _shareCurrentMemory(KiokuMemory? item) async {
    try {
      final bytes = await _getBytesForMemory(item, _activeMediaId);
      final fileName = item?.fileName ?? '$_activeMediaId.jpg';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: item?.mimeType ?? 'image/jpeg', name: fileName)],
        text: _currentCaption,
      );
    } catch (e) {
      final text = _currentCaption ?? 'A memory from ${item?.postmarkDate ?? 'Kioku'}';
      Share.share(text);
    }
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
          style: typography.headlineSmall?.copyWith(color: colors.ink),
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
          style: typography.headlineSmall?.copyWith(color: colors.ink),
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
          await ref.read(memoriesProvider.notifier).delete(_activeMediaId);
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
    final item = _activeMemory;

    final caption = _currentCaption ?? item?.caption;
    final meta = item != null ? '${item.postmarkDate} · ${item.uploaderLabel}' : '';
    final bgOpacity = (1.0 - (_dragOffset / 320.0)).clamp(0.0, 1.0);

    final albums = ref.watch(albumsProvider).valueOrNull ?? [];
    final currentAlbum = albums.where((a) => a.id == item?.albumId).firstOrNull;
    final albumTitle = item?.albumName ?? currentAlbum?.title ?? 'Kioku Memory';

    final itemCount = _memoriesList.isEmpty ? 1 : _memoriesList.length;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: GestureDetector(
        onTap: _toggleOverlay,
        onVerticalDragUpdate: _isZoomed ? null : _onVerticalDragUpdate,
        onVerticalDragEnd: _isZoomed ? null : _onVerticalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Center photo viewer / PageView
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                itemCount: itemCount,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _currentCaption = _memoriesList.isNotEmpty ? _memoriesList[index].caption : widget.memory?.caption;
                  });
                  _startOverlayTimer();
                },
                itemBuilder: (context, index) {
                  final memoryItem = _memoriesList.isNotEmpty ? _memoriesList[index] : widget.memory;
                  final mediaId = memoryItem?.id ?? widget.mediaId;

                  return FutureBuilder<Uint8List>(
                    future: _getBytesForMemory(memoryItem, mediaId),
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
                              const Icon(Icons.broken_image_outlined, size: 56, color: Colors.white38),
                              const SizedBox(height: 8),
                              Text(
                                'Could not load this memory',
                                style: typography.bodyMedium?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      }
                      return PhotoView(
                        imageProvider: MemoryImage(snapshot.data!),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 4,
                        initialScale: PhotoViewComputedScale.contained,
                        scaleStateChangedCallback: (state) {
                          final zoomed = state != PhotoViewScaleState.initial;
                          setState(() {
                            _isZoomed = zoomed;
                            if (zoomed) {
                              _showOverlay = false;
                            }
                          });
                        },
                        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                        heroAttributes: PhotoViewHeroAttributes(tag: 'memory_media_$mediaId'),
                      );
                    },
                  );
                },
              ),
            ),

            // Top overlay bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top: _showOverlay ? 0 : -100,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: bgOpacity,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                              tooltip: 'Close viewer',
                              onPressed: () => context.pop(),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  albumTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const EncryptedBadge(
                              variant: EncryptedBadgeVariant.standard,
                              label: 'E2EE',
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                              tooltip: 'More options',
                              onPressed: () => _showMoreMenu(context, item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom overlay bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              bottom: _showOverlay ? 0 : -160,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: bgOpacity,
                child: SafeArea(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (caption != null && caption.isNotEmpty) ...[
                                Text(
                                  caption,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (meta.isNotEmpty)
                                Text(
                                  meta,
                                  style: typography.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _shareCurrentMemory(item),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            padding: const EdgeInsets.all(12),
                          ),
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}