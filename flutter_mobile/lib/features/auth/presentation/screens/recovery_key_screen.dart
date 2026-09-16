import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/crypto/recovery_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class RecoveryKeyScreen extends StatefulWidget {
  final String? recoveryPhrase;
  final VoidCallback? onConfirmed;
  final bool isModal;

  const RecoveryKeyScreen({
    super.key,
    this.recoveryPhrase,
    this.onConfirmed,
    this.isModal = false,
  });

  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  String? _phrase;
  bool _isLoading = true;
  bool _confirmedSaved = false;
  bool _copied = false;
  Timer? _clipboardTimer;

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.recoveryPhrase != null && widget.recoveryPhrase!.isNotEmpty) {
      _phrase = widget.recoveryPhrase;
      _isLoading = false;
    } else {
      _loadPhrase();
    }
  }

  Future<void> _loadPhrase() async {
    try {
      final p = await KeyStore.instance.getRecoveryPhrase();
      if (mounted) {
        setState(() {
          _phrase = p;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = context.kiokuTypography;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          title: Text('Recovery Key', style: typography.heading.copyWith(color: colors.ink)),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    final words = (_phrase ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: widget.isModal
            ? IconButton(
                icon: Icon(Icons.close, color: colors.ink),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: colors.ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Recovery Key',
          style: typography.heading.copyWith(color: colors.ink),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Japanese tactile header badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: colors.primary),
                      const Gap(6),
                      Text(
                        'ZERO-KNOWLEDGE ENCRYPTION',
                        style: typography.label.copyWith(color: colors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(16),

              Text(
                'Your Master Secret Phrase',
                style: typography.heading.copyWith(color: colors.ink),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              Text(
                'These 24 words are the only key to your albums. Write them down in a secure place. No one, not even Kioku, can restore your photos if you lose them.',
                style: typography.body.copyWith(color: colors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const Gap(24),

              // 24 Words Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.dividerLight),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: typography.bodySmall.copyWith(
                              color: colors.inkSubtle,
                              fontSize: 10,
                            ),
                          ),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              words[index],
                              style: typography.bodyBold.copyWith(
                                color: colors.ink,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Gap(16),

              // Copy button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final textToCopy = _phrase ?? '';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  setState(() => _copied = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Recovery phrase copied! Clipboard will clear in 60s.'),
                      backgroundColor: colors.primaryDark,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _clipboardTimer?.cancel();
                  _clipboardTimer = Timer(const Duration(seconds: 60), () async {
                    try {
                      final current = await Clipboard.getData(Clipboard.kTextPlain);
                      if (current?.text == textToCopy) {
                        await Clipboard.setData(const ClipboardData(text: ''));
                      }
                    } catch (_) {}
                  });
                },
                icon: Icon(_copied ? Icons.check : Icons.copy_rounded, size: 18),
                label: Text(
                  _copied ? 'Copied to Clipboard' : 'Copy All 24 Words',
                  style: typography.button.copyWith(color: colors.primary),
                ),
              ),
              const Gap(12),

              // Verify recovery key button
              TextButton.icon(
                onPressed: () => _verifyKeyDialog(context),
                icon: Icon(Icons.verified_outlined, size: 18, color: colors.accentDark),
                label: Text(
                  'Verify Recovery Key',
                  style: typography.button.copyWith(color: colors.accentDark),
                ),
              ),
              const Gap(16),

              // Checkbox confirmation
              InkWell(
                onTap: () => setState(() => _confirmedSaved = !_confirmedSaved),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _confirmedSaved,
                        onChanged: (val) => setState(() => _confirmedSaved = val ?? false),
                        activeColor: colors.primary,
                      ),
                      Expanded(
                        child: Text(
                          'I have written down or saved my 24-word recovery key in a safe place.',
                          style: typography.bodyMedium.copyWith(color: colors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(24),

              // Continue Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.ink,
                  disabledBackgroundColor: colors.divider,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: _confirmedSaved ? 3 : 0,
                ),
                onPressed: _confirmedSaved
                    ? () {
                        if (widget.onConfirmed != null) {
                          widget.onConfirmed!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                child: Text(
                  widget.onConfirmed != null ? 'Continue to Kioku' : 'Done',
                  style: typography.button.copyWith(
                    color: _confirmedSaved ? Colors.white : colors.inkSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  void _verifyKeyDialog(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = context.kiokuTypography;
    final controller = TextEditingController();
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Verify Recovery Key',
            style: typography.heading.copyWith(color: colors.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter or paste your 24 words below to confirm they match your active vault key.',
                style: typography.body.copyWith(color: colors.inkMuted),
              ),
              const Gap(16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'word1 word2 word3 ...',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.inkMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final input = controller.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                final current = (_phrase ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                if (input.isEmpty) {
                  setDialogState(() => errorText = 'Please enter your recovery phrase');
                  return;
                }
                if (!RecoveryService.instance.validatePhrase(input)) {
                  setDialogState(() => errorText = 'Invalid BIP39 mnemonic (must be 24 valid words)');
                  return;
                }
                if (input == current) {
                  Navigator.of(dialogCtx).pop();
                  setState(() => _confirmedSaved = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Recovery key verified! Master key confirmed.'),
                      backgroundColor: colors.primaryDark,
                    ),
                  );
                } else {
                  setDialogState(() => errorText = 'Words do not match your current key');
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
