import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/core/services/app_lock_service.dart';

/// Wraps the root app widget and presents an AppLockScreen overlay whenever locked.
class AppLockGate extends StatelessWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLockService.instance.isLockedNotifier,
      builder: (context, isLocked, _) {
        return Stack(
          children: [
            child,
            if (isLocked)
              const Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: AppLockScreen(),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// PIN keypad lock screen shown on app resume.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const Color _terracotta = Color(0xFFC76C4D);

  String _pin = '';
  bool _hasError = false;
  bool _isChecking = false;

  void _onDigit(String digit) {
    if (_pin.length >= 6 || _isChecking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _pin += digit;
    });

    if (_pin.length >= 4) {
      _checkPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _isChecking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _checkPin() async {
    setState(() => _isChecking = true);
    final success = await AppLockService.instance.verifyPin(_pin);
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (success) {
      HapticFeedback.mediumImpact();
    } else if (_pin.length == 6 || _pin.length == 4) {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _pin = '';
      });
    }
  }

  void _showRecoveryDialog() {
    final phraseController = TextEditingController();
    final newPinController = TextEditingController();
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bg = isDark ? const Color(0xFF1E2522) : const Color(0xFFFBF8F2);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Recover with Recovery Phrase',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your 24-word backup mnemonic phrase to reset your PIN.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phraseController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter 24 recovery words separated by spaces...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter new 4 to 6-digit PIN',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _terracotta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final phrase = phraseController.text.trim();
                        final newPin = newPinController.text.trim();
                        if (newPin.length < 4) {
                          setModalState(() {
                            errorMsg = 'PIN must be at least 4 digits.';
                          });
                          return;
                        }

                        final ok = await AppLockService.instance.resetWithRecoveryPhrase(
                          phrase: phrase,
                          newPin: newPin,
                        );

                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx);
                        } else {
                          setModalState(() {
                            errorMsg = 'Invalid 24-word recovery phrase. Please check your backup.';
                          });
                        }
                      },
                      child: const Text('Reset PIN & Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141916) : const Color(0xFFF6F3EE);
    final fg = isDark ? Colors.white : const Color(0xFF2C241E);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.lock_rounded,
              size: 48,
              color: _terracotta,
            ),
            const SizedBox(height: 16),
            Text(
              'Kioku 記憶',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: fg,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasError ? 'Incorrect PIN. Try again.' : 'Enter PIN to unlock',
              style: TextStyle(
                fontSize: 14,
                color: _hasError ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black54),
                fontWeight: _hasError ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 24),
            // Pin indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (_hasError ? Colors.redAccent : _terracotta)
                        : (isDark ? Colors.white24 : Colors.black12),
                  ),
                );
              }),
            ),
            const Spacer(),
            // Numeric Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (var row = 0; row < 3; row++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var col = 1; col <= 3; col++)
                            _buildKey((row * 3 + col).toString(), fg, isDark),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 72),
                        _buildKey('0', fg, isDark),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: IconButton(
                            icon: Icon(Icons.backspace_outlined, color: fg),
                            onPressed: _onBackspace,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _showRecoveryDialog,
              child: Text(
                'Forgot PIN? Recover with Phrase',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String digit, Color fg, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onDigit(digit),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
