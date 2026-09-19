import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/drive_thumb.dart';
import 'package:flutter_mobile/shared/design_system/encrypted_badge.dart';


class MemoryCard extends ConsumerWidget {
  const MemoryCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
    this.albumName,
  });

  final KiokuMemory item;
  final AppColors colors;
  final TextTheme typography;
  final String? albumName;

  void _showContextMenu(BuildContext context, WidgetRef ref) {
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
                _confirmDelete(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
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
    final albums = ref.watch(albumsProvider).valueOrNull ?? [];
    final activeAlbumId = ref.watch(activeAlbumProvider);
    final currentAlbum = albums.where((a) => a.id == (item.albumId ?? activeAlbumId)).firstOrNull;
    final displayAlbum = albumName ?? item.albumName ?? currentAlbum?.title ?? 'Album';

    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/media/${item.id}', extra: item),
      onLongPress: () => _showContextMenu(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
              child: Hero(
                tag: 'memory_media_${item.id}',
                child: DriveThumb(
                  key: ValueKey('thumb_${item.id}'),
                  memory: item,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 12, color: colors.primary),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              displayAlbum,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.bodySmall?.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EncryptedBadge(variant: EncryptedBadgeVariant.compact),
                        const SizedBox(width: 8),
                        Text(
                          item.postmarkDate,
                          style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: colors.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Posted by ',
                      style: typography.bodySmall?.copyWith(
                        color: colors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      item.uploaderLabel,
                      style: typography.bodySmall?.copyWith(
                        color: colors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (item.caption != null && item.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.headlineSmall?.copyWith(fontSize: 15, color: colors.ink),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
