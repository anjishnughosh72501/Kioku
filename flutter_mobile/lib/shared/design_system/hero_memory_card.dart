import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/design_system/encrypted_badge.dart';
import 'package:flutter_mobile/shared/widgets/drive_thumb.dart';

class HeroMemoryCard extends ConsumerWidget {
  const HeroMemoryCard({
    super.key,
    required this.item,
    this.badgeLabel = 'HERO MEMORY',
    this.albumName,
  });

  final KiokuMemory item;
  final String badgeLabel;
  final String? albumName;

  void _showContextMenu(BuildContext context, WidgetRef ref, AppColors colors) {
    HapticFeedback.mediumImpact();
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
              title: Text('Share memory', style: typography.bodyMedium?.copyWith(color: colors.ink)),
              onTap: () {
                Navigator.of(ctx).pop();
                final text = item.caption != null && item.caption!.isNotEmpty
                    ? '${item.caption!} (${item.postmarkDate})'
                    : 'A memory from ${item.postmarkDate}';
                Share.share(text);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.danger),
              title: Text('Delete memory', style: typography.bodyMedium?.copyWith(color: colors.danger)),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(context, ref, colors);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppColors colors) {
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
      if (confirmed == true) {
        try {
          await ref.read(memoriesProvider.notifier).delete(item.id);
          if (context.mounted) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    final albums = ref.watch(albumsProvider).valueOrNull ?? [];
    final activeAlbumId = ref.watch(activeAlbumProvider);
    final currentAlbum = albums.where((a) => a.id == (item.albumId ?? activeAlbumId)).firstOrNull;
    final displayAlbum = albumName ?? item.albumName ?? currentAlbum?.title ?? 'Album';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/media/${item.id}', extra: item);
      },
      onLongPress: () => _showContextMenu(context, ref, colors),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero Photo
              Hero(
                tag: 'memory_media_${item.id}',
                child: DriveThumb(
                  key: ValueKey('hero_thumb_${item.id}'),
                  memory: item,
                ),
              ),

              // Gradient scrim for contrast
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
              ),

              // Top Bar: Badge & Encryption Indicator
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const EncryptedBadge(
                      variant: EncryptedBadgeVariant.compact,
                    ),
                  ],
                ),
              ),

              // Bottom Details
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Album & Postmark date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  displayAlbum,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.postmarkDate,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Caption or placeholder
                    if (item.caption != null && item.caption!.trim().isNotEmpty) ...[
                      Text(
                        item.caption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typography.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Author line
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Captured by ${item.uploaderLabel}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
