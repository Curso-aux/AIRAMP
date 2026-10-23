import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../auth/application/auth_provider.dart';
import '../../data/student_repository.dart';
import 'student_analytics_sheet.dart';
import '../../../notifications/application/notification_provider.dart';
import 'student_announcements_sheet.dart';

/// Unified, institutional Student Sticky Top Header.
/// Pinned at the top of Student screens (Dashboard, Calendar/Timetable, etc.)
///
/// Features:
/// - Left: Interactive student identity (Avatar button with scale animations,
///   formal student name, institutional verified badge, STUDENT role pill, section).
/// - Tapping student identity navigates directly to `/student/profile`.
/// - Right: Quick institutional actions (Saved Offline Materials with live count badge,
///   Announcements & Notifications Bell with unread counter/dot).
class StudentStickyTopHeader extends ConsumerWidget {
  final bool? isCompact;
  final List<Widget>? extraActions;

  const StudentStickyTopHeader({
    super.key,
    this.isCompact,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final allAnnouncements = ref.watch(announcementsProvider);
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = isCompact ?? (screenWidth < 400);

    final displayName = currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Student Learner';
    final sectionStr = currentUser.section?.trim();

    // Filter announcements for this student
    final studentSection = sectionStr?.toLowerCase();
    final studentAnnouncements = allAnnouncements.where((a) {
      final aud = (a['target_audience'] as String? ?? 'all').toLowerCase();
      if (aud != 'all' && aud != 'students') return false;

      final aSec = (a['section'] as String?)?.trim();
      if (aSec == null ||
          aSec.isEmpty ||
          aSec == 'All Sections' ||
          aSec == 'All Handled Sections') {
        return true;
      }
      if (studentSection != null && studentSection.isNotEmpty) {
        return aSec.toLowerCase() == studentSection;
      }
      return false;
    }).toList();

    final progress = ref.watch(studentProgressProvider);
    final completedLessons = (progress['completed'] as num?)?.toInt() ?? 0;
    final pendingLessons = (progress['pending'] as num?)?.toInt() ?? 0;
    final totalLessons = completedLessons + pendingLessons;
    final completionPct = totalLessons > 0 ? ((completedLessons / totalLessons) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: isDark ? 0.6 : 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Interactive Student Identity (Avatar + Formal Name + Institutional Badge)
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.go('/student/profile');
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StudentHeaderAvatarButton(
                      currentUser: currentUser,
                      onTap: () => context.go('/student/profile'),
                      isCompact: compact,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 13.5 : 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'STUDENT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  (sectionStr != null && sectionStr.isNotEmpty) ? sectionStr : 'DepEd SHS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Right: Action Buttons (Analytics, Notifications Bell, extraActions)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?extraActions,
              _buildAnalyticsHeaderButton(
                context,
                completionPct: completionPct,
                isDark: isDark,
                isCompact: compact,
              ),
              const SizedBox(width: 8),
              _buildBellButton(
                context,
                studentAnnouncements,
                unreadNotifs: unreadNotifs,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeaderButton(
    BuildContext context, {
    required int completionPct,
    required bool isDark,
    bool isCompact = false,
  }) {
    final primary = AppTheme.primary;
    final labelText = completionPct > 0
        ? (isCompact ? '$completionPct%' : '$completionPct% Done')
        : (isCompact ? 'Progress' : 'My Progress');

    return Tooltip(
      message: 'View My Progress ($completionPct% Completed)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.lightImpact();
            showStudentAnalyticsSheet(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDark ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primary.withValues(alpha: isDark ? 0.50 : 0.40),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: isDark ? 0.22 : 0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: primary,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  labelText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 3.5),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: primary.withValues(alpha: 0.75),
                  size: 9.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBellButton(
    BuildContext context,
    List<Map<String, dynamic>> announcements, {
    required int unreadNotifs,
    required bool isDark,
  }) {
    final hasUnread = unreadNotifs > 0;
    final hasAnnouncements = announcements.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.border.withValues(alpha: isDark ? 0.7 : 0.9),
              width: 1.0,
            ),
          ),
          child: IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: AppTheme.text, size: 20),
            tooltip: 'Announcements & Notifications',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(7),
            onPressed: () => showStudentAnnouncementsSheet(context, announcements),
          ),
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadNotifs > 9 ? '9+' : '$unreadNotifs',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (hasAnnouncements)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Interactive student avatar with hover, pressed feedback, and profile navigation.
class _StudentHeaderAvatarButton extends StatefulWidget {
  final User currentUser;
  final VoidCallback onTap;
  final bool isCompact;

  const _StudentHeaderAvatarButton({
    required this.currentUser,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  State<_StudentHeaderAvatarButton> createState() => _StudentHeaderAvatarButtonState();
}

class _StudentHeaderAvatarButtonState extends State<_StudentHeaderAvatarButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.currentUser.profileImage != null &&
        widget.currentUser.profileImage!.isNotEmpty;
    final initial = widget.currentUser.fullName.isNotEmpty
        ? widget.currentUser.fullName[0].toUpperCase()
        : 'S';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = widget.isCompact ? 36.0 : 40.0;

    return Tooltip(
      message: 'Student Profile & Settings',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.94 : (_isHovered ? 1.04 : 1.0),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasImage
                    ? Image.network(
                        widget.currentUser.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackInitial(initial),
                      )
                    : _buildFallbackInitial(initial),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Container(
      color: AppTheme.primary,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
