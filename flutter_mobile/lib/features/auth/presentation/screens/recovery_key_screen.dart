/// RecoveryKeyScreen — restores vault master keys using 24-word recovery phrase.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/crypto/recovery_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  final List<TextEditingController> _controllers =
      List.generate(24, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(24, (_) => FocusNode());

  bool _isRestoring = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _fullPhrase =>
      _controllers.map((c) => c.text.trim().toLowerCase()).join(' ');

  int get _wordCount =>
      _controllers.where((c) => c.text.trim().isNotEmpty).length;

  void _onPasteFullPhrase() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;

    final words = text.trim().toLowerCase().split(RegExp(r'\s+'));
    for (int i = 0; i < 24; i++) {
      if (i < words.length) {
        _controllers[i].text = words[i];
      } else {
        _controllers[i].clear();
      }
    }
    setState(() {
      _errorMessage = null;
    });
  }

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _restoreVault() async {
    final phrase = _fullPhrase;
    final words = phrase.split(' ').where((w) => w.isNotEmpty).toList();

    if (words.length != 24) {
      setState(() {
        _errorMessage = 'Please enter all 24 words (currently entered: ${words.length}).';
      });
      return;
    }

    if (!RecoveryService.instance.validatePhrase(phrase)) {
      setState(() {
        _errorMessage = 'Invalid recovery phrase. Please verify spelling and word order.';
      });
      return;
    }

    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    try {
      await KeyStore.instance.restoreFromRecoveryPhrase(phrase);
      setState(() {
        _isRestoring = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        context.go('/');
      }
    } on VaultDecryptionException catch (e) {
      setState(() {
        _isRestoring = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isRestoring = false;
        _errorMessage = 'Failed to recover vault: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Vault Recovery',
          style: typography.titleMedium?.copyWith(
            color: colors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isSuccess ? _buildSuccessView(colors, typography) : _buildFormView(colors, typography),
      ),
    );
  }

  Widget _buildSuccessView(AppColors colors, TextTheme typography) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, size: 48, color: colors.primary),
          )
              .animate()
              .scale(duration: 400.ms, curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Vault Restored',
            style: typography.headlineSmall?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Your encrypted memories have been safely unlocked.',
            style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),
        ],
      ),
    );
  }

  Widget _buildFormView(AppColors colors, TextTheme typography) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: colors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'An encrypted vault was detected on this device. Enter your 24-word recovery phrase to restore access.',
                          style: typography.bodySmall?.copyWith(
                            color: colors.ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Words: $_wordCount / 24',
                      style: typography.labelMedium?.copyWith(
                        color: _wordCount == 24 ? colors.primary : colors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _onPasteFullPhrase,
                      icon: const Icon(Icons.paste_rounded, size: 16),
                      label: const Text('Paste Phrase'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: colors.primary,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: colors.inkMuted,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 48,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.inkMuted.withValues(alpha: 0.2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: typography.bodySmall?.copyWith(
                              color: colors.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textInputAction: index < 23 ? TextInputAction.next : TextInputAction.done,
                              style: typography.bodyMedium?.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (_) => setState(() => _errorMessage = null),
                              onSubmitted: (_) {
                                if (index < 23) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 20, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: typography.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().shake(duration: 300.ms),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.background,
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                offset: const Offset(0, -4),
                blurRadius: 10,
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isRestoring ? null : _restoreVault,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isRestoring
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Restore Vault',
                      style: typography.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
