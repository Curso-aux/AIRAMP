import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AvatarPreset {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;
  final List<String> aliases;

  const AvatarPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradientColors,
    this.iconColor = Colors.white,
    this.aliases = const [],
  });
}

const List<AvatarPreset> kAvatarPresets = [
  AvatarPreset(
    id: 'preset:girl_1',
    label: 'Girl',
    icon: Icons.face_3_rounded,
    gradientColors: [Color(0xFF0D9488), Color(0xFF10B981)],
    aliases: ['preset:scholar'],
  ),
  AvatarPreset(
    id: 'preset:boy_1',
    label: 'Boy',
    icon: Icons.face_4_rounded,
    gradientColors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
    aliases: ['preset:coder'],
  ),
  AvatarPreset(
    id: 'preset:bob_cut',
    label: 'Bob Cut',
    icon: Icons.face_2_rounded,
    gradientColors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    aliases: ['preset:creative'],
  ),
  AvatarPreset(
    id: 'preset:glasses',
    label: 'Glasses',
    icon: Icons.face_5_rounded,
    gradientColors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
    aliases: ['preset:science'],
  ),
  AvatarPreset(
    id: 'preset:curly',
    label: 'Curly',
    icon: Icons.face_6_rounded,
    gradientColors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
    aliases: ['preset:explorer'],
  ),
  AvatarPreset(
    id: 'preset:joyful',
    label: 'Joyful',
    icon: Icons.face_rounded,
    gradientColors: [Color(0xFFD97706), Color(0xFFFBBF24)],
    aliases: ['preset:champion'],
  ),
  AvatarPreset(
    id: 'preset:scholar_f',
    label: 'Scholar',
    icon: Icons.person_4_rounded,
    gradientColors: [Color(0xFF059669), Color(0xFF34D399)],
    aliases: ['preset:star'],
  ),
  AvatarPreset(
    id: 'preset:learner_m',
    label: 'Learner',
    icon: Icons.person_3_rounded,
    gradientColors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    aliases: ['preset:math'],
  ),
  AvatarPreset(
    id: 'preset:friendly',
    label: 'Friendly',
    icon: Icons.person_2_rounded,
    gradientColors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
    aliases: ['preset:robot'],
  ),
  AvatarPreset(
    id: 'preset:cheerful',
    label: 'Cheerful',
    icon: Icons.face_retouching_natural_rounded,
    gradientColors: [Color(0xFFC026D3), Color(0xFFE879F9)],
    aliases: ['preset:music'],
  ),
];

/// A unified avatar component that displays:
/// 1. Preset Vector/Gradient Avatars (`preset:...`)
/// 2. Base64 Data URL or raw base64 uploaded photos (`data:image/...`)
/// 3. Remote Network URLs (`http://`, `https://`)
/// 4. Local asset paths (`assets/...`)
/// 5. Graceful fallback letter initial with curated gradient styling
class UserAvatarWidget extends StatelessWidget {
  final String? imageSource;
  final String fallbackInitial;
  final double size;
  final double? fontSize;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatarWidget({
    super.key,
    required this.imageSource,
    required this.fallbackInitial,
    this.size = 40.0,
    this.fontSize,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.5,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cleanSrc = imageSource?.trim() ?? '';
    final initial = fallbackInitial.trim().isNotEmpty
        ? fallbackInitial.trim()[0].toUpperCase()
        : '?';

    Widget content;

    if (cleanSrc.isEmpty) {
      content = _buildInitialFallback(context, initial);
    } else if (cleanSrc.startsWith('preset:')) {
      content = _buildPresetAvatar(cleanSrc, initial, context);
    } else if (cleanSrc.startsWith('data:image') || _isLikelyBase64(cleanSrc)) {
      content = _buildBase64Image(cleanSrc, initial, context);
    } else if (cleanSrc.startsWith('http://') || cleanSrc.startsWith('https://')) {
      content = _buildNetworkImage(cleanSrc, initial, context);
    } else if (cleanSrc.startsWith('assets/')) {
      content = _buildAssetImage(cleanSrc, initial, context);
    } else {
      content = _buildInitialFallback(context, initial);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppTheme.border,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(child: content),
    );
  }

  bool _isLikelyBase64(String src) {
    if (src.length < 50) return false;
    if (src.startsWith('http://') || src.startsWith('https://')) return false;
    if (src.startsWith('assets/')) return false;
    if (src.startsWith('preset:')) return false;
    return true;
  }

  Widget _buildPresetAvatar(String presetId, String initial, BuildContext context) {
    AvatarPreset? match;
    for (final p in kAvatarPresets) {
      if (p.id == presetId || p.aliases.contains(presetId)) {
        match = p;
        break;
      }
    }

    if (match == null) {
      return _buildInitialFallback(context, initial);
    }

    final iconSize = size * 0.54;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: match.gradientColors,
        ),
      ),
      child: Center(
        child: HumanFaceWidget(
          presetId: match.id,
          size: iconSize,
          color: match.iconColor,
        ),
      ),
    );
  }

  Widget _buildBase64Image(String dataUrl, String initial, BuildContext context) {
    try {
      final base64Part = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      final bytes = base64Decode(base64Part.trim());
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialFallback(context, initial),
      );
    } catch (_) {
      return _buildInitialFallback(context, initial);
    }
  }

  Widget _buildNetworkImage(String url, String initial, BuildContext context) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildInitialFallback(context, initial),
    );
  }

  Widget _buildAssetImage(String assetPath, String initial, BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildInitialFallback(context, initial),
    );
  }

  Widget _buildInitialFallback(BuildContext context, String initial) {
    final effectiveFontSize = fontSize ?? (size * 0.44);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppTheme.primary.withValues(alpha: 0.14),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.bold,
            color: textColor ?? AppTheme.text,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// A standalone vector human face widget that renders pure vector graphics
/// directly onto the Canvas, completely independent of external font files
/// or font tree-shaking on Web and Mobile.
class HumanFaceWidget extends StatelessWidget {
  final String presetId;
  final double size;
  final Color color;

  const HumanFaceWidget({
    super.key,
    required this.presetId,
    this.size = 24.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: HumanFacePainter(
          presetId: presetId,
          color: color,
        ),
      ),
    );
  }
}

class HumanFacePainter extends CustomPainter {
  final String presetId;
  final Color color;

  HumanFacePainter({required this.presetId, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.08).clamp(1.4, 2.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.30;

    // Base head oval outline
    final headRect = Rect.fromCircle(center: Offset(cx, cy + size.height * 0.04), radius: r);
    canvas.drawOval(headRect, strokePaint);

    final eyeY = cy + size.height * 0.02;
    final eyeDx = r * 0.44;
    final eyeR = (size.width * 0.04).clamp(1.1, 2.2);

    final smileY = cy + size.height * 0.16;
    final smileRect = Rect.fromCenter(
      center: Offset(cx, smileY),
      width: r * 0.65,
      height: r * 0.40,
    );

    switch (presetId) {
      case 'preset:girl_1':
      case 'preset:scholar':
        // Top Bun & Bangs
        canvas.drawCircle(Offset(cx, cy - r - size.height * 0.06), r * 0.36, strokePaint);
        final bangsPath = Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.2)
          ..quadraticBezierTo(cx, cy - r * 0.65, cx + r * 0.85, cy - r * 0.2);
        canvas.drawPath(bangsPath, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:boy_1':
      case 'preset:coder':
        // Short side-parted hair cap
        final hairPath = Path()
          ..moveTo(cx - r * 0.95, cy - r * 0.1)
          ..quadraticBezierTo(cx - r * 0.4, cy - r * 1.15, cx + r * 0.95, cy - r * 0.45);
        canvas.drawPath(hairPath, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:bob_cut':
      case 'preset:creative':
        // Bob cut framing the face
        final leftBob = Path()
          ..moveTo(cx - r * 0.8, cy - r * 0.5)
          ..quadraticBezierTo(cx - r * 1.25, cy + r * 0.3, cx - r * 0.7, cy + r * 0.9);
        final rightBob = Path()
          ..moveTo(cx + r * 0.8, cy - r * 0.5)
          ..quadraticBezierTo(cx + r * 1.25, cy + r * 0.3, cx + r * 0.7, cy + r * 0.9);
        canvas.drawPath(leftBob, strokePaint);
        canvas.drawPath(rightBob, strokePaint);
        final bobBangs = Path()
          ..moveTo(cx - r * 0.8, cy - r * 0.2)
          ..quadraticBezierTo(cx, cy - r * 0.55, cx + r * 0.8, cy - r * 0.2);
        canvas.drawPath(bobBangs, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:glasses':
      case 'preset:science':
        // Hair parting
        final partHair = Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.3)
          ..quadraticBezierTo(cx - r * 0.2, cy - r * 1.0, cx + r * 0.85, cy - r * 0.3);
        canvas.drawPath(partHair, strokePaint);
        // Glasses frames & bridge
        final glassR = r * 0.28;
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), glassR, strokePaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), glassR, strokePaint);
        canvas.drawLine(Offset(cx - eyeDx + glassR, eyeY), Offset(cx + eyeDx - glassR, eyeY), strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR * 0.8, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR * 0.8, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:curly':
      case 'preset:explorer':
        // Curly hair puffs
        canvas.drawCircle(Offset(cx - r * 0.7, cy - r * 0.7), r * 0.32, strokePaint);
        canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.95), r * 0.35, strokePaint);
        canvas.drawCircle(Offset(cx + r * 0.25, cy - r * 0.95), r * 0.35, strokePaint);
        canvas.drawCircle(Offset(cx + r * 0.7, cy - r * 0.7), r * 0.32, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:joyful':
      case 'preset:champion':
        // Joyful ^ ^ eyes
        final leftEyeJoy = Path()
          ..moveTo(cx - eyeDx - 3, eyeY + 1)
          ..quadraticBezierTo(cx - eyeDx, eyeY - 3, cx - eyeDx + 3, eyeY + 1);
        final rightEyeJoy = Path()
          ..moveTo(cx + eyeDx - 3, eyeY + 1)
          ..quadraticBezierTo(cx + eyeDx, eyeY - 3, cx + eyeDx + 3, eyeY + 1);
        canvas.drawPath(leftEyeJoy, strokePaint);
        canvas.drawPath(rightEyeJoy, strokePaint);
        canvas.drawArc(smileRect, 0, 3.14159, true, fillPaint);
        break;

      case 'preset:scholar_f':
      case 'preset:star':
        // Hair + Student Collar
        final scholarHair = Path()
          ..moveTo(cx - r * 0.9, cy - r * 0.3)
          ..quadraticBezierTo(cx, cy - r * 1.1, cx + r * 0.9, cy - r * 0.3);
        canvas.drawPath(scholarHair, strokePaint);
        final vCollar = Path()
          ..moveTo(cx - r * 0.45, cy + r * 0.85)
          ..lineTo(cx, cy + r * 1.35)
          ..lineTo(cx + r * 0.45, cy + r * 0.85);
        canvas.drawPath(vCollar, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:learner_m':
      case 'preset:math':
        // Boy hair + student collar
        final boyHair = Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.2)
          ..quadraticBezierTo(cx - r * 0.3, cy - r * 1.15, cx + r * 0.85, cy - r * 0.6);
        canvas.drawPath(boyHair, strokePaint);
        final collar = Path()
          ..moveTo(cx - r * 0.4, cy + r * 0.88)
          ..lineTo(cx, cy + r * 1.3)
          ..lineTo(cx + r * 0.4, cy + r * 0.88);
        canvas.drawPath(collar, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:friendly':
      case 'preset:robot':
        // Friendly Hair with playful wink
        final fHair = Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.3)
          ..quadraticBezierTo(cx, cy - r * 1.0, cx + r * 0.85, cy - r * 0.3);
        canvas.drawPath(fHair, strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawLine(Offset(cx + eyeDx - 3, eyeY), Offset(cx + eyeDx + 3, eyeY), strokePaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;

      case 'preset:cheerful':
      case 'preset:music':
      default:
        // Cheerful hair with star sparkle
        final cHair = Path()
          ..moveTo(cx - r * 0.85, cy - r * 0.2)
          ..quadraticBezierTo(cx, cy - r * 1.1, cx + r * 0.85, cy - r * 0.2);
        canvas.drawPath(cHair, strokePaint);
        final starX = cx + r * 0.85;
        final starY = cy - r * 0.7;
        canvas.drawLine(Offset(starX - 3, starY), Offset(starX + 3, starY), strokePaint);
        canvas.drawLine(Offset(starX, starY - 3), Offset(starX, starY + 3), strokePaint);
        canvas.drawCircle(Offset(cx - eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawCircle(Offset(cx + eyeDx, eyeY), eyeR, fillPaint);
        canvas.drawArc(smileRect, 0, 3.14159, false, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant HumanFacePainter oldDelegate) {
    return oldDelegate.presetId != presetId || oldDelegate.color != color;
  }
}
