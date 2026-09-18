import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/services/invite_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/drive_thumb.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    this.album,
  });

  final String albumId;
  final Album? album;

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  late Future<List<AlbumMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = AppDrive.instance.albumMembers(widget.albumId);
  }

  Future<String> _buildInviteUrl(String title) async {
    final userProfile = ref.read(userProfileProvider);
    String claimParams = '';
    try {
      final claim = await InviteService.instance.createInviteClaim(albumId: widget.albumId);
      if (claim != null) {
        if (claim.claimToken.isNotEmpty) {
          claimParams += '&claim=${Uri.encodeComponent(claim.claimToken)}';
        }
        if (claim.inviterPubKey.isNotEmpty) {
          claimParams += '&pubKey=${Uri.encodeComponent(claim.inviterPubKey)}';
        }
      }
    } catch (_) {}

    return 'https://kioku.app/invite?albumId=${widget.albumId}&albumName=${Uri.encodeComponent(title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}$claimParams';
  }

  Future<void> _shareInviteLink(String title) async {
    final link = await _buildInviteUrl(title);
    final appUri = link.replaceFirst('https://kioku.app/', 'kioku://');

    Share.share(
      'Join my memory album "$title" on Kioku!\n\n'
      'Tap to open and join:\n$link\n\n'
      'Or app link: $appUri',
      subject: 'Kioku Memory Album: $title',
    );
  }

  Future<void> _pickThumbnail(
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
                title: const Text('Remove Cover Photo', style: TextStyle(color: Colors.red)),
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
          SnackBar(content: Text('Cover photo removed for "${album.title}"')),
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
              content: Text('Cover photo updated for "${album.title}"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set cover photo: $e')),
        );
      }
    }
  }

  Future<void> _showInviteDialog(BuildContext context, AppColors colors, TextTheme typography, String title) async {
    final friends = ref.read(connectedFriendsProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, size: 22, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invite to "$title"',
                  style: typography.headlineSmall?.copyWith(
                    color: colors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connected Friends Section
                if (friends.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Connected Friends (${friends.length})',
                        style: typography.bodyMedium?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap a friend to send an invite link directly:',
                    style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.divider, width: 0.5),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: friends.length,
                      separatorBuilder: (_, _) => Divider(color: colors.divider, height: 1),
                      itemBuilder: (context, index) {
                        final code = friends[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor: colors.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.person_rounded, size: 14, color: colors.primary),
                          ),
                          title: Text(
                            code,
                            style: typography.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                            ),
                          ),
                          trailing: Icon(Icons.send_rounded, size: 15, color: colors.accentDark),
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            final link = await _buildInviteUrl(title);
                            final appUri = link.replaceFirst('https://kioku.app/', 'kioku://');
                            Share.share(
                              'Hey $code! Join my memory album "$title" on Kioku!\n\n'
                              'Tap to open and join:\n$link\n\n'
                              'Or app link: $appUri',
                              subject: 'Kioku Memory Album: $title',
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Divider(color: colors.divider),
                  const SizedBox(height: AppTheme.spacingSm),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: colors.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add friends using their Friend Code in your Profile, or share an invite link below to connect automatically!',
                            style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                ],

                // Share Link Section
                Row(
                  children: [
                    Icon(Icons.link_rounded, size: 16, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Album Invite Link',
                      style: typography.bodyMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Anyone with this link will automatically connect with you and join this album.',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          final link = await _buildInviteUrl(title);
                          await Clipboard.setData(ClipboardData(text: link));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invite link copied to clipboard!')),
                            );
                          }
                        },
                        icon: Icon(Icons.copy_rounded, size: 16, color: colors.ink),
                        label: Text(
                          'Copy Link',
                          style: typography.bodySmall?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClayButton(
                        label: 'Share Link',
                        icon: const Icon(Icons.share_outlined, size: 16),
                        size: ClayButtonSize.small,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _shareInviteLink(title);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Close', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    final albums = ref.watch(albumsProvider).value ?? <Album>[];
    final currentAlbum = albums.where((a) => a.id == widget.albumId).firstOrNull ??
        widget.album ??
        Album(id: widget.albumId, name: 'Album');

    final memoriesAsync = ref.watch(memoriesProvider);
    final memories = memoriesAsync.value ?? <KiokuMemory>[];

    final hasCover = currentAlbum.thumbnailPath != null &&
        currentAlbum.thumbnailPath!.isNotEmpty &&
        File(currentAlbum.thumbnailPath!).existsSync();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: colors.background,
              pinned: true,
              elevation: 0,
              title: Text(
                currentAlbum.title,
                style: typography.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Change Cover Photo',
                  icon: Icon(
                    hasCover ? Icons.edit_outlined : Icons.add_photo_alternate_outlined,
                    color: colors.primary,
                  ),
                  onPressed: () => _pickThumbnail(context, ref, currentAlbum),
                ),
                IconButton(
                  tooltip: 'Share Invite Link',
                  icon: Icon(Icons.share_outlined, color: colors.accentDark),
                  onPressed: () => _shareInviteLink(currentAlbum.title),
                ),
                IconButton(
                  tooltip: 'Invite Friends',
                  icon: Icon(Icons.person_add_alt_1_outlined, color: colors.primary),
                  onPressed: () => _showInviteDialog(context, colors, typography, currentAlbum.title),
                ),
                const SizedBox(width: 4),
              ],
            ),

            // Optional Cover Banner
            if (hasCover)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        child: SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(currentAlbum.thumbnailPath!),
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.65),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _pickThumbnail(context, ref, currentAlbum),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white38, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Change Cover',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
              ),

            // Members bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                child: FutureBuilder<List<AlbumMember>>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    final members = snapshot.data ?? [];
                    if (members.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: colors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group_outlined, size: 16, color: colors.inkMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${members.length} ${members.length == 1 ? "member" : "members"}: ${members.map((m) => m.displayName ?? m.email.split('@').first).join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
 style: typography.bodySmall?.copyWith(
 color: colors.inkMuted,
 fontSize: 12,
 ),
 ),
 ),
 ],
 ),
 );
 },
 ),
 ),
 ),

 // 2x2 Photo Grid
 if (memoriesAsync.isLoading && memories.isEmpty)
 SliverFillRemaining(
 child: Center(child: CircularProgressIndicator(color: colors.primary)),
 )
 else if (memories.isEmpty)
 SliverFillRemaining(
 child: Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(Icons.photo_outlined, size: 54, color: colors.inkMuted.withValues(alpha: 0.5)),
 const SizedBox(height: 12),
 Text('No photos yet', style: typography.headlineSmall?.copyWith(color: colors.ink)),
 const SizedBox(height: 6),
 Text('Capture photos to add them to this album.',
 style: typography.bodySmall?.copyWith(color: colors.inkMuted)),
                  const SizedBox(height: 18),
                  ClayButton(
                    label: 'Add Photo',
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    onPressed: () => context.push('/upload'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final memory = memories[index];
                  return RepaintBoundary(
                    key: ValueKey(memory.id),
                    child: GestureDetector(
                      onTap: () => context.push('/media/${memory.id}', extra: memory),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusPhoto),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DriveThumb(memory: memory),
                            if (memory.isVideo)
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: memories.length,
              ),
            ),
          ),
      ],
    ),
  ),
);
}
}
