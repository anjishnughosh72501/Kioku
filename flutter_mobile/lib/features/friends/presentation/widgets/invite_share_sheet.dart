import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class InviteShareSheet extends ConsumerWidget {
  const InviteShareSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InviteShareSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final myFriendCode = UserProfileService.instance.friendCode;
    final inviteAsync = ref.watch(userInviteProvider);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomPadding = math.max(viewPadding.bottom, AppTheme.spacingLg) + viewInsets.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.divider, width: 1),
          ),
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacingLg,
            AppTheme.spacingMd,
            AppTheme.spacingLg,
            bottomPadding,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_outlined, size: 22, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Friends',
                        style: typography.headlineSmall?.copyWith(
                          color: colors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Share memories privately with end-to-end encryption',
                        style: typography.bodySmall?.copyWith(
                          color: colors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Section 1: Friend Code
            Text(
              'Your Friend Code',
              style: typography.bodySmall?.copyWith(
                color: colors.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend code copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.ink,
                      side: BorderSide(color: colors.divider),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(height: 6),

            inviteAsync.when(
              data: (invite) {
                final shortUrl = invite?.url ?? 'https://kioku.app/i/$myFriendCode';
                final displayShort = shortUrl.replaceFirst('https://', '');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, size: 20, color: colors.accentDark),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Short invite link copied!')),
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

                    // Section 3: QR Code
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
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not generate short link: $err',
                    style: typography.bodySmall?.copyWith(color: colors.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08, end: 0, duration: 250.ms);
  }
}
