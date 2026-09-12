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
        // Logo Image Container (blends seamlessly in light & dark mode)
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: AppTheme.isDark ? 0.22 : 0.10),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/aira_logo.png',
            width: size,
            height: size,
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