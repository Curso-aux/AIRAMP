import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Ecosystem Item model representing a platform or core technology
class EcosystemItem {
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  const EcosystemItem({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });
}

/// Aceternity UI-style Animated Cross-Platform Ecosystem Cloud.
///
/// Features:
/// - Staggered multi-column logo swap with vertical motion, opacity fade, and directional blur.
/// - Sleek dark glassmorphism container with gradient typography and responsive grid/row.
/// - Hover/tap tooltip with detailed platform architecture guidelines.
class CrossPlatformEcosystemCloud extends StatefulWidget {
  final bool isDark;
  final bool isCompact;

  const CrossPlatformEcosystemCloud({
    super.key,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  State<CrossPlatformEcosystemCloud> createState() =>
      _CrossPlatformEcosystemCloudState();
}

class _CrossPlatformEcosystemCloudState
    extends State<CrossPlatformEcosystemCloud> {
  // 4 columns, each cycling through 3 distinct ecosystem platforms/technologies
  static const List<List<EcosystemItem>> _columns = [
    // Column 0: Web & Curriculum
    [
      EcosystemItem(
        title: 'Web Console',
        category: 'Administrators & Faculty',
        description:
            'Responsive web platform accessible via Chrome, Safari, and Edge for institutional curriculum, pass rates, and master governance.',
        icon: Icons.language_rounded,
        gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      ),
      EcosystemItem(
        title: 'DepEd SHS',
        category: 'Senior High Curriculum',
        description:
            'Pre-loaded DepEd SHS competencies across STEM, ABM, HUMSS, and TVL tracks structured into verifiable Learning Outcomes.',
        icon: Icons.school_rounded,
        gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      EcosystemItem(
        title: 'Gizmo Reviews',
        category: 'Gamified Modules',
        description:
            'Interactive flashcard reviews and active-recall practice modules tailored for student mastery test prep.',
        icon: Icons.auto_awesome_rounded,
        gradientColors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
      ),
    ],

    // Column 1: Mobile & Offline
    [
      EcosystemItem(
        title: 'Mobile PWA',
        category: 'iOS & Android Web',
        description:
            'Add AIRA to your device Home Screen for an instant, full-screen mobile app feel with offline lesson caching.',
        icon: Icons.phone_iphone_rounded,
        gradientColors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
      ),
      EcosystemItem(
        title: 'SQLite Local',
        category: 'Zero-Lag Engine',
        description:
            'High-speed local embedded database on client devices for zero-latency offline assessment test taking and lesson access.',
        icon: Icons.storage_rounded,
        gradientColors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
      ),
      EcosystemItem(
        title: 'Admin KPIs',
        category: 'Institutional Metrics',
        description:
            'Live analytics, pass rates, section capacities, and cohort distribution reports for school heads and supervisors.',
        icon: Icons.insights_rounded,
        gradientColors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
      ),
    ],

    // Column 2: Windows PC & Cloud Sync
    [
      EcosystemItem(
        title: 'Windows Desktop',
        category: 'School PC Labs',
        description:
            'Offline-ready assessment execution, auto-sync, and teacher grading tools optimized for campus computer laboratories.',
        icon: Icons.desktop_windows_rounded,
        gradientColors: [Color(0xFF6366F1), Color(0xFF4338CA)],
      ),
      EcosystemItem(
        title: 'Firebase Cloud',
        category: 'Realtime Sync',
        description:
            'Instant bi-directional cloud synchronization connecting offline SQLite records once network connectivity is restored.',
        icon: Icons.cloud_sync_rounded,
        gradientColors: [Color(0xFFFF7043), Color(0xFFD84315)],
      ),
      EcosystemItem(
        title: 'Section Keys',
        category: 'Self-Enrollment',
        description:
            '6-character access codes for seamless student self-enrollment into assigned grade levels and class sections.',
        icon: Icons.vpn_key_rounded,
        gradientColors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      ),
    ],

    // Column 3: Android Native & Scoring Hub
    [
      EcosystemItem(
        title: 'Android Native',
        category: 'Portable APK',
        description:
            'Dedicated Android APK for portable learning outcome reviews and direct teacher consultations on mobile hardware.',
        icon: Icons.android_rounded,
        gradientColors: [Color(0xFF22C55E), Color(0xFF15803D)],
      ),
      EcosystemItem(
        title: 'Scorebook Hub',
        category: 'Teacher Evaluations',
        description:
            'Comprehensive teacher scoring tools with LO mastery calculations, student feedback logs, and exportable grade sheets.',
        icon: Icons.fact_check_rounded,
        gradientColors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
      ),
      EcosystemItem(
        title: 'Zero-Lag Sync',
        category: 'Offline Resilience',
        description:
            'Intelligent conflict-free delta sync that guarantees no student exam progress or faculty grading is lost during outages.',
        icon: Icons.wifi_off_rounded,
        gradientColors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
      ),
    ],
  ];

  final List<GlobalKey<_AnimatedSlotState>> _slotKeys = [
    GlobalKey<_AnimatedSlotState>(),
    GlobalKey<_AnimatedSlotState>(),
    GlobalKey<_AnimatedSlotState>(),
    GlobalKey<_AnimatedSlotState>(),
  ];

  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    // Rotate every 3.2 seconds with a wave stagger
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      _triggerNextRotation();
    });
  }

  void _triggerNextRotation() {
    if (!mounted) return;
    for (int i = 0; i < _slotKeys.length; i++) {
      // Stagger by 120ms per column to create the natural wave motion from Aceternity UI
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) {
          _slotKeys[i].currentState?.advance();
        }
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isNarrow = MediaQuery.sizeOf(context).width < 620;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 16 : 24,
        vertical: widget.isCompact ? 20 : 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Header Title (Aceternity UI bold gradient style) ──────
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isDark
                  ? const [Colors.white, Color(0xFFCBD5E1)]
                  : const [Color(0xFF0F172A), Color(0xFF334155)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              'Cross-Platform Ecosystem',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.isCompact ? 19 : 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── Subtitle ─────────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              'Unified learning outcomes, offline caching, and administrative governance across every device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.isCompact ? 12 : 13.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: widget.isCompact ? 20 : 26),

          // ── Animated Logo Cloud Grid / Row ───────────────────────
          if (isNarrow)
            // 2x2 layout on narrow mobile screens
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSlot(0)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSlot(1)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildSlot(2)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSlot(3)),
                  ],
                ),
              ],
            )
          else
            // Single sleek 4-column horizontal ticker row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildSlot(0)),
                const SizedBox(width: 12),
                Expanded(child: _buildSlot(1)),
                const SizedBox(width: 12),
                Expanded(child: _buildSlot(2)),
                const SizedBox(width: 12),
                Expanded(child: _buildSlot(3)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSlot(int colIndex) {
    return _AnimatedSlot(
      key: _slotKeys[colIndex],
      items: _columns[colIndex],
      isDark: widget.isDark,
    );
  }
}

/// A single animated slot in the ecosystem cloud that transitions
/// between items with a vertical slide, opacity fade, and directional blur.
class _AnimatedSlot extends StatefulWidget {
  final List<EcosystemItem> items;
  final bool isDark;

  const _AnimatedSlot({
    super.key,
    required this.items,
    required this.isDark,
  });

  @override
  State<_AnimatedSlot> createState() => _AnimatedSlotState();
}

class _AnimatedSlotState extends State<_AnimatedSlot>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _incomingIndex = 1;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.85, curve: Curves.easeInOut),
    );

    _blurAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex = _incomingIndex;
          _animController.reset();
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void advance() {
    if (!mounted || _animController.isAnimating) return;
    _incomingIndex = (_currentIndex + 1) % widget.items.length;
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items[_currentIndex];
    final incomingItem = widget.items[_incomingIndex];
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: '${currentItem.title} (${currentItem.category})\n${currentItem.description}',
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.4,
        ),
        waitDuration: const Duration(milliseconds: 300),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 68,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark
                ? (_isHovered
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF131A29))
                : (_isHovered
                    ? Colors.white
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? currentItem.gradientColors.first.withValues(alpha: 0.5)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06)),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: currentItem.gradientColors.first.withValues(alpha: 0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final isAnimating = _animController.isAnimating;

              if (!isAnimating) {
                // Static resting view
                return Center(
                  child: _buildItemContent(currentItem, isDark),
                );
              }

              // Animated Transition View:
              // Outgoing item slides up (-36px), blurs vertically, and fades out.
              // Incoming item slides up from bottom (+36px to 0), unblurs, and fades in.
              final progress = _slideAnimation.value;
              final fadeVal = _fadeAnimation.value;
              final blurVal = (_blurAnimation.value * 5.0).clamp(0.0, 5.0);
              final unblurVal = ((1.0 - _blurAnimation.value) * 5.0).clamp(0.0, 5.0);

              return Stack(
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.center,
                children: [
                  // Outgoing Item
                  Transform.translate(
                    offset: Offset(0, -36.0 * progress),
                    child: Opacity(
                      opacity: (1.0 - fadeVal).clamp(0.0, 1.0),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 0.0,
                          sigmaY: blurVal,
                        ),
                        child: _buildItemContent(currentItem, isDark),
                      ),
                    ),
                  ),

                  // Incoming Item
                  Transform.translate(
                    offset: Offset(0, 36.0 * (1.0 - progress)),
                    child: Opacity(
                      opacity: fadeVal.clamp(0.0, 1.0),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 0.0,
                          sigmaY: unblurVal,
                        ),
                        child: _buildItemContent(incomingItem, isDark),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(EcosystemItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sleek gradient rounded brand badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: item.gradientColors.first.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              item.icon,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          // Typography matching Aceternity UI logo cloud
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
