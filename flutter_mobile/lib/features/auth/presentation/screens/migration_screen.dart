import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_mobile/core/crypto/key_store.dart';
import 'package:flutter_mobile/core/crypto/migration_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class MigrationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const MigrationScreen({super.key, required this.onComplete});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  MigrationProgress? _progress;

  @override
  void initState() {
    super.initState();
    _checkAndInit();
  }

  Future<void> _checkAndInit() async {
    await KeyStore.instance.initialize();
    _startMigration();
  }

  void _startMigration() {
    MigrationService.instance.migrate().listen(
      (progress) {
        if (mounted) {
          setState(() => _progress = progress);
          if (progress.progress >= 1.0) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) widget.onComplete();
            });
          }
        }
      },
      onError: (err) {
        // Migration error handled gracefully
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = context.kiokuTypography;

    // 2. Migration progress screen
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated lock/shield icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.glassBorder, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.enhanced_encryption_rounded,
                    size: 56,
                    color: colors.primary,
                  ),
                ),
                const Gap(32),

                Text(
                  'Upgrading to End-to-End Encryption',
                  style: typography.heading.copyWith(color: colors.ink),
                  textAlign: TextAlign.center,
                ),
                const Gap(12),
                Text(
                  _progress?.status ?? 'Preparing your encrypted albums...',
                  style: typography.body.copyWith(color: colors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const Gap(36),

                // Progress indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress?.progress,
                    backgroundColor: colors.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    minHeight: 8,
                  ),
                ),
                const Gap(16),

                if (_progress != null && _progress!.totalFiles > 0)
                  Text(
                    '${_progress!.processedFiles} of ${_progress!.totalFiles} photos encrypted',
                    style: typography.caption.copyWith(color: colors.inkSubtle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
