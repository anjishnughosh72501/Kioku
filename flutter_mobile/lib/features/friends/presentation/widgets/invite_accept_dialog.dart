import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/features/friends/presentation/controllers/friends_controller.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class InviteAcceptDialog extends ConsumerStatefulWidget {
  const InviteAcceptDialog({
    super.key,
    required this.inviteCode,
  });

  final String inviteCode;

  static Future<void> show(BuildContext context, String inviteCode) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => InviteAcceptDialog(inviteCode: inviteCode),
    );
  }

  @override
  ConsumerState<InviteAcceptDialog> createState() => _InviteAcceptDialogState();
}

class _InviteAcceptDialogState extends ConsumerState<InviteAcceptDialog> {
  bool _loading = true;
  bool _submitting = false;
  InviteResolution? _resolution;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await UserProfileService.instance.resolveInvite(widget.inviteCode);
    if (!mounted) return;

    final myCode = UserProfileService.instance.friendCode.trim().toUpperCase();
    if (res.friendCode != null && res.friendCode!.trim().toUpperCase() == myCode) {
      setState(() {
        _loading = false;
        _resolution = res;
        _errorMessage = 'You cannot connect with your own invite link.';
      });
      return;
    }

    final currentFriends = await UserProfileService.instance.getConnectedFriends();
    if (res.friendCode != null && currentFriends.contains(res.friendCode!.trim().toUpperCase())) {
      setState(() {
        _loading = false;
        _resolution = res;
        _errorMessage = 'You and ${res.username ?? 'this user'} are already connected friends!';
      });
      return;
    }

    setState(() {
      _loading = false;
      _resolution = res;
      if (!res.isValid) {
        if (res.isExpired) {
          _errorMessage = 'This invite link has expired. Please request a new invite.';
        } else {
          _errorMessage = 'This invite code is invalid or does not exist.';
        }
      }
    });
  }

  Future<void> _acceptInvite() async {
    final res = _resolution;
    if (res == null) return;

    setState(() => _submitting = true);
    final inviteCode = res.code ?? widget.inviteCode;

    try {
      final confirmRes = await UserProfileService.instance.confirmInvite(inviteCode);
      if (!mounted) return;
      setState(() => _submitting = false);

      Navigator.of(context).pop();

      ref.read(incomingRequestsProvider.notifier).refresh();
      ref.read(sentRequestsProvider.notifier).refresh();
      ref.read(friendsListProvider.notifier).refresh();

      final name = res.username ?? res.friendCode ?? 'your friend';
      if (confirmRes != null && confirmRes['status'] == 'already_friends') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are already friends with $name!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite confirmed with $name! Friend request received.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is FriendException ? e.message : 'Could not confirm invite: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                'Resolving invite...',
                textAlign: TextAlign.center,
                style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
            ] else if (_errorMessage != null) ...[
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info_outline_rounded, size: 28, color: colors.primary),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                'Invite Notice',
                textAlign: TextAlign.center,
                style: typography.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              ClayButton(
                label: 'Close',
                variant: ClayButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else if (_resolution != null) ...[
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      (_resolution!.username?.isNotEmpty == true
                              ? _resolution!.username![0]
                              : '?')
                          .toUpperCase(),
                      style: typography.headlineMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                _resolution!.username ?? 'Kioku Friend',
                textAlign: TextAlign.center,
                style: typography.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Friend Code: ${_resolution!.friendCode ?? widget.inviteCode}',
                textAlign: TextAlign.center,
                style: typography.bodySmall?.copyWith(
                  color: colors.inkMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Wants to connect with you on Kioku to share private, end-to-end encrypted memories.',
                textAlign: TextAlign.center,
                style: typography.bodySmall?.copyWith(
                  color: colors.inkMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                        ),
                      ),
                      child: Text('Decline', style: TextStyle(color: colors.inkMuted)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ClayButton(
                      label: _submitting ? 'Connecting...' : 'Accept Friend',
                      variant: ClayButtonVariant.primary,
                      onPressed: _submitting ? () {} : _acceptInvite,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 200.ms);
  }
}
