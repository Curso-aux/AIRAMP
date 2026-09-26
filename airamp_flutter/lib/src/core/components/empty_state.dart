import 'package:flutter/material.dart';
import '../animations/animated_pressable.dart';
import '../theme/app_theme.dart';

/// Semantic type representing the nature of the feedback state.
enum AppFeedbackType {
  empty,
  searchEmpty,
  error,
  offline,
  maintenance,
}

/// A modern, standardized feedback state component for empty, search-not-found,
/// error, and offline scenarios.
///
/// Features:
/// - Prominent, soft-glowing squircle icon badge.
/// - Clear, human-readable headline and explanatory description.
/// - Immediate, actionable 1-tap resolution buttons with tactile micro-interactions.
/// - Full-page and compact in-card variants.
class AppFeedbackState extends StatelessWidget {
  final AppFeedbackType type;
  final String title;
  final String? message;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final IconData? primaryActionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData? secondaryActionIcon;
  final bool compact;
  final Widget? customContent;
  final EdgeInsetsGeometry? padding;

  const AppFeedbackState({
    super.key,
    this.type = AppFeedbackType.empty,
    required this.title,
    this.message,
    this.icon,
    this.iconColor,
    this.iconBgColor,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionIcon,
    this.compact = false,
    this.customContent,
    this.padding,
  });

  /// Factory for empty data states (e.g. empty lists, initial setup).
  factory AppFeedbackState.empty({
    Key? key,
    required String title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? actionIcon,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    bool compact = false,
    EdgeInsetsGeometry? padding,
  }) {
    return AppFeedbackState(
      key: key,
      type: AppFeedbackType.empty,
      title: title,
      message: message,
      icon: icon ?? Icons.inbox_outlined,
      primaryActionLabel: actionLabel,
      onPrimaryAction: onAction,
      primaryActionIcon: actionIcon ?? Icons.add_rounded,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      compact: compact,
      padding: padding,
    );
  }

  /// Factory for search results that returned zero matches.
  factory AppFeedbackState.search({
    Key? key,
    String? title,
    String? query,
    String? message,
    VoidCallback? onClearSearch,
    String actionLabel = 'Clear Search',
    bool compact = false,
    EdgeInsetsGeometry? padding,
  }) {
    final effectiveTitle = title ?? (query != null && query.isNotEmpty ? 'No Results Found' : 'No Matches');
    final effectiveMessage = message ??
        (query != null && query.isNotEmpty
            ? 'No items matched "$query". Try checking for spelling errors or clearing your search query.'
            : 'Try adjusting your search terms or filters to find what you are looking for.');

    return AppFeedbackState(
      key: key,
      type: AppFeedbackType.searchEmpty,
      title: effectiveTitle,
      message: effectiveMessage,
      icon: Icons.search_off_rounded,
      primaryActionLabel: onClearSearch != null ? actionLabel : null,
      onPrimaryAction: onClearSearch,
      primaryActionIcon: Icons.close_rounded,
      compact: compact,
      padding: padding,
    );
  }

  /// Factory for network or offline failures.
  factory AppFeedbackState.offline({
    Key? key,
    String title = 'No Internet Connection',
    String message = 'Please check your Wi-Fi or mobile data settings and tap retry to reconnect.',
    VoidCallback? onRetry,
    String retryLabel = 'Retry Connection',
    bool compact = false,
    EdgeInsetsGeometry? padding,
  }) {
    return AppFeedbackState(
      key: key,
      type: AppFeedbackType.offline,
      title: title,
      message: message,
      icon: Icons.wifi_off_rounded,
      primaryActionLabel: onRetry != null ? retryLabel : null,
      onPrimaryAction: onRetry,
      primaryActionIcon: Icons.refresh_rounded,
      compact: compact,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve visual styling based on type
    final Color resolvedColor;
    final Color resolvedBg;
    final IconData resolvedIcon;

    switch (type) {
      case AppFeedbackType.error:
        resolvedColor = iconColor ?? (isDark ? AppTheme.darkError : AppTheme.lightError);
        resolvedBg = iconBgColor ?? resolvedColor.withValues(alpha: isDark ? 0.14 : 0.08);
        resolvedIcon = icon ?? Icons.error_outline_rounded;
        break;
      case AppFeedbackType.offline:
        resolvedColor = iconColor ?? (isDark ? AppTheme.darkWarning : AppTheme.lightWarning);
        resolvedBg = iconBgColor ?? resolvedColor.withValues(alpha: isDark ? 0.14 : 0.08);
        resolvedIcon = icon ?? Icons.wifi_off_rounded;
        break;
      case AppFeedbackType.searchEmpty:
        resolvedColor = iconColor ?? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent);
        resolvedBg = iconBgColor ?? resolvedColor.withValues(alpha: isDark ? 0.14 : 0.08);
        resolvedIcon = icon ?? Icons.search_off_rounded;
        break;
      case AppFeedbackType.maintenance:
        resolvedColor = iconColor ?? const Color(0xFF8B5CF6);
        resolvedBg = iconBgColor ?? resolvedColor.withValues(alpha: isDark ? 0.14 : 0.08);
        resolvedIcon = icon ?? Icons.engineering_outlined;
        break;
      case AppFeedbackType.empty:
        resolvedColor = iconColor ?? (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextSecondary);
        resolvedBg = iconBgColor ?? (isDark ? AppTheme.darkSurfaceLight.withValues(alpha: 0.6) : const Color(0xFFF1F5F9));
        resolvedIcon = icon ?? Icons.inbox_outlined;
        break;
    }

    final effectivePadding = padding ??
        (compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
            : const EdgeInsets.symmetric(horizontal: 28, vertical: 36));

    final badgeSize = compact ? 54.0 : 72.0;
    final iconSize = compact ? 26.0 : 34.0;
    final titleFontSize = compact ? 15.0 : 18.0;
    final messageFontSize = compact ? 12.0 : 13.5;

    return Center(
      child: Padding(
        padding: effectivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Soft-tinted squircle badge
            Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: resolvedBg,
                borderRadius: BorderRadius.circular(compact ? 16 : 22),
                border: Border.all(
                  color: resolvedColor.withValues(alpha: isDark ? 0.25 : 0.2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: resolvedColor.withValues(alpha: isDark ? 0.12 : 0.06),
                    blurRadius: compact ? 12 : 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(resolvedIcon, size: iconSize, color: resolvedColor),
            ),
            SizedBox(height: compact ? 12 : 16),

            // Headline
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),

            // Description
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 300 : 420),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: messageFontSize,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],

            if (customContent != null) ...[
              const SizedBox(height: 12),
              customContent!,
            ],

            // Action Buttons
            if ((primaryActionLabel != null && onPrimaryAction != null) ||
                (secondaryActionLabel != null && onSecondaryAction != null)) ...[
              SizedBox(height: compact ? 16 : 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (primaryActionLabel != null && onPrimaryAction != null)
                    AnimatedPressable(
                      onTap: onPrimaryAction,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 20,
                          vertical: compact ? 8 : 11,
                        ),
                        decoration: BoxDecoration(
                          color: type == AppFeedbackType.error
                              ? (isDark ? AppTheme.darkError : AppTheme.lightError)
                              : AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (type == AppFeedbackType.error
                                      ? (isDark ? AppTheme.darkError : AppTheme.lightError)
                                      : AppTheme.primary)
                                  .withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (primaryActionIcon != null) ...[
                              Icon(primaryActionIcon, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              primaryActionLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (secondaryActionLabel != null && onSecondaryAction != null)
                    AnimatedPressable(
                      onTap: onSecondaryAction,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 18,
                          vertical: compact ? 8 : 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (secondaryActionIcon != null) ...[
                              Icon(
                                secondaryActionIcon,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              secondaryActionLabel!,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Specialized, human-friendly Empty State widget.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    this.padding,
  });

  /// Factory for zero search results.
  factory AppEmptyState.search({
    Key? key,
    String? title,
    String? query,
    String? message,
    VoidCallback? onClearSearch,
    String actionLabel = 'Clear Search',
    bool compact = false,
    EdgeInsetsGeometry? padding,
  }) {
    return AppEmptyState(
      key: key,
      title: title ?? (query != null && query.isNotEmpty ? 'No Results Found' : 'No Matches'),
      message: message ??
          (query != null && query.isNotEmpty
              ? 'No items matched "$query". Try checking for spelling errors or clearing your search.'
              : 'Try adjusting your search terms or filters to find what you are looking for.'),
      icon: Icons.search_off_rounded,
      actionLabel: onClearSearch != null ? actionLabel : null,
      onAction: onClearSearch,
      actionIcon: Icons.close_rounded,
      compact: compact,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFeedbackState.empty(
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      actionIcon: actionIcon,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      compact: compact,
      padding: padding,
    );
  }
}

/// Specialized, user-centric Error State widget with intelligent failure
/// interpretation and immediate 1-tap recovery.
class AppErrorState extends StatefulWidget {
  final dynamic error;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  const AppErrorState({
    super.key,
    this.error,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    this.padding,
  });

  @override
  State<AppErrorState> createState() => _AppErrorStateState();
}

class _AppErrorStateState extends State<AppErrorState> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final rawError = widget.error?.toString() ?? '';
    final lower = rawError.toLowerCase();

    final bool isOffline = lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('clientexception');

    final bool isTimeout = lower.contains('timeout');
    final bool isAuth = lower.contains('401') || lower.contains('unauthorized');
    final bool isForbidden = lower.contains('403') || lower.contains('forbidden');
    final bool isServer = lower.contains('500') || lower.contains('server');

    final String resolvedTitle;
    final String resolvedMessage;
    final IconData resolvedIcon;
    final AppFeedbackType resolvedType;

    if (widget.title != null) {
      resolvedTitle = widget.title!;
      resolvedMessage = widget.message ?? (isOffline ? 'Please check your connection and try again.' : 'An error occurred. Tap below to retry.');
      resolvedIcon = isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
      resolvedType = isOffline ? AppFeedbackType.offline : AppFeedbackType.error;
    } else if (isOffline) {
      resolvedTitle = 'No Internet Connection';
      resolvedMessage = widget.message ?? 'Please check your Wi-Fi or cellular network and tap retry.';
      resolvedIcon = Icons.wifi_off_rounded;
      resolvedType = AppFeedbackType.offline;
    } else if (isTimeout) {
      resolvedTitle = 'Connection Timed Out';
      resolvedMessage = widget.message ?? 'The server took too long to respond. Please try again.';
      resolvedIcon = Icons.timer_off_outlined;
      resolvedType = AppFeedbackType.error;
    } else if (isAuth) {
      resolvedTitle = 'Session Expired';
      resolvedMessage = widget.message ?? 'Your session has ended. Please log in again to continue.';
      resolvedIcon = Icons.lock_clock_outlined;
      resolvedType = AppFeedbackType.error;
    } else if (isForbidden) {
      resolvedTitle = 'Access Restricted';
      resolvedMessage = widget.message ?? 'You do not have permission to view or modify this resource.';
      resolvedIcon = Icons.gpp_bad_outlined;
      resolvedType = AppFeedbackType.error;
    } else if (isServer) {
      resolvedTitle = 'Server Temporarily Unavailable';
      resolvedMessage = widget.message ?? 'The service encountered an unexpected error. Please try again in a few moments.';
      resolvedIcon = Icons.cloud_off_rounded;
      resolvedType = AppFeedbackType.error;
    } else {
      resolvedTitle = 'Unable to Load Data';
      resolvedMessage = widget.message ?? 'Something went wrong while retrieving information. Tap below to retry.';
      resolvedIcon = Icons.error_outline_rounded;
      resolvedType = AppFeedbackType.error;
    }

    Widget? detailsWidget;
    if (rawError.isNotEmpty && !widget.compact) {
      detailsWidget = Column(
        children: [
          TextButton(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _showDetails ? 'Hide technical info' : 'View technical info',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
          if (_showDetails) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkSurfaceLight
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.lightBorder,
                ),
              ),
              child: SelectableText(
                rawError,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return AppFeedbackState(
      type: resolvedType,
      title: resolvedTitle,
      message: resolvedMessage,
      icon: resolvedIcon,
      primaryActionLabel: widget.onRetry != null ? widget.retryLabel : null,
      onPrimaryAction: widget.onRetry,
      primaryActionIcon: Icons.refresh_rounded,
      secondaryActionLabel: widget.secondaryActionLabel,
      onSecondaryAction: widget.onSecondaryAction,
      compact: widget.compact,
      padding: widget.padding,
      customContent: detailsWidget,
    );
  }
}

/// Backwards-compatible EmptyState component.
class EmptyState extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool compact;

  const EmptyState({
    super.key,
    this.message = 'No data available',
    this.title,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppFeedbackState(
      type: AppFeedbackType.empty,
      title: title ?? (message.isNotEmpty ? message : 'No Data Available'),
      message: title != null ? message : null,
      icon: icon,
      primaryActionLabel: actionLabel,
      onPrimaryAction: onAction,
      primaryActionIcon: Icons.add_rounded,
      compact: compact,
    );
  }
}
