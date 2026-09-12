import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({
    super.key,
    this.size = 120,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeState = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Image Container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: themeState.colorScheme.surface,
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.glowPrimary,
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.all(size * 0.08),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.18),
            child: Image.asset(
              'assets/images/aira_logo.png',
              width: size * 0.84,
              height: size * 0.84,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if image fails to load
                return Icon(
                  Icons.school,
                  size: size * 0.5,
                  color: themeState.colorScheme.primary,
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),

          // Brand Text
          Text(
            'AIRA',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: themeState.colorScheme.onSurface,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Academic Integrated Review & Assessment',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeState.colorScheme.secondary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Train Smart. Get Certified!',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: themeState.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}