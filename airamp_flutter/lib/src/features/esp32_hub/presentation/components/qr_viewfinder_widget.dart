import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';

/// Real-time live camera QR viewfinder for scanning the physical ESP32 OLED or classroom QR code.
class QrViewfinderWidget extends StatefulWidget {
  final ValueChanged<String> onScanned;
  final String statusText;

  const QrViewfinderWidget({
    super.key,
    required this.onScanned,
    this.statusText = 'Align ESP32 QR code inside frame',
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

    _scanLineAnim = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
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
    const double boxSize = 270;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
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
                      color: Colors.black,
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppTheme.warning, size: 36),
                          const SizedBox(height: 10),
                          const Text(
                            'Camera access required',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please grant camera permission in your phone settings to scan the ESP32 QR.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Corner brackets
                const _ViewfinderCorners(boxSize: boxSize),

                // Animated Laser Scanning Line
                AnimatedBuilder(
                  animation: _scanLineAnim,
                  builder: (context, _) {
                    return Positioned(
                      top: boxSize * _scanLineAnim.value,
                      left: 24,
                      right: 24,
                      child: Container(
                        height: 3,
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
                              color: AppTheme.primary.withValues(alpha: 0.9),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Flashlight toggle button (top right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: _torchOn ? AppTheme.warning : Colors.white70,
                        size: 20,
                      ),
                      onPressed: () async {
                        await _scannerController.toggleTorch();
                        if (mounted) {
                          setState(() {
                            _torchOn = !_torchOn;
                          });
                        }
                      },
                      tooltip: 'Toggle Flashlight',
                    ),
                  ),
                ),

                // Switch Camera toggle button (top left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_android, color: Colors.white70, size: 20),
                      onPressed: () async {
                        await _scannerController.switchCamera();
                      },
                      tooltip: 'Switch Camera',
                    ),
                  ),
                ),

                // Bottom Status Pill
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
    const double length = 28;
    const double stroke = 4.0;
    final color = AppTheme.primary;

    return Stack(
      children: [
        // Top-Left
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Top-Right
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}
