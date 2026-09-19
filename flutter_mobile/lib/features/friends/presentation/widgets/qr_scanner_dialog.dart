import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({
    super.key,
    required this.onScanned,
  });

  final ValueChanged<String> onScanned;

  static Future<void> show(BuildContext context, {required ValueChanged<String> onScanned}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => QrScannerDialog(onScanned: onScanned),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;
  bool _torchOn = false;
  final _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _submitManual() {
    final text = _manualInputController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      widget.onScanned(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.divider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: colors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Scan Kioku Code',
                      style: typography.headlineSmall?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: colors.inkMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Scanner Viewfinder
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    // Corner targeting brackets
                    CustomPaint(
                      size: const Size(250, 250),
                      painter: _ViewfinderCornersPainter(color: colors.primary),
                    ),

                    // Laser scan animation
                    AnimatedBuilder(
                      animation: _scanLineAnimation,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment(0, (_scanLineAnimation.value * 2) - 1),
                          child: Container(
                            height: 2.5,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1.5,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Center camera hint
                    Center(
                      child: Icon(
                        Icons.qr_code_rounded,
                        size: 96,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Point camera at friend’s QR invite',
              style: typography.bodySmall?.copyWith(
                color: colors.inkMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            // Manual Code Input field fallback
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                border: Border.all(color: colors.divider, width: 0.8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualInputController,
                      style: typography.bodyMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter code manually...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => _submitManual(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_rounded, color: colors.primary, size: 20),
                    onPressed: _submitManual,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Flashlight button toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, size: 20),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _torchOn = !_torchOn);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;

  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const cornerRadius = 12.0;
    const margin = 20.0;

    // Top-left
    final pathTL = Path()
      ..moveTo(margin, margin + cornerLength)
      ..lineTo(margin, margin + cornerRadius)
      ..quadraticBezierTo(margin, margin, margin + cornerRadius, margin)
      ..lineTo(margin + cornerLength, margin);
    canvas.drawPath(pathTL, paint);

    // Top-right
    final pathTR = Path()
      ..moveTo(size.width - margin - cornerLength, margin)
      ..lineTo(size.width - margin - cornerRadius, margin)
      ..quadraticBezierTo(size.width - margin, margin, size.width - margin, margin + cornerRadius)
      ..lineTo(size.width - margin, margin + cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-left
    final pathBL = Path()
      ..moveTo(margin, size.height - margin - cornerLength)
      ..lineTo(margin, size.height - margin - cornerRadius)
      ..quadraticBezierTo(margin, size.height - margin, margin + cornerRadius, size.height - margin)
      ..lineTo(margin + cornerLength, size.height - margin);
    canvas.drawPath(pathBL, paint);

    // Bottom-right
    final pathBR = Path()
      ..moveTo(size.width - margin - cornerLength, size.height - margin)
      ..lineTo(size.width - margin - cornerRadius, size.height - margin)
      ..quadraticBezierTo(size.width - margin, size.height - margin, size.width - margin, size.height - margin - cornerRadius)
      ..lineTo(size.width - margin, size.height - margin - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
