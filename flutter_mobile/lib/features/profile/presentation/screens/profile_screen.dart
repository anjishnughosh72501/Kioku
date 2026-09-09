/// ProfileScreen — signed-in Google account, album manager (create / share /
/// members), and sign out. Storage is the user's own Google Drive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/services.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_mobile/features/profile/presentation/widgets/album_row.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final albums = albumsAsync.value ?? <Album>[];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (authState.photoUrl != null)
                        Container(
                          width: 30,
                          height: 30,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: colors.sageDark,
                            shape: BoxShape.circle,
                          ),
                          child: Image.network(
                            authState.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                        )
                      else
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/kiokulogo.jpg', fit: BoxFit.cover),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        'Account & Albums',
                        style: typography.headlineSmall?.copyWith(
                          fontSize: 24,
                          color: colors.ink,
                          fontFamily: 'Fraunces',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '設定',
                        style: typography.headlineSmall?.copyWith(
                          fontSize: 18,
                          color: colors.sage,
                          fontFamily: 'Fraunces',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your memories live in your own Google Drive',
                    style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0, duration: 400.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Google account card
              ClayCard(
                variant: ClayVariant.elevated,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(authState: authState, colors: colors),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authState.displayName ??
                                    (authState.isGuest ? 'Local Explorer' : 'Signed In'),
                                style: typography.headlineSmall?.copyWith(
                                  fontSize: 17,
                                  color: colors.ink,
                                  fontFamily: 'Fraunces',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                authState.email ??
                                    (authState.isGuest ? 'Offline Mode (Device Storage)' : '—'),
                                style: typography.bodySmall?.copyWith(
                                  color: colors.inkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (authState.isSignedIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentSoft,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_done_outlined,
                                    size: 13, color: colors.accentDark),
                                const SizedBox(width: 4),
                                Text(
                                  'Drive Connected',
                                  style: typography.bodySmall?.copyWith(
                                    color: colors.accentDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill),
                            ),
                            child: Text(
                              'Local Only',
                              style: typography.bodySmall?.copyWith(
                                color: colors.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Divider(color: colors.divider),
                    const SizedBox(height: AppTheme.spacingSm),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: colors.inkMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Your memories live in your Google Drive under "Kioku · <Album>". '
                            'Kioku never runs a central server or sees your private photos.',
                            style: typography.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colors.inkMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              // User Profile & Friend Code card
              ClayCard(
                variant: ClayVariant.elevated,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Your Kioku Identity',
                          style: typography.bodyMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () async {
                            await UsernameDialog.showEdit(context);
                            (context as Element).markNeedsBuild();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 14, color: colors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: typography.bodySmall?.copyWith(color: colors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Username',
                              style: typography.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colors.inkMuted,
                              ),
                            ),
                            Text(
                              UserProfileService.instance.username,
                              style: typography.headlineSmall?.copyWith(
                                fontSize: 18,
                                color: colors.ink,
                                fontFamily: 'Fraunces',
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Friend Code',
                                style: typography.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: colors.inkMuted,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    UserProfileService.instance.friendCode,
                                    style: typography.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: UserProfileService.instance.friendCode),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Friend code copied to clipboard!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Icon(Icons.copy_rounded, size: 16, color: colors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'Share this code with friends so they know who shared memories with them.',
                      style: typography.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Shared albums manager
              ClayCard(
                variant: ClayVariant.defaultCard,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_copy_outlined, size: 16, color: colors.ink),
                        const SizedBox(width: 8),
                        Text(
                          'Albums (${albums.length})',
                          style: typography.bodyMedium?.copyWith(color: colors.ink),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _promptNewAlbum(context, ref, colors, typography),
                          icon: Icon(Icons.add, size: 15, color: colors.accentDark),
                          label: Text('New Album',
                              style: typography.bodySmall?.copyWith(color: colors.accentDark)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                            side: BorderSide(color: colors.divider),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    if (albums.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                        child: Text(
                          'No albums yet — create one to start collecting memories.',
                          style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                        ),
                      )
                    else
                      ...albums.map(
                        (album) => AlbumRow(
                          key: ValueKey(album.id),
                          album: album,
                          colors: colors,
                          typography: typography,
                          onShare: () => _promptShareAlbum(
                            context, ref, album, colors, typography),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Sign out or Connect Drive
              SizedBox(
                width: double.infinity,
                child: ClayButton(
                  label: authState.isSignedIn ? 'Sign Out' : 'Connect Google Drive',
                  icon: authState.isSignedIn
                      ? null
                      : Icon(Icons.cloud_upload_outlined, size: 18, color: colors.ink),
                  variant: authState.isSignedIn
                      ? ClayButtonVariant.secondary
                      : ClayButtonVariant.primary,
                  onPressed: () {
                    if (authState.isSignedIn) {
                      ref.read(authControllerProvider.notifier).signOut();
                    } else {
                      ref.read(authControllerProvider.notifier).signIn();
                    }
                  },
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              Center(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.1),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/kiokulogo.jpg', fit: BoxFit.cover),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'Kioku · 記憶',
                      style: typography.headlineSmall?.copyWith(
                        fontSize: 15,
                        color: colors.ink,
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The past becomes warmth when shared with someone.',
                      style: typography.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: colors.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingXl),
            ],
          ),
        ),
      ),
    );
  }

  void _promptNewAlbum(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    TextTheme typography,
  ) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          title: Text('Name your album',
              style: typography.headlineSmall?.copyWith(color: colors.ink, fontFamily: 'Fraunces')),
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

  Future<void> _promptShareAlbum(
    BuildContext context,
    WidgetRef ref,
    Album album,
    AppColors colors,
    TextTheme typography,
  ) async {
    final controller = TextEditingController();
    String? inlineError;
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              title: Text(
                'Share "${album.title}"',
                style: typography.headlineSmall?.copyWith(color: colors.ink, fontFamily: 'Fraunces'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Google Drive folder is already the album — invite a '
                    'friend’s email and they’ll see it in their Kioku after they '
                    'sign in with Google.',
                    style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'friend@example.com',
                      errorText: inlineError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
                ),
                TextButton(
                  onPressed: () async {
                    final email = controller.text.trim();
                    if (!emailRegex.hasMatch(email)) {
                      setDialogState(() {
                        inlineError = 'Please enter a valid email address';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    try {
                      await ref.read(albumsProvider.notifier).share(album.id, email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Shared "${album.title}" with $email')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to share album: $e'),
                            backgroundColor: colors.danger,
                          ),
                        );
                      }
                    }
                  },
                  child: Text('Share', style: typography.bodyMedium?.copyWith(color: colors.accentDark)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.authState, required this.colors});

  final AuthState authState;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final photoUrl = authState.photoUrl;
    if (photoUrl == null) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: colors.surfaceContainerHigh,
        child: authState.isSignedIn
            ? Text(
                authState.email?.substring(0, 1).toUpperCase() ?? '?',
                style: TextStyle(
                    color: colors.accentDark, fontSize: 20, fontFamily: 'Fraunces'),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset('assets/kiokulogo.jpg', fit: BoxFit.cover),
              ),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: colors.surfaceContainerHigh,
      backgroundImage: NetworkImage(photoUrl),
    );
  }
}