import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AvatarPreset {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;

  const AvatarPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradientColors,
    this.iconColor = Colors.white,
  });
}

const List<AvatarPreset> kAvatarPresets = [
  AvatarPreset(
    id: 'preset:scholar',
    label: 'Scholar',
    icon: Icons.school_rounded,
    gradientColors: [Color(0xFF0D9488), Color(0xFF10B981)],
  ),
  AvatarPreset(
    id: 'preset:coder',
    label: 'Coder',
    icon: Icons.terminal_rounded,
    gradientColors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
  ),
  AvatarPreset(
    id: 'preset:science',
    label: 'Scientist',
    icon: Icons.biotech_rounded,
    gradientColors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
  ),
  AvatarPreset(
    id: 'preset:explorer',
    label: 'Explorer',
    icon: Icons.rocket_launch_rounded,
    gradientColors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
  ),
  AvatarPreset(
    id: 'preset:creative',
    label: 'Artist',
    icon: Icons.palette_rounded,
    gradientColors: [Color(0xFFDB2777), Color(0xFFF43F5E)],
  ),
  AvatarPreset(
    id: 'preset:champion',
    label: 'Champion',
    icon: Icons.emoji_events_rounded,
    gradientColors: [Color(0xFFD97706), Color(0xFFFBBF24)],
  ),
  AvatarPreset(
    id: 'preset:math',
    label: 'Mathematician',
    icon: Icons.calculate_rounded,
    gradientColors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
  ),
  AvatarPreset(
    id: 'preset:star',
    label: 'Achiever',
    icon: Icons.auto_awesome_rounded,
    gradientColors: [Color(0xFF059669), Color(0xFF34D399)],
  ),
  AvatarPreset(
    id: 'preset:robot',
    label: 'AI Bot',
    icon: Icons.smart_toy_rounded,
    gradientColors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
  ),
  AvatarPreset(
    id: 'preset:music',
    label: 'Music',
    icon: Icons.music_note_rounded,
    gradientColors: [Color(0xFFC026D3), Color(0xFFE879F9)],
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
    return src.length > 100 && !src.contains('/') && !src.contains(':');
  }

  Widget _buildPresetAvatar(String presetId, String initial, BuildContext context) {
    AvatarPreset? match;
    for (final p in kAvatarPresets) {
      if (p.id == presetId) {
        match = p;
        break;
      }
    }

    if (match == null) {
      return _buildInitialFallback(context, initial);
    }

    final iconSize = size * 0.52;

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
        child: Icon(
          match.icon,
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
