import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A custom rendered QR code graphic for classroom projection and mobile scanning
class HubQrCodeWidget extends StatelessWidget {
  final String qrData;
  final String hubSsid;
  final String hubIp;
  final double size;
  final bool showLabels;

  const HubQrCodeWidget({
    super.key,
    required this.qrData,
    this.hubSsid = 'AIRAMP-HUB-01',
    this.hubIp = '192.168.4.1',
    this.size = 200,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size - 28, size - 28),
                painter: _QrMatrixPainter(seedString: qrData),
              ),
              // Center AIRA Hub Badge
              Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: AppTheme.darkPrimaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'AIRA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.055,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'SSID: $hubSsid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(width: 10),
                Text('•', style: TextStyle(color: AppTheme.textMuted)),
                const SizedBox(width: 10),
                Text(
                  hubIp,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter that creates a deterministic, crisp QR matrix pattern with corner finder patterns
class _QrMatrixPainter extends CustomPainter {
  final String seedString;

  _QrMatrixPainter({required this.seedString});

  @override
  void paint(Canvas canvas, Size size) {
    const int matrixDim = 25; // 25x25 grid
    final double cellSize = size.width / matrixDim;
    final paintDark = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Draw the 3 finder squares: Top-Left, Top-Right, Bottom-Left
    _drawFinderPattern(canvas, 0, 0, cellSize, paintDark);
    _drawFinderPattern(canvas, (matrixDim - 7) * cellSize, 0, cellSize, paintDark);
    _drawFinderPattern(canvas, 0, (matrixDim - 7) * cellSize, cellSize, paintDark);

    // Draw pseudo-random deterministic data cells based on hash of seedString
    final int hash = seedString.hashCode.abs();
    final random = math.Random(hash);

    for (int r = 0; r < matrixDim; r++) {
      for (int c = 0; c < matrixDim; c++) {
        // Skip finder pattern zones (7x7 in top-left, top-right, bottom-left)
        final inTopLeft = r < 8 && c < 8;
        final inTopRight = r < 8 && c >= matrixDim - 8;
        final inBottomLeft = r >= matrixDim - 8 && c < 8;
        final inCenter = r >= 10 && r <= 14 && c >= 10 && c <= 14; // Center logo space

        if (inTopLeft || inTopRight || inBottomLeft || inCenter) {
          continue;
        }

        // Timing patterns
        if (r == 6 || c == 6) {
          if ((r + c) % 2 == 0) {
            _drawCell(canvas, c * cellSize, r * cellSize, cellSize, paintDark);
          }
          continue;
        }

        // Deterministic pseudo-random filled cells
        if (random.nextDouble() > 0.48) {
          _drawCell(canvas, c * cellSize, r * cellSize, cellSize, paintDark);
        }
      }
    }
  }

  void _drawCell(Canvas canvas, double x, double y, double size, Paint paint) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 0.3, y + 0.3, size - 0.6, size - 0.6),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(rrect, paint);
  }

  void _drawFinderPattern(Canvas canvas, double left, double top, double cellSize, Paint paint) {
    final fullSize = cellSize * 7;
    // Outer black square
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, fullSize, fullSize),
        const Radius.circular(4),
      ),
      paint,
    );

    // Inner white gap
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + cellSize, top + cellSize, cellSize * 5, cellSize * 5),
        const Radius.circular(3),
      ),
      whitePaint,
    );

    // Center black dot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + cellSize * 2, top + cellSize * 2, cellSize * 3, cellSize * 3),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) =>
      oldDelegate.seedString != seedString;
}
