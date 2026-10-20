import 'package:flutter/material.dart';

/// Institutional Design System tokens for the Super Admin Governance Portal.
/// Designed for high-trust academic & educational governance with flawless
/// light and dark mode contrast harmony.
class GovernanceTheme {
  final bool isDark;

  const GovernanceTheme(this.isDark);

  // Background canvases
  Color get canvas => isDark ? const Color(0xFF0B111D) : const Color(0xFFF8FAFC);
  Color get surface => isDark ? const Color(0xFF131B2A) : const Color(0xFFFFFFFF);
  Color get surfaceSubtle => isDark ? const Color(0xFF1A2436) : const Color(0xFFF1F5F9);
  Color get surfaceElevated => isDark ? const Color(0xFF1E2A3E) : const Color(0xFFFFFFFF);

  // Borders
  Color get border => isDark ? const Color(0xFF233247) : const Color(0xFFE2E8F0);
  Color get borderSubtle => isDark ? const Color(0xFF1A2638) : const Color(0xFFEEF2F6);
  Color get borderFocus => isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8);

  // Typography
  Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get textMuted => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Institutional Primary (Academic Navy / Slate Blue)
  Color get primary => isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8);
  Color get primaryDark => isDark ? const Color(0xFF1E40AF) : const Color(0xFF1E3A8A);
  Color get primarySubtle => isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.28) : const Color(0xFFEFF6FF);
  Color get primaryBorder => isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : const Color(0xFFBFDBFE);

  // Secondary Accent (Refined Steel Slate)
  Color get accent => isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);

  // Semantic Status: Operational / Active
  Color get successText => isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
  Color get successBg => isDark ? const Color(0xFF14532D).withValues(alpha: 0.32) : const Color(0xFFF0FDF4);
  Color get successBorder => isDark ? const Color(0xFF166534).withValues(alpha: 0.45) : const Color(0xFFBBF7D0);

  // Semantic Status: Pending / Warning
  Color get warningText => isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  Color get warningBg => isDark ? const Color(0xFF78350F).withValues(alpha: 0.32) : const Color(0xFFFFFBEB);
  Color get warningBorder => isDark ? const Color(0xFF92400E).withValues(alpha: 0.45) : const Color(0xFFFDE68A);

  // Semantic Status: Restricted / Inactive / Danger
  Color get dangerText => isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
  Color get dangerBg => isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.32) : const Color(0xFFFEF2F2);
  Color get dangerBorder => isDark ? const Color(0xFF991B1B).withValues(alpha: 0.45) : const Color(0xFFFECACA);

  // Input background
  Color get inputBg => isDark ? const Color(0xFF162030) : const Color(0xFFFFFFFF);
}
