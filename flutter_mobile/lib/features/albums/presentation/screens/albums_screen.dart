import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/design_system/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';


class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  Future<void> _pickThumbnailForAlbum(
    BuildContext context,
    WidgetRef ref,
    Album album,
  ) async {
    final hasThumb = album.thumbnailPath != null &&
        album.thumbnailPath!.isNotEmpty &&
        File(album.thumbnailPath!).existsSync();

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            if (hasThumb)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Thumbnail', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'remove') {
      await ref.read(albumsProvider.notifier).setAlbumThumbnail(album.id, null);
      await ref.read(albumsProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thumbnail removed for "${album.title}"')),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        await ref
            .read(albumsProvider.notifier)
            .setAlbumThumbnail(album.id, picked.path);
        await ref.read(albumsProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thumbnail updated for "${album.title}"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set thumbnail: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final albumsAsync = ref.watch(albumsProvider);
    final albums = albumsAsync.value ?? <Album>[];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Albums',
          style: typography.displayLarge?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create New Album',
            icon: Icon(Icons.add_circle_outline, color: colors.primary, size: 26),
            onPressed: () async {
              final name = await CreateAlbumDialog.show(context);
              if (name != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Album "$name" created')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          onRefresh: () async {
            await ref.read(albumsProvider.notifier).refresh();
          },
          child: albumsAsync.isLoading && albums.isEmpty
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : albums.isEmpty
                  ? _buildEmptyState(context, colors, typography)
                  : _buildAlbumGrid(context, ref, albums, colors, typography),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppColors colors,
    TextTheme typography,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        KiokuEmptyState(
          icon: Icons.photo_library_outlined,
          title: 'No albums yet',
          subtitle: 'Create an album to organize your photos and share with close friends.',
          buttonText: 'Create First Album',
          onButtonPressed: () => CreateAlbumDialog.show(context),
        ),
      ],
    );
  }

  Widget _buildAlbumGrid(
    BuildContext context,
    WidgetRef ref,
    List<Album> albums,
    AppColors colors,
    TextTheme typography,
  ) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _buildAlbumTile(context, ref, album, colors, typography);
      },
    );
  }

  Widget _buildAlbumTile(
    BuildContext context,
    WidgetRef ref,
    Album album,
    AppColors colors,
    TextTheme typography,
  ) {
    final albumTint = colors.withAlbumTint(album.id);
    final hasThumb = album.thumbnailPath != null &&
        album.thumbnailPath!.isNotEmpty &&
        File(album.thumbnailPath!).existsSync();

    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Card body tap target (navigates to album, long-press to edit thumbnail)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(activeAlbumProvider.notifier).set(album.id);
                  context.push('/albums/${album.id}', extra: album);
                },
                onLongPress: () => _pickThumbnailForAlbum(context, ref, album),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image or tinted stylized paper background
                    if (hasThumb)
                      Image.file(
                        File(album.thumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackBackground(albumTint),
                      )
                    else
                      _buildFallbackBackground(albumTint),

                    // Morphing vignette / dark overlay to blend image and text seamlessly
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: hasThumb ? 0.35 : 0.15),
                            Colors.black.withValues(alpha: hasThumb ? 0.55 : 0.40),
                            Colors.black.withValues(alpha: hasThumb ? 0.80 : 0.65),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),

                    // Centered morphing text and storage badge
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Centered album title morphing with the picture
                            Text(
                              album.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typography.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    offset: const Offset(0, 1.5),
                                    blurRadius: 6,
                                  ),
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    offset: const Offset(0, 3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Storage and memories indicator badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    album.storageType.toLowerCase() == 'google'
                                        ? Icons.cloud_outlined
                                        : Icons.folder_outlined,
                                    size: 11,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    album.storageType.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-right host thumbnail picker action button (isolated gesture arena)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickThumbnailForAlbum(context, ref, album),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Icon(
                    hasThumb ? Icons.edit_outlined : Icons.add_a_photo_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBackground(AppColors albumTint) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            albumTint.accentSoft.withValues(alpha: 0.6),
            albumTint.primaryDark.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_library_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
