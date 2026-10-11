import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Interactive QR viewfinder with scanning animation and instant simulation mode
class QrViewfinderWidget extends StatefulWidget {
  final VoidCallback onSimulatedScan;
  final String statusText;

  const QrViewfinderWidget({
    super.key,
    required this.onSimulatedScan,
    this.statusText = 'Align QR code inside frame',
  });

  @override
  State<QrViewfinderWidget> createState() => _QrViewfinderWidgetState();
}

class _QrViewfinderWidgetState extends State<QrViewfinderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanLineAnim;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double boxSize = 250;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background camera grid
              Opacity(
                opacity: 0.15,
                child: GridPaper(
                  color: AppTheme.primary,
                  divisions: 2,
                  subdivisions: 2,
                ),
              ),

              // Corner brackets
              const _ViewfinderCorners(boxSize: boxSize),

              // Animated Scanning Line
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
                            color: AppTheme.primary.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Flashlight / Control overlay on top-right
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    _torchOn ? Icons.flash_on : Icons.flash_off,
                    color: _torchOn ? AppTheme.warning : Colors.white70,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _torchOn = !_torchOn;
                    });
                  },
                  tooltip: 'Toggle Flashlight',
                ),
              ),

              // Center Guidance Icon
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 40,
                    color: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.statusText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // One-tap Simulation Button for immediate testing
        ElevatedButton.icon(
          onPressed: widget.onSimulatedScan,
          icon: const Icon(Icons.qr_code, size: 18),
          label: const Text('Simulate Scan Teacher QR Code'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    const double length = 26;
    const double stroke = 3.5;
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
            color: color,
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            width: stroke,
            height: length,
            color: color,
          ),
        ),
        // Top-Right
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: length,
            height: stroke,
            color: color,
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: stroke,
            height: length,
            color: color,
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: length,
            height: stroke,
            color: color,
          ),
        ),
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: stroke,
            height: length,
            color: color,
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: length,
            height: stroke,
            color: color,
          ),
        ),
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: stroke,
            height: length,
            color: color,
          ),
        ),
      ],
    );
  }
}
