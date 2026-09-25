import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/shared/design_system/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class InviteShareSheet extends ConsumerStatefulWidget {
  const InviteShareSheet({super.key});

  /// Opens the Invite Friends modal bottom sheet on the root navigator.
  static Future<void> show(BuildContext context) {
    return showKiokuBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const InviteShareSheet(),
    );
  }

  @override
  ConsumerState<InviteShareSheet> createState() => _InviteShareSheetState();
}

class _InviteShareSheetState extends ConsumerState<InviteShareSheet> {
  @override
  void initState() {
    super.initState();
    // Schedule invite generation outside of the widget build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final legacy = ref.read(userInviteProvider).valueOrNull;
      if (legacy != null && !legacy.isExpired) return;
      ref.read(inviteControllerProvider.notifier).ensureInviteGenerated();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final myFriendCode = UserProfileService.instance.friendCode;

    // Observe dedicated invite controller
    final inviteState = ref.watch(inviteControllerProvider);
    // Backward compatibility with callers/tests providing userInviteProvider
    final legacyInviteAsync = ref.watch(userInviteProvider);
    final legacyInvite = legacyInviteAsync.valueOrNull;
    final hasLegacyData = legacyInvite != null && !legacyInvite.isExpired;

    final activeInvite = hasLegacyData ? legacyInvite : inviteState.invite;
    final isReady =
        (hasLegacyData || inviteState.isReady) &&
        activeInvite != null &&
        !activeInvite.isExpired;
    final isExpired =
        !hasLegacyData &&
        (inviteState.isExpired ||
            (activeInvite != null && activeInvite.isExpired));
    final isGenerating =
        !hasLegacyData &&
        (inviteState.isGenerating ||
            (inviteState.isIdle && legacyInviteAsync.isLoading));
    final isError =
        !hasLegacyData &&
        (inviteState.isError ||
            (legacyInviteAsync.hasError && activeInvite == null));

    return KiokuBottomSheet(
      title: const Text('Invite Friends'),
      subtitle: const Text(
        'Share memories privately with end-to-end encryption',
      ),
      headerLeading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person_add_outlined, size: 22, color: colors.primary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Friend Code (Always available immediately)
          Text(
            'Your Friend Code',
            style: typography.bodySmall?.copyWith(
              color: colors.inkMuted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    myFriendCode,
                    style: typography.titleMedium?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: myFriendCode));
                    showKiokuSnackBar(
                      context,
                      'Friend code copied',
                      icon: Icons.copy_rounded,
                      aboveBottomNav: false,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.ink,
                    side: BorderSide(color: colors.divider),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingLg),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: AppTheme.spacingLg),

          // Section 2: Universal Short Link
          Text(
            'Share Invite Link',
            style: typography.bodySmall?.copyWith(
              color: colors.inkMuted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Invite Loading State
          if (isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating secure invite...',
                    style: typography.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          // Invite Error State (Never shows raw stack traces or internal framework errors)
          else if (isError)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Couldn't generate an invite link.",
                          style: typography.bodyMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check your connection and try again. Your Friend Code remains usable above.',
                    style: typography.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClayButton(
                      label: 'Retry',
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      variant: ClayButtonVariant.primary,
                      size: ClayButtonSize.small,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(inviteControllerProvider.notifier).retry();
                      },
                    ),
                  ),
                ],
              ),
            )
          // Invite Expired State
          else if (isExpired)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_off_outlined,
                        size: 20,
                        color: colors.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Invite link has expired.',
                          style: typography.bodyMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClayButton(
                      label: 'Generate New Link',
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      variant: ClayButtonVariant.primary,
                      size: ClayButtonSize.small,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(inviteControllerProvider.notifier).retry();
                      },
                    ),
                  ),
                ],
              ),
            )
          // Invite Ready / Success State
          else if (isReady) ...[
            Builder(
              builder: (context) {
                final shortUrl = activeInvite.url.isNotEmpty
                    ? activeInvite.url
                    : 'https://kioku.app/i/${activeInvite.code}';
                final displayShort = shortUrl.replaceFirst('https://', '');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 20,
                            color: colors.accentDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayShort,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.bodyMedium?.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClayButton(
                            label: 'Copy Link',
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            variant: ClayButtonVariant.secondary,
                            size: ClayButtonSize.small,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: shortUrl));
                              showKiokuSnackBar(
                                context,
                                'Invite link copied',
                                icon: Icons.link_rounded,
                                aboveBottomNav: false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClayButton(
                            label: 'Share',
                            icon: const Icon(Icons.share_outlined, size: 16),
                            variant: ClayButtonVariant.primary,
                            size: ClayButtonSize.small,
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Share.share(
                                'Connect with me on Kioku to share private end-to-end encrypted memories: $shortUrl',
                                subject: 'Join me on Kioku',
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingLg),
                    Divider(color: colors.divider, height: 1),
                    const SizedBox(height: AppTheme.spacingLg),

                    // Section 3: QR Code (Data comes directly from created invite)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Scan QR Code',
                            style: typography.bodySmall?.copyWith(
                              color: colors.inkMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: colors.divider),
                            ),
                            child: QrImageView(
                              data: shortUrl,
                              version: QrVersions.auto,
                              size: 160.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF2C2623),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF2C2623),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan to connect instantly with Kioku',
                            style: typography.bodySmall?.copyWith(
                              color: colors.inkMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else
            // Idle initial state before generation triggers
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ClayButton(
                  label: 'Generate Invite Link',
                  icon: const Icon(Icons.link_rounded, size: 16),
                  size: ClayButtonSize.small,
                  onPressed: () {
                    ref
                        .read(inviteControllerProvider.notifier)
                        .ensureInviteGenerated();
                  },
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms);
  }
}
