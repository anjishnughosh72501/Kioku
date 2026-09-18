/// ProfileScreen — signed-in Google account, album manager (create / share /
/// members), and sign out. Storage is the user's own Google Drive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/services.dart';
import 'package:flutter_mobile/features/auth/presentation/widgets/username_dialog.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mobile/core/config.dart';
import 'package:flutter_mobile/core/services/invite_service.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/services/app_lock_service.dart';
import 'package:flutter_mobile/core/services/error_reporter.dart';
import 'package:flutter_mobile/features/profile/presentation/widgets/album_row.dart';
import 'package:flutter_mobile/main.dart';
import 'package:flutter_mobile/shared/widgets/create_album_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showDriveInfo = false;
  bool _showEncryptionInfo = false;
  bool _showStorageInfo = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final albums = albumsAsync.value ?? <Album>[];
    final userProfile = ref.watch(userProfileProvider);

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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '設定',
                        style: typography.headlineSmall?.copyWith(
                          fontSize: 18,
                          color: colors.sage,
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
                              color: colors.success.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(color: colors.success.withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_done_outlined,
                                    size: 13, color: colors.success),
                                const SizedBox(width: 4),
                                Text(
                                  'Drive Connected',
                                  style: typography.bodySmall?.copyWith(
                                    color: colors.success,
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
                              color: colors.amber.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(color: colors.amber.withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Text(
                              'Local Only',
                              style: typography.bodySmall?.copyWith(
                                color: colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            _showDriveInfo ? Icons.info : Icons.info_outline,
                            size: 16,
                            color: colors.primary,
                          ),
                          tooltip: 'Storage info',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _showDriveInfo = !_showDriveInfo),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppTheme.spacingMd),
                          Divider(color: colors.divider),
                          const SizedBox(height: AppTheme.spacingSm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                      crossFadeState: _showDriveInfo ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 240),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Zero-Knowledge Encryption & Recovery Key card
              ClayCard(
                variant: ClayVariant.elevated,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Zero-Knowledge Encryption',
                          style: typography.bodyMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(color: colors.success.withValues(alpha: 0.3), width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Active',
                                style: typography.bodySmall?.copyWith(
                                  color: colors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            _showEncryptionInfo ? Icons.info : Icons.info_outline,
                            size: 16,
                            color: colors.primary,
                          ),
                          tooltip: 'Encryption details',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _showEncryptionInfo = !_showEncryptionInfo),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _showEncryptionInfo = !_showEncryptionInfo),
                        icon: Icon(
                          _showEncryptionInfo ? Icons.expand_less : Icons.help_outline,
                          size: 15,
                          color: colors.inkMuted,
                        ),
                        label: Text(
                          _showEncryptionInfo ? 'Hide Details' : 'Encryption Info',
                          style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacingMd),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingSm),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.divider),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: colors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'All photos, videos, and metadata are sealed on this device with XChaCha20-Poly1305 and X25519 before being synced. Storage providers only ever see opaque ciphertext.',
                                  style: typography.bodySmall?.copyWith(
                                    color: colors.inkMuted,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      crossFadeState: _showEncryptionInfo ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 240),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Storage Provider (BYOS) card
              ClayCard(
                variant: ClayVariant.elevated,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Storage Backend',
                          style: typography.bodyMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            border: Border.all(color: colors.amber.withValues(alpha: 0.3), width: 0.5),
                          ),
                          child: Text(
                            ref.watch(activeStorageTypeProvider).name.toUpperCase(),
                            style: typography.bodySmall?.copyWith(
                              color: colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            _showStorageInfo ? Icons.info : Icons.info_outline,
                            size: 16,
                            color: colors.primary,
                          ),
                          tooltip: 'Storage info',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _showStorageInfo = !_showStorageInfo),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/storage-setup'),
                            icon: Icon(Icons.tune_outlined, size: 16, color: colors.ink),
                            label: Text(
                              'Configure Storage',
                              style: typography.bodySmall?.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showStorageInfo = !_showStorageInfo),
                          icon: Icon(
                            _showStorageInfo ? Icons.expand_less : Icons.help_outline,
                            size: 15,
                            color: colors.inkMuted,
                          ),
                          label: Text(
                            _showStorageInfo ? 'Hide' : 'Info',
                            style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.divider),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacingMd),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingSm),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.divider),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.cloud_sync_outlined, size: 14, color: colors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bring your own storage: switch between Local Device, Google Drive, S3 (AWS/R2/B2/MinIO), WebDAV (Nextcloud), or P2P Mesh.',
                                  style: typography.bodySmall?.copyWith(
                                    color: colors.inkMuted,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      crossFadeState: _showStorageInfo ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 240),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 180.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

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
                            ref.invalidate(userProfileProvider);
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
                              userProfile.username,
                              style: typography.headlineSmall?.copyWith(
                                fontSize: 18,
                                color: colors.ink,
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
                                    userProfile.friendCode,
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
                                        ClipboardData(text: userProfile.friendCode),
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
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      final link = 'https://kioku.app/invite?friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';
                                      final appUri = 'kioku://invite?friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}';
                                      Share.share(
                                        'Add me on Kioku!\n'
                                        'Friend code: ${userProfile.friendCode}\n\n'
                                        'Tap to connect:\n$link\n\n'
                                        'Or app link: $appUri',
                                        subject: 'Kioku Friend Invite',
                                      );
                                    },
                                    child: Icon(Icons.share_rounded, size: 16, color: colors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Friends & Circle Section
              _buildFriendsCard(context, ref, colors, typography, albums),

              const SizedBox(height: AppTheme.spacingLg),

              // App Lock & Privacy Gate (P1-8 & P2-10)
              _buildAppLockCard(context, colors, typography),

              const SizedBox(height: AppTheme.spacingLg),

              // Appearance & Motion Card
              ClayCard(
                variant: ClayVariant.elevated,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Appearance & Motion',
                          style: typography.bodyMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'Theme Palette',
                      style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final currentMode = ref.watch(themeModeProvider);
                        final notifier = ref.read(themeModeProvider.notifier);

                        Widget buildThemeChip(String label, ThemeMode mode, IconData icon) {
                          final isSelected = currentMode == mode;
                          return Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setThemeMode(mode);
                              },
                              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.15)
                                      : colors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                                  border: Border.all(
                                    color: isSelected ? colors.primary : colors.divider,
                                    width: isSelected ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      icon,
                                      size: 18,
                                      color: isSelected ? colors.primary : colors.inkMuted,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: typography.bodySmall?.copyWith(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? colors.primary : colors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Row(
                          children: [
                            buildThemeChip('System', ThemeMode.system, Icons.brightness_auto_outlined),
                            const SizedBox(width: 8),
                            buildThemeChip('Dark', ThemeMode.dark, Icons.dark_mode_outlined),
                            const SizedBox(width: 8),
                            buildThemeChip('Light', ThemeMode.light, Icons.light_mode_outlined),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 110.ms, duration: 300.ms),

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
                          onPressed: () async {
                            final name = await CreateAlbumDialog.show(context);
                            if (name != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Album "$name" created')),
                              );
                            }
                          },
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
                  onPressed: () async {
                    if (authState.isSignedIn) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: colors.surfaceContainer,
                          title: Text(
                            'Sign out?',
                            style: typography.headlineSmall?.copyWith(
                              color: colors.ink,
                            ),
                          ),
                          content: Text(
                            'Your memories will remain safely stored in your Google Drive. You can sign back in anytime to access them.',
                            style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                'Sign Out',
                                style: typography.bodyMedium?.copyWith(
                                  color: colors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        ref.read(authControllerProvider.notifier).signOut();
                      }
                    } else {
                      ref.read(authControllerProvider.notifier).signIn();
                    }
                  },
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

              const SizedBox(height: AppTheme.spacingLg),

              // Legal & Privacy Policy
              _buildLegalCard(context, colors, typography),

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



  Widget _buildLegalCard(
    BuildContext context,
    AppColors colors,
    TextTheme typography,
  ) {
    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'View Privacy Policy',
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(Icons.privacy_tip_outlined, size: 20, color: colors.primary),
              title: Text(
                'Privacy Policy',
                style: typography.bodyMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Zero-knowledge, client-side encryption policy',
                style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.inkMuted),
              onTap: () => _showPrivacyPolicyModal(context, colors, typography),
            ),
          ),
          Divider(color: colors.divider, height: 1),
          Semantics(
            button: true,
            label: 'View Terms of Service',
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(Icons.gavel_outlined, size: 20, color: colors.primary),
              title: Text(
                'Terms of Service',
                style: typography.bodyMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Personal data ownership & service conditions',
                style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
              ),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.inkMuted),
              onTap: () => _showTermsModal(context, colors, typography),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 300.ms);
  }

  void _showPrivacyPolicyModal(
    BuildContext context,
    AppColors colors,
    TextTheme typography,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusModal)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Privacy Policy',
                    style: typography.headlineSmall?.copyWith(color: colors.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                'Kioku Privacy & Zero-Knowledge Guarantee\n\n'
                '1. Data Ownership\n'
                'All your photos, videos, and memories are stored exclusively in your own Google Drive storage (or local device storage). Kioku does not maintain a central media server, cloud database of your photos, or data-mining pipeline.\n\n'
                '2. End-to-End Encryption\n'
                'All media content is encrypted on your device using libsodium XChaCha20-Poly1305 before upload. Your master key and recovery phrases never leave your hardware secure storage.\n\n'
                '3. No Tracking or Third-Party Ads\n'
                'Kioku does not sell your personal data, track your location, or include advertising SDKs.\n\n'
                'For online reference, visit:\n${AppConfig.appPrivacyUrl}',
                style: typography.bodyMedium?.copyWith(color: colors.ink, height: 1.5),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Policy URL'),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: AppConfig.appPrivacyUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy Policy URL copied')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsModal(
    BuildContext context,
    AppColors colors,
    TextTheme typography,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusModal)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms of Service',
                    style: typography.headlineSmall?.copyWith(color: colors.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                'Kioku Terms of Service\n\n'
                '1. Acceptance\n'
                'By using Kioku, you agree to these terms governing peer-to-peer and personal-drive memory sharing.\n\n'
                '2. User Responsibility & Key Custody\n'
                'Because Kioku utilizes zero-knowledge encryption, you are the sole custodian of your cryptographic keys and recovery phrase. If you lose your recovery phrase and device access, Kioku cannot recover your encrypted memories.\n\n'
                '3. Acceptable Use\n'
                'You agree not to use Kioku to distribute harmful, infringing, or unlawful material.\n\n'
                'For online reference, visit:\n${AppConfig.appTermsUrl}',
                style: typography.bodyMedium?.copyWith(color: colors.ink, height: 1.5),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Terms URL'),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: AppConfig.appTermsUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms of Service URL copied')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _buildInviteUrl(Album album) async {
    final userProfile = ref.read(userProfileProvider);
    String claimParams = '';
    try {
      final claim = await InviteService.instance.createInviteClaim(albumId: album.id);
      if (claim != null) {
        if (claim.claimToken.isNotEmpty) {
          claimParams += '&claim=${Uri.encodeComponent(claim.claimToken)}';
        }
        if (claim.inviterPubKey.isNotEmpty) {
          claimParams += '&pubKey=${Uri.encodeComponent(claim.inviterPubKey)}';
        }
      }
    } catch (_) {}

    return 'https://kioku.app/invite?albumId=${album.id}&albumName=${Uri.encodeComponent(album.title)}&friendCode=${Uri.encodeComponent(userProfile.friendCode)}&from=${Uri.encodeComponent(userProfile.username)}$claimParams';
  }

  Future<void> _shareInviteLink(Album album) async {
    final link = await _buildInviteUrl(album);
    final appUri = link.replaceFirst('https://kioku.app/', 'kioku://');

    Share.share(
      'Join my memory album "${album.title}" on Kioku!\n\n'
      'Tap to open and join:\n$link\n\n'
      'Or app link: $appUri',
      subject: 'Kioku Memory Album: ${album.title}',
    );
  }

  Future<void> _promptShareAlbum(
    BuildContext context,
    WidgetRef ref,
    Album album,
    AppColors colors,
    TextTheme typography,
  ) async {
    final friends = ref.read(connectedFriendsProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
          title: Row(
            children: [
              Icon(Icons.share_outlined, size: 22, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Share "${album.title}"',
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
                    'Tap a friend to send an invite directly:',
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
                            final sent = await UserProfileService.instance.sendAlbumInvite(
                              albumId: album.id,
                              albumName: album.title,
                              toFriendCode: code,
                            );
                            if (context.mounted) {
                              if (sent) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Album invite sent directly to $code!')),
                                );
                              } else {
                                final link = await _buildInviteUrl(album);
                                final appUri = link.replaceFirst('https://kioku.app/', 'kioku://');
                                Share.share(
                                  'Hey $code! Join my memory album "${album.title}" on Kioku!\n\n'
                                  'Tap to open and join:\n$link\n\n'
                                  'Or app link: $appUri',
                                  subject: 'Kioku Memory Album: ${album.title}',
                                );
                              }
                            }
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
                            'Add friends using their Friend Code, or share an album link below to connect automatically!',
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
                  'Friends who open this link will automatically connect and join this album.',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          final link = await _buildInviteUrl(album);
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
                          _shareInviteLink(album);
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

  Widget _buildFriendsCard(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    TextTheme typography,
    List<Album> albums,
  ) {
    final connectedFriends = ref.watch(connectedFriendsProvider);
    final incomingRequestsAsync = ref.watch(incomingFriendRequestsProvider);
    final incomingRequests = incomingRequestsAsync.value ?? [];
    final incomingAlbumInvitesAsync = ref.watch(incomingAlbumInvitesProvider);
    final incomingAlbumInvites = incomingAlbumInvitesAsync.value ?? [];

    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Friends (${connectedFriends.length})',
                style: typography.bodyMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Add Friend by code',
                child: OutlinedButton.icon(
                  onPressed: () => _promptAddFriendCode(context, ref, colors, typography),
                  icon: Icon(Icons.person_add_outlined, size: 15, color: colors.primary),
                  label: Text(
                    'Add Friend',
                    style: typography.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Connect with friends via their Kioku code to share memories and collaborate on albums.',
            style: typography.bodySmall?.copyWith(
              fontSize: 11,
              color: colors.inkMuted,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Incoming requests section
          if (incomingRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mark_email_unread_outlined, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Incoming Friend Requests (${incomingRequests.length})',
                        style: typography.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: incomingRequests.length,
                    separatorBuilder: (_, _) => Divider(color: colors.divider, height: 12),
                    itemBuilder: (context, index) {
                      final req = incomingRequests[index];
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.person, size: 16, color: colors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.fromName?.isNotEmpty == true
                                      ? req.fromName!
                                      : req.fromCode,
                                  style: typography.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.ink,
                                  ),
                                ),
                                if (req.fromName?.isNotEmpty == true)
                                  Text(
                                    req.fromCode,
                                    style: typography.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: colors.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(incomingFriendRequestsProvider.notifier)
                                  .decline(req);
                            },
                            child: Text(
                              'Decline',
                              style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              ),
                            ),
                            onPressed: () async {
                              final success = await ref
                                  .read(incomingFriendRequestsProvider.notifier)
                                  .accept(req);
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Connected with ${req.fromCode}')),
                                );
                              }
                            },
                            child: Text(
                              'Accept',
                              style: typography.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],

          // Incoming album invites section
          if (incomingAlbumInvites.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_shared_outlined, size: 18, color: colors.accentDark),
                      const SizedBox(width: 8),
                      Text(
                        'Album Invites (${incomingAlbumInvites.length})',
                        style: typography.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.accentDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: incomingAlbumInvites.length,
                    separatorBuilder: (_, _) => Divider(color: colors.divider, height: 12),
                    itemBuilder: (context, index) {
                      final invite = incomingAlbumInvites[index];
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.accent.withValues(alpha: 0.15),
                            child: Icon(Icons.photo_album_rounded, size: 16, color: colors.accentDark),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite.albumName,
                                  style: typography.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.ink,
                                  ),
                                ),
                                Text(
                                  'From ${invite.fromName ?? invite.fromCode}',
                                  style: typography.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: colors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(incomingAlbumInvitesProvider.notifier)
                                  .decline(invite);
                            },
                            child: Text(
                              'Decline',
                              style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accentDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              ),
                            ),
                            onPressed: () async {
                              final success = await ref
                                  .read(incomingAlbumInvitesProvider.notifier)
                                  .accept(invite);
                              if (success) {
                                await ref.read(albumsProvider.notifier).refresh();
                                await ref.read(activeAlbumProvider.notifier).set(invite.albumId);
                                await ref.read(memoriesProvider.notifier).refresh();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Joined "${invite.albumName}"!')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Join',
                              style: typography.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],

          if (connectedFriends.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd, horizontal: AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_search_outlined, size: 28, color: colors.inkMuted.withValues(alpha: 0.6)),
                    const SizedBox(height: 6),
                    Text(
                      'No friends added yet',
                      style: typography.bodySmall?.copyWith(
                        color: colors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap "Add Friend" above to send a request with your friend\'s code.',
                      textAlign: TextAlign.center,
                      style: typography.bodySmall?.copyWith(
                        fontSize: 10,
                        color: colors.inkMuted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: connectedFriends.length,
              separatorBuilder: (context, index) => Divider(color: colors.divider, height: 1),
              itemBuilder: (context, index) {
                final code = connectedFriends[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Icon(Icons.person_rounded, size: 20, color: colors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code,
                              style: typography.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: colors.ink,
                              ),
                            ),
                            Text(
                              'Connected Friend',
                              style: typography.bodySmall?.copyWith(
                                fontSize: 10,
                                color: colors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Invite $code to Album',
                        child: IconButton(
                          tooltip: 'Invite to Album',
                          icon: Icon(Icons.folder_shared_outlined, size: 18, color: colors.accentDark),
                          onPressed: () => _promptInviteFriendToAlbum(context, ref, colors, typography, code, albums),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Remove $code from friends',
                        child: IconButton(
                          tooltip: 'Remove Friend',
                          icon: Icon(Icons.close_rounded, size: 16, color: colors.inkMuted),
                          onPressed: () async {
                            await ref.read(connectedFriendsProvider.notifier).removeFriend(code);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Removed $code from friends')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ).animate().fadeIn(delay: 110.ms, duration: 300.ms);
  }

  Future<void> _promptAddFriendCode(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    TextTheme typography,
  ) async {
    final controller = TextEditingController();
    String? inlineError;
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              title: Text(
                'Send Friend Request',
                style: typography.headlineSmall?.copyWith(color: colors.ink, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your friend\'s Kioku code (e.g. KIOKU-XXXX). They will receive your request and can accept it.',
                    style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'KIOKU-XXXX',
                      errorText: inlineError,
                      prefixIcon: Icon(Icons.tag_rounded, color: colors.primary),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: typography.bodyMedium?.copyWith(color: colors.inkMuted)),
                ),
                ClayButton(
                  label: isSending ? 'Sending…' : 'Send Request',
                  size: ClayButtonSize.small,
                  onPressed: isSending
                      ? null
                      : () async {
                          final code = controller.text.trim().toUpperCase();
                          if (code.isEmpty) {
                            setDialogState(() => inlineError = 'Please enter a code');
                            return;
                          }
                          if (code == ref.read(userProfileProvider).friendCode) {
                            setDialogState(() => inlineError = 'That is your own code');
                            return;
                          }
                          setDialogState(() => isSending = true);
                          final result = await ref
                              .read(connectedFriendsProvider.notifier)
                              .sendFriendRequest(code);
                          setDialogState(() => isSending = false);

                          switch (result) {
                            case FriendRequestResult.sent:
                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Friend request sent to $code!'),
                                  ),
                                );
                              }
                              break;
                            case FriendRequestResult.alreadySent:
                              setDialogState(() => inlineError = 'Request already sent to this code');
                              break;
                            case FriendRequestResult.alreadyFriends:
                              setDialogState(() => inlineError = 'You are already friends');
                              break;
                            case FriendRequestResult.sameUser:
                              setDialogState(() => inlineError = 'That is your own code');
                              break;
                            case FriendRequestResult.error:
                              setDialogState(() => inlineError = 'Could not send request. Please try again.');
                              break;
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

  Future<void> _promptInviteFriendToAlbum(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    TextTheme typography,
    String friendCode,
    List<Album> albums,
  ) async {
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an album first before inviting friends')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusModal)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_shared_outlined, size: 20, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Invite $friendCode to Album',
                      style: typography.bodyMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select an album to share with your friend:',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: albums.length,
                    separatorBuilder: (context, index) => Divider(color: colors.divider, height: 1),
                    itemBuilder: (context, idx) {
                      final album = albums[idx];
                      return ListTile(
                        leading: Icon(Icons.photo_album_outlined, color: colors.primary),
                        title: Text(album.title, style: typography.bodyMedium?.copyWith(color: colors.ink)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colors.inkMuted),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _promptShareAlbum(context, ref, album, colors, typography);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppLockCard(
    BuildContext context,
    AppColors colors,
    TextTheme typography,
  ) {
    final lockService = AppLockService.instance;
    final isEnabled = lockService.isEnabled;

    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'App Lock & Privacy Gate',
                style: typography.bodyMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.divider.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: isEnabled ? colors.primary.withValues(alpha: 0.3) : colors.divider,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  isEnabled ? 'PROTECTED' : 'DISABLED',
                  style: typography.bodySmall?.copyWith(
                    color: isEnabled ? colors.primary : colors.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Re-locks the decrypted photo gallery and prompts for a PIN or recovery phrase whenever Kioku returns from the background.',
            style: typography.bodySmall?.copyWith(
              color: colors.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleAppLock(context, colors, typography),
                  icon: Icon(
                    isEnabled ? Icons.lock_open : Icons.lock,
                    size: 16,
                    color: colors.ink,
                  ),
                  label: Text(
                    isEnabled ? 'Manage App Lock' : 'Enable App Lock',
                    style: typography.bodySmall?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (isEnabled) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    lockService.lock();
                  },
                  tooltip: 'Lock immediately',
                  icon: Icon(Icons.screen_lock_portrait_outlined, size: 18, color: colors.primary),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showErrorLogsModal(context, colors, typography),
              icon: Icon(Icons.bug_report_outlined, size: 14, color: colors.inkMuted),
              label: Text(
                'View Privacy-Scrubbed Logs',
                style: typography.bodySmall?.copyWith(
                  color: colors.inkMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 115.ms, duration: 300.ms);
  }

  void _toggleAppLock(BuildContext context, AppColors colors, TextTheme typography) {
    final lockService = AppLockService.instance;
    if (!lockService.isEnabled) {
      _showSetPinDialog(context, colors, typography);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manage App Lock',
                style: typography.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.key_outlined, color: colors.primary),
                title: const Text('Change PIN'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetPinDialog(context, colors, typography);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_open_outlined, color: Colors.redAccent),
                title: const Text('Disable App Lock', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDisablePinDialog(context, colors, typography);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showSetPinDialog(BuildContext context, AppColors colors, TextTheme typography) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Set 4 to 6-digit PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Enter PIN'),
              ),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final p1 = pinController.text.trim();
                final p2 = confirmController.text.trim();
                if (p1.length < 4) {
                  setDialogState(() => error = 'PIN must be 4 to 6 digits');
                  return;
                }
                if (p1 != p2) {
                  setDialogState(() => error = 'PINs do not match');
                  return;
                }
                await AppLockService.instance.setPin(p1);
                if (mounted) setState(() {});
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisablePinDialog(BuildContext context, AppColors colors, TextTheme typography) {
    final pinController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm PIN to Disable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await AppLockService.instance.disableLock(pinController.text.trim());
                if (ok) {
                  if (mounted) setState(() {});
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                } else {
                  setDialogState(() => error = 'Incorrect PIN');
                }
              },
              child: const Text('Disable'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorLogsModal(BuildContext context, AppColors colors, TextTheme typography) {
    final logs = ErrorReporter.instance.logs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(sheetCtx).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(sheetCtx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Privacy-Scrubbed Error Logs',
                  style: typography.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            Text(
              'Zero analytics or tracking. All paths, keys, and identifiers are scrubbed locally.',
              style: typography.bodySmall?.copyWith(color: colors.inkMuted),
            ),
            const Divider(height: 24),
            Expanded(
              child: logs.isEmpty
                  ? const Center(child: Text('No errors recorded. Kioku is running cleanly!'))
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (ctx, i) {
                        final entry = logs[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.timestamp.toIso8601String().substring(11, 19),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  entry.message,
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: logs.isEmpty
                        ? null
                        : () {
                            final allText = logs.map((l) => '${l.timestamp.toIso8601String()}: ${l.message}').join('\n');
                            Clipboard.setData(ClipboardData(text: allText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Scrubbed logs copied to clipboard')),
                            );
                          },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy All'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () {
                    ErrorReporter.instance.clearLogs();
                    Navigator.pop(sheetCtx);
                  },
                  tooltip: 'Clear logs',
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
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
                    color: colors.accentDark, fontSize: 20, fontWeight: FontWeight.bold),
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