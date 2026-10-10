import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A glowing circular progress ring that draws around AIRA's avatar as the user holds down.
class AiraHoldRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Widget child;

  const AiraHoldRing({
    super.key,
    required this.progress,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glow track when holding
          if (progress > 0.01)
            CustomPaint(
              size: Size(size, size),
              painter: _AiraHoldRingPainter(progress: progress),
            ),
          child,
        ],
      ),
    );
  }
}

class _AiraHoldRingPainter extends CustomPainter {
  final double progress;

  _AiraHoldRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3.5;
    const strokeWidth = 3.5;

    // 1. Subtle background track
    final trackPaint = Paint()
      ..color = const Color(0x3300BFA5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Glowing outer blur for neon effect
    final glowPaint = Paint()
      ..color = const Color(0x8800E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Radial/Sweep Gradient for the active arc
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        Color(0xFF00BFA5), // Teal
        Color(0xFF00E5FF), // Cyan neon
        Color(0xFFA7FFEB), // Mint highlight
      ],
      stops: const [0.0, 0.7, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw glow and main arc
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    // 3. Glowing head tip dot
    if (progress > 0.05) {
      final tipAngle = startAngle + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      final tipCenter = Offset(tipX, tipY);

      final tipGlow = Paint()
        ..color = const Color(0xFF00E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      final tipWhite = Paint()..color = Colors.white;

      canvas.drawCircle(tipCenter, 3.5, tipGlow);
      canvas.drawCircle(tipCenter, 2.0, tipWhite);
    }
  }

  @override
  bool shouldRepaint(covariant _AiraHoldRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
