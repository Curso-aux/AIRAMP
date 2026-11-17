import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/aira_qr_scanner_dialog.dart';
import '../../../../core/components/app_toast.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/components/user_avatar_widget.dart';
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
  final bool showQrScanner;

  const StudentStickyTopHeader({
    super.key,
    this.isCompact,
    this.extraActions,
    this.showQrScanner = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final allAnnouncements = ref.watch(announcementsProvider);
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = isCompact ?? (screenWidth < 420);

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
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 4 : 6,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
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
                  children: [
                    _StudentHeaderAvatarButton(
                      currentUser: currentUser,
                      onTap: () => context.go('/student/profile'),
                      isCompact: compact,
                    ),
                    SizedBox(width: compact ? 8 : 12),
                    Expanded(
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
                                    fontSize: compact ? 13.0 : 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                size: compact ? 12 : 14,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'STUDENT',
                                  style: TextStyle(
                                    fontSize: compact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (sectionStr != null && sectionStr.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    sectionStr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: compact ? 10.0 : 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
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

          // Right: Action Buttons (Analytics, Notifications Bell, extraActions, optional QR)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?extraActions,
              if (showQrScanner) ...[
                _buildQrScanButton(
                  context,
                  ref,
                  isDark: isDark,
                  isCompact: compact,
                ),
                SizedBox(width: compact ? 6 : 8),
              ],
              _buildAnalyticsHeaderButton(
                context,
                completionPct: completionPct,
                isDark: isDark,
                isCompact: compact,
              ),
              SizedBox(width: compact ? 6 : 8),
              _buildBellButton(
                context,
                studentAnnouncements,
                unreadNotifs: unreadNotifs,
                isDark: isDark,
                isCompact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrScanButton(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    bool isCompact = false,
  }) {
    final primary = AppTheme.primary;
    return Tooltip(
      message: 'Scan Section QR Code',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.lightImpact();
            AiraQrScannerDialog.show(
              context: context,
              title: 'Scan Section Enrollment QR',
              subtitle: 'Point camera at classroom projector display',
              onKeyScanned: (scannedKey) async {
                try {
                  final verified = await ref.read(studentCoursesProvider.notifier).verifyKey(scannedKey);
                  if (verified != null && context.mounted) {
                    _showDirectEnrollConfirmSheet(context, ref, verified, scannedKey);
                  } else if (context.mounted) {
                    AppToast.showWarning(
                      context,
                      'Invalid Key "$scannedKey". Please check with your teacher.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppToast.showError(context, 'Verification error: $e');
                  }
                }
              },
            );
          },
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 18,
              color: primary,
            ),
          ),
        ),
      ),
    );
  }

  void _showDirectEnrollConfirmSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> verifiedData,
    String key,
  ) {
    final sec = (verifiedData['section'] as Map<String, dynamic>?) ?? {};
    final subjects = (verifiedData['subjects'] as List?) ?? [];
    final sectionName = sec['name']?.toString() ?? 'Section';
    final grade = sec['grade']?.toString() ?? '';
    final room = sec['room']?.toString() ?? 'Main Building';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified Section QR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                        Text(
                          sectionName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room_outlined, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      '$grade · Room $room · ${subjects.length} Subjects',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        try {
                          final success = await ref
                              .read(studentCoursesProvider.notifier)
                              .enrollBySectionKey(key);
                          if (success && context.mounted) {
                            ref.read(studentCoursesProvider.notifier).reload();
                            AppToast.showSuccess(
                              context,
                              'Enrolled in $sectionName successfully! Loaded ${subjects.length} subjects.',
                            );
                          } else if (context.mounted) {
                            AppToast.showError(context, 'Enrollment failed. Please try again.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppToast.showError(context, 'Error enrolling: $e');
                          }
                        }
                      },
                      icon: const Icon(Icons.school_rounded, size: 18),
                      label: const Text('Confirm & Enroll', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
            height: isCompact ? 32 : 36,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10),
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
                  size: isCompact ? 13 : 15,
                ),
                SizedBox(width: isCompact ? 3.5 : 5),
                Text(
                  labelText,
                  style: TextStyle(
                    fontSize: isCompact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(width: isCompact ? 2.5 : 3.5),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: primary.withValues(alpha: 0.75),
                  size: isCompact ? 8.5 : 9.5,
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
    bool isCompact = false,
  }) {
    final hasUnread = unreadNotifs > 0;
    final hasAnnouncements = announcements.isNotEmpty;
    final buttonSize = isCompact ? 32.0 : 36.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.border.withValues(alpha: isDark ? 0.7 : 0.9),
              width: 1.0,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.text,
              size: isCompact ? 17 : 20,
            ),
            tooltip: 'Announcements & Notifications',
            constraints: BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
            padding: EdgeInsets.zero,
            onPressed: () => context.push('/notifications'),
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
            top: 6,
            right: 6,
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
              child: UserAvatarWidget(
                imageSource: widget.currentUser.profileImage,
                fallbackInitial: initial,
                size: size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
