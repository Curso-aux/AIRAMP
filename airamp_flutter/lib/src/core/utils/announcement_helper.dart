import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized helper for announcement priority labeling, normalization, and color mapping.
class AnnouncementPriorityHelper {
  const AnnouncementPriorityHelper._();

  /// Returns user-facing uppercase label: 'STANDARD', 'IMPORTANT', or 'URGENT'.
  static String formatUpper(String? priority) {
    final p = (priority ?? '').toLowerCase().trim();
    if (p == 'high' || p == 'urgent') return 'URGENT';
    if (p == 'medium' || p == 'important') return 'IMPORTANT';
    return 'STANDARD';
  }

  /// Returns user-facing title case label: 'Standard', 'Important', or 'Urgent'.
  static String formatTitle(String? priority) {
    final p = (priority ?? '').toLowerCase().trim();
    if (p == 'high' || p == 'urgent') return 'Urgent';
    if (p == 'medium' || p == 'important') return 'Important';
    return 'Standard';
  }

  /// Returns the corresponding semantic color.
  static Color getColor(String? priority) {
    final p = (priority ?? '').toLowerCase().trim();
    if (p == 'high' || p == 'urgent') return AppTheme.error;
    if (p == 'medium' || p == 'important') return AppTheme.warning;
    return AppTheme.primary;
  }

  /// Normalizes incoming priority string to canonical storage key ('normal', 'medium', 'high').
  static String normalize(String? priority) {
    final p = (priority ?? '').toLowerCase().trim();
    if (p == 'high' || p == 'urgent') return 'high';
    if (p == 'medium' || p == 'important') return 'medium';
    return 'normal';
  }
}

