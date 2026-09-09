import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';

/// Compact album switcher shown in the feed header.
class AlbumDropdown extends ConsumerWidget {
  const AlbumDropdown({
    super.key,
    required this.albums,
    required this.activeAlbumId,
    required this.colors,
    required this.typography,
  });

  final List<Album> albums;
  final String? activeAlbumId;
  final AppColors colors;
  final TextTheme typography;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = albums.where((a) => a.id == activeAlbumId).firstOrNull;
    return InkWell(
      onTap: () => _showPicker(context, ref),
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              current?.title ?? (albums.length > 1 ? 'Pick an album' : albums.first.title),
              overflow: TextOverflow.ellipsis,
              style: typography.bodyMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 20, color: colors.inkMuted),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Text(
                'Your albums',
                style: typography.headlineSmall?.copyWith(color: colors.ink, fontFamily: 'Fraunces'),
              ),
            ),
            ...albums.map((album) {
              final selected = album.id == activeAlbumId;
              return ListTile(
                title: Text(album.title, style: typography.bodyMedium?.copyWith(color: colors.ink)),
                trailing: selected ? Icon(Icons.check_circle, color: colors.accentDark) : null,
                onTap: () {
                  ref.read(activeAlbumProvider.notifier).set(album.id);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            ListTile(
              leading: Icon(Icons.create_new_folder_outlined, color: colors.accent),
              title: Text('New album…', style: typography.bodyMedium?.copyWith(color: colors.accentDark)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _promptNewAlbum(context, ref);
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
        ),
      ),
    );
  }

  /// Creates a new album from an inline dialog.
  void _promptNewAlbum(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          title: Text(
            'Name your album',
            style: typography.headlineSmall?.copyWith(color: colors.ink, fontFamily: 'Fraunces'),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. Summer 2026'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();
                try {
                  await ref.read(albumsProvider.notifier).addAlbum(name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Album "$name" created')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create album: $e'),
                        backgroundColor: colors.danger,
                      ),
                    );
                  }
                }
              },
              child: Text('Create', style: typography.bodyMedium?.copyWith(color: colors.accentDark)),
            ),
          ],
        );
      },
    );
  }
}
