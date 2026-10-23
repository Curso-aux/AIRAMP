import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';

/// Real-time live camera QR viewfinder for scanning the classroom QR code.
class QrViewfinderWidget extends StatefulWidget {
  final ValueChanged<String> onScanned;
  final String statusText;

  const QrViewfinderWidget({
    super.key,
    required this.onScanned,
    this.statusText = 'Align QR code inside frame',
  });

  @override
  State<QrViewfinderWidget> createState() => _QrViewfinderWidgetState();
}

class _QrViewfinderWidgetState extends State<QrViewfinderWidget>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  late Animation<double> _scanLineAnim;
  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.10, end: 0.90).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _hasScanned = true;
        HapticFeedback.mediumImpact();
        widget.onScanned(code.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = (screenWidth - 64.0).clamp(260.0, 300.0);
    final isDark = AppTheme.isDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderLight : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Live Camera Stream
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcodeDetect,
                  errorBuilder: (context, error) {
                    return Container(
                      color: const Color(0xFF0F172A),
                      padding: const EdgeInsets.all(22),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.videocam_off_outlined, color: AppTheme.warning, size: 30),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Camera Access Needed',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please grant camera permission in your phone settings to scan classroom QR codes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5, height: 1.3),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Corner brackets
                _ViewfinderCorners(boxSize: boxSize),

                // Animated Laser Scanning Line
                AnimatedBuilder(
                  animation: _scanLineAnim,
                  builder: (context, _) {
                    return Positioned(
                      top: boxSize * _scanLineAnim.value,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.0),
                              AppTheme.primary,
                              AppTheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.65),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Flashlight toggle button (top right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _torchOn
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _torchOn
                                ? const Color(0xFFF59E0B)
                                : Colors.white24,
                            width: 1.0,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                            color: _torchOn ? const Color(0xFFF59E0B) : Colors.white70,
                            size: 19,
                          ),
                          onPressed: () async {
                            await _scannerController.toggleTorch();
                            if (mounted) {
                              setState(() {
                                _torchOn = !_torchOn;
                              });
                            }
                          },
                          tooltip: _torchOn ? 'Turn off Flashlight' : 'Turn on Flashlight',
                        ),
                      ),
                    ),
                  ),
                ),

                // Switch Camera toggle button (top left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white24,
                            width: 1.0,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 19),
                          onPressed: () async {
                            await _scannerController.switchCamera();
                          },
                          tooltip: 'Switch Camera',
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Status Capsule
                Positioned(
                  bottom: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewfinderCorners extends StatelessWidget {
  final double boxSize;

  const _ViewfinderCorners({required this.boxSize});

  @override
  Widget build(BuildContext context) {
    const double length = 30;
    const double stroke = 3.5;
    final color = AppTheme.primary;

    return Stack(
      children: [
        // Top-Left
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        // Top-Right
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    );
  }
}
