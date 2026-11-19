import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum PrescriptionPriority {
  critical,
  warning,
  recommended,
  routine,
}

class PrescriptiveActionCard extends StatefulWidget {
  final String title;
  final String description;
  final String badgeText;
  final IconData icon;
  final PrescriptionPriority priority;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool isDark;

  const PrescriptiveActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.badgeText,
    this.icon = Icons.lightbulb_outline_rounded,
    this.priority = PrescriptionPriority.recommended,
    required this.actionLabel,
    this.onAction,
    required this.isDark,
  });

  @override
  State<PrescriptiveActionCard> createState() => _PrescriptiveActionCardState();
}

class _PrescriptiveActionCardState extends State<PrescriptiveActionCard> {
  bool _isHovered = false;

  Color _getPriorityColor() {
    switch (widget.priority) {
      case PrescriptionPriority.critical:
        return AppTheme.error;
      case PrescriptionPriority.warning:
        return AppTheme.warning;
      case PrescriptionPriority.recommended:
        return widget.isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
      case PrescriptionPriority.routine:
        return widget.isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final surfaceColor = widget.isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = _isHovered
        ? priorityColor.withValues(alpha: 0.6)
        : (widget.isDark ? AppTheme.darkBorder : AppTheme.lightBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: _isHovered ? 1.5 : 1.0),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? priorityColor.withValues(alpha: widget.isDark ? 0.2 : 0.08)
                  : Colors.black.withValues(alpha: widget.isDark ? 0.15 : 0.02),
              blurRadius: _isHovered ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badge + Priority Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 12, color: priorityColor),
                      const SizedBox(width: 4),
                      Text(
                        widget.badgeText.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: priorityColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? AppTheme.darkTextBright : AppTheme.lightTextBright,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            // Description
            Text(
              widget.description,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // Action Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: widget.onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 12),
                label: Text(
                  widget.actionLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: priorityColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
