import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
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

  void _shareInviteLink(String title) {
    final userProfile = ref.read(userProfileProvider);
    final link = 'https://kioku.app/invite?albumId=${widget.albumId}&albumName=${Uri.encodeComponent(title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';
    final appUri = 'kioku://invite?albumId=${widget.albumId}&albumName=${Uri.encodeComponent(title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';

    Share.share(
      'Join my memory album "$title" on Kioku!\n\n'
      'Tap to open and join:\n$link\n\n'
      'Or app link: $appUri',
      subject: 'Kioku Memory Album: $title',
    );
  }

  Future<void> _inviteByEmail(BuildContext context, AppColors colors, TextTheme typography, String title) async {
    final controller = TextEditingController();
    String? inlineError;
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    final friends = ref.read(connectedFriendsProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
              title: Text(
                'Invite to "$title"',
                style: typography.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
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
                        'Tap a friend to send them an invitation link:',
                        style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
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
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                final userProfile = ref.read(userProfileProvider);
                                final link = 'https://kioku.app/invite?albumId=${widget.albumId}&albumName=${Uri.encodeComponent(title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';
                                final appUri = 'kioku://invite?albumId=${widget.albumId}&albumName=${Uri.encodeComponent(title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';

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
                      const SizedBox(height: AppTheme.spacingLg),
                      Divider(color: colors.divider),
                      const SizedBox(height: AppTheme.spacingSm),
                    ],

                    // Direct Email Section
                    Row(
                      children: [
                        Icon(Icons.mail_outline, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Invite by Google Email',
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
                      'Give read & write access to view and add photos.',
                      style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'friend@gmail.com',
                        errorText: inlineError,
                        prefixIcon: Icon(Icons.alternate_email, color: colors.primary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
                ),
                ClayButton(
                  label: 'Send Invite',
                  size: ClayButtonSize.small,
                  onPressed: () async {
                    final email = controller.text.trim();
                    if (!emailRegex.hasMatch(email)) {
                      setDialogState(() => inlineError = 'Enter a valid email address');
                      return;
                    }
                    try {
                      await ref.read(albumsProvider.notifier).share(widget.albumId, email);
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invited $email to album')),
                        );
                        setState(() {
                          _membersFuture = AppDrive.instance.albumMembers(widget.albumId);
                        });
                      }
                    } catch (e) {
                      setDialogState(() => inlineError = 'Could not share: $e');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

 @override
 Widget build(BuildContext context) {
 final colors = context.kiokuColors;
 final typography = Theme.of(context).textTheme;

 final albums = ref.watch(albumsProvider).value ?? <Album>[];
 final currentAlbum = widget.album ??
 albums.where((a) => a.id == widget.albumId).firstOrNull ??
 Album(id: widget.albumId, name: 'Album');

 final memoriesAsync = ref.watch(memoriesProvider);
 final memories = memoriesAsync.value ?? <KiokuMemory>[];

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
 tooltip: 'Share Invite Link',
 icon: Icon(Icons.share_outlined, color: colors.accentDark),
 onPressed: () => _shareInviteLink(currentAlbum.title),
 ),
 IconButton(
 tooltip: 'Invite by Email',
 icon: Icon(Icons.person_add_alt_1_outlined, color: colors.primary),
 onPressed: () => _inviteByEmail(context, colors, typography, currentAlbum.title),
 ),
 const SizedBox(width: 4),
 ],
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
