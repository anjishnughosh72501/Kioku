import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class UsernameDialog extends StatefulWidget {
  const UsernameDialog({super.key, this.isDismissible = false});

  final bool isDismissible;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (!UserProfileService.instance.hasUsername) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const UsernameDialog(isDismissible: false),
      );
    }
  }

  static Future<void> showEdit(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const UsernameDialog(isDismissible: true),
    );
  }

  @override
  State<UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<UsernameDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final current = UserProfileService.instance.username;
    if (current != 'Storyteller') {
      _controller.text = current;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter a username or nickname');
      return;
    }
    if (text.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters');
      return;
    }

    setState(() => _submitting = true);
    final profile = await UserProfileService.instance.setUsername(text);
    if (!mounted) return;

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome, ${profile.username}! Your code is ${profile.friendCode}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final friendCode = UserProfileService.instance.friendCode;

    return PopScope(
      canPop: widget.isDismissible,
      child: Dialog(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.coffee_rounded, size: 30, color: colors.primary),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                'Welcome to Kioku',
                textAlign: TextAlign.center,
                style: typography.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a username so friends recognize your shared memories & albums.',
                textAlign: TextAlign.center,
                style: typography.bodySmall?.copyWith(
                  color: colors.inkMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Username / Nickname',
                  hintText: 'e.g. Maya or CoffeeLovers',
                  errorText: _error,
                  prefixIcon: Icon(Icons.badge_outlined, color: colors.primary),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 22, color: colors.inkMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Kioku Friend Code',
                            style: typography.bodySmall?.copyWith(
                              fontSize: 10,
                              color: colors.inkMuted,
                            ),
                          ),
                          Text(
                            friendCode,
                            style: typography.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Row(
                children: [
                  if (widget.isDismissible) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: ClayButton(
                      label: _submitting ? 'Saving...' : 'Get Started',
                      variant: ClayButtonVariant.primary,
                      onPressed: _submitting ? () {} : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
