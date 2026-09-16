import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';
import 'package:share_plus/share_plus.dart';

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
                style: typography.headlineSmall?.copyWith(color: colors.ink),
              ),
            ),
            ...albums.map((album) {
              final selected = album.id == activeAlbumId;
              return ListTile(
                title: Text(album.title, style: typography.bodyMedium?.copyWith(color: colors.ink)),
                leading: Icon(
                  selected ? Icons.folder_special : Icons.folder_outlined,
                  color: selected ? colors.accentDark : colors.inkMuted,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.share_outlined, size: 18, color: colors.accentDark),
                      tooltip: 'Invite friends to album',
                      onPressed: () {
                        Share.share(
                          'Join my memory album "${album.title}" on Kioku! Download the Kioku app, sign in with your Google account, and collaborate on our shared memories.',
                          subject: 'Kioku Memory Album: ${album.title}',
                        );
                      },
                    ),
                    if (selected) Icon(Icons.check_circle, color: colors.accentDark, size: 20),
                  ],
                ),
                onTap: () {
                  ref.read(activeAlbumProvider.notifier).set(album.id);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            ListTile(
              leading: Icon(Icons.create_new_folder_outlined, color: colors.accent),
              title: Text('New album…', style: typography.bodyMedium?.copyWith(color: colors.accentDark)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final name = await CreateAlbumDialog.show(context);
                if (name != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Album "$name" created')),
                  );
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
        ),
      ),
    );
  }
}
