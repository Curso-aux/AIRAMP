import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Central branding component for AIRA.
///
/// Features:
/// - Exact representation of the official AIRA graduation-cap "a" emblem.
/// - Transparent background: no container or bounding box so it blends seamlessly into headers/navbars.
/// - Dynamic contrast switching:
///   In Light Mode -> Pure BLACK logo glyph (blends seamlessly on light backgrounds).
///   In Dark Mode  -> Pure WHITE logo glyph (blends seamlessly on dark backgrounds).
/// - Full brand display (mark + typography) or compact mark ([AppLogo.mark]) for web headers, app bars, and sidebars.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool showSubtitle;
  final bool showSlogan;
  final bool showBackground;
  final Color? logoColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool? isDark;

  const AppLogo({
    super.key,
    this.size = 120,
    this.showText = true,
    this.showSubtitle = true,
    this.showSlogan = true,
    this.showBackground = false,
    this.logoColor,
    this.backgroundColor,
    this.borderRadius,
    this.isDark,
  });

  /// Compact branded emblem for top navigation bars, headers, and sidebars.
  const AppLogo.mark({
    super.key,
    this.size = 38,
    this.showText = false,
    this.showSubtitle = false,
    this.showSlogan = false,
    this.showBackground = false,
    this.logoColor,
    this.backgroundColor,
    this.borderRadius,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark = isDark ??
        (Theme.of(context).brightness == Brightness.dark || AppTheme.isDark);

    final markWidget = _buildMark(context, effectiveDark);

    if (!showText) {
      return markWidget;
    }

    final textColor = effectiveDark ? AppTheme.darkTextBright : AppTheme.lightText;
    final subtitleColor = effectiveDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final sloganColor = effectiveDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.lightPrimaryDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        markWidget,
        const SizedBox(height: 16),
        // Brand Text
        Text(
          'AIRA',
          style: TextStyle(
            fontSize: (size * 0.28).clamp(20.0, 36.0),
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 4,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            'Academic Integrated Review & Assessment',
            style: TextStyle(
              fontSize: (size * 0.10).clamp(10.0, 13.0),
              fontWeight: FontWeight.w500,
              color: subtitleColor,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (showSlogan) ...[
          const SizedBox(height: 4),
          Text(
            'Train Smart. Get Certified!',
            style: TextStyle(
              fontSize: (size * 0.11).clamp(11.0, 14.0),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: sloganColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildMark(BuildContext context, bool effectiveDark) {
    // In Dark Mode: pure WHITE logo (assets/images/aira_logo.png).
    // In Light Mode: pure BLACK logo (assets/images/aira_logo_dark.png).
    final defaultAsset = effectiveDark
        ? 'assets/images/aira_logo.png'
        : 'assets/images/aira_logo_dark.png';

    final effectiveColor = logoColor ?? (effectiveDark ? Colors.white : Colors.black);
    final markSize = showBackground ? size * 0.76 : size;

    Widget imageWidget = Image.asset(
      defaultAsset,
      width: markSize,
      height: markSize,
      fit: BoxFit.contain,
      color: effectiveColor,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/aira_logo.png',
        width: markSize,
        height: markSize,
        fit: BoxFit.contain,
        color: effectiveColor,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, _, _) => Icon(
          Icons.school_rounded,
          size: markSize * 0.7,
          color: effectiveColor,
        ),
      ),
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: imageWidget),
      );
    }

    final defaultBg = effectiveDark
        ? const Color(0xFF161F2E)
        : const Color(0xFF0F172A);
    final defaultBorder = effectiveDark
        ? AppTheme.darkPrimary.withValues(alpha: 0.35)
        : const Color(0xFF334155);
    final radius = borderRadius ?? BorderRadius.circular(size * 0.24);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: radius,
        border: Border.all(
          color: defaultBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveDark
                ? AppTheme.darkPrimary.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: imageWidget,
    );
  }
}
