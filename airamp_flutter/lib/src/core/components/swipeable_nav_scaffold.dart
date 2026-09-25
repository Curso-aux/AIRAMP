import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// A premium, adaptive scaffold supporting:
/// 1. Smooth auto-hiding of the bottom navigation bar while actively scrolling
/// 2. Smooth reveal of the bottom navigation bar as soon as scrolling stops
/// 3. Horizontal swipe gestures to switch between navigation tabs
/// 4. Hardware-accelerated overflow-free slide animation
class SwipeableNavScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<BottomNavigationBarItem> items;
  final Set<int> swipeDisabledIndices;
  final double selectedFontSize;
  final double unselectedFontSize;
  final Color? backgroundColor;

  const SwipeableNavScaffold({
    super.key,
    required this.navigationShell,
    required this.items,
    this.swipeDisabledIndices = const {},
    this.selectedFontSize = 10,
    this.unselectedFontSize = 10,
    this.backgroundColor,
  });

  @override
  ConsumerState<SwipeableNavScaffold> createState() => _SwipeableNavScaffoldState();
}

class _SwipeableNavScaffoldState extends ConsumerState<SwipeableNavScaffold> {
  bool _isBarVisible = true;
  Timer? _scrollStopTimer;
  static const double _baseBarHeight = 58.0;

  @override
  void dispose() {
    _scrollStopTimer?.cancel();
    super.dispose();
  }

  void _showBar() {
    _scrollStopTimer?.cancel();
    _scrollStopTimer = null;
    if (!_isBarVisible && mounted) {
      setState(() => _isBarVisible = true);
    }
  }

  void _hideBar() {
    if (_isBarVisible && mounted) {
      setState(() => _isBarVisible = false);
    }
  }

  void _scheduleShowOnStop() {
    _scrollStopTimer?.cancel();
    _scrollStopTimer = Timer(const Duration(milliseconds: 320), () {
      _showBar();
    });
  }

  void _goBranch(int index) {
    _showBar();
    if (index != widget.navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    // If current tab has swipe disabled (e.g. Chat with dismissible rows), do nothing
    if (widget.swipeDisabledIndices.contains(widget.navigationShell.currentIndex)) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    const velocityThreshold = 260.0;

    if (velocity < -velocityThreshold) {
      // Swiped Left -> go to NEXT tab
      final nextIndex = widget.navigationShell.currentIndex + 1;
      if (nextIndex < widget.items.length) {
        _goBranch(nextIndex);
      }
    } else if (velocity > velocityThreshold) {
      // Swiped Right -> go to PREVIOUS tab
      final prevIndex = widget.navigationShell.currentIndex - 1;
      if (prevIndex >= 0) {
        _goBranch(prevIndex);
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      // If user is near top of scrollview, always reveal the bar
      if (notification.metrics.pixels <= 15) {
        _showBar();
        return false;
      }

      if (notification is ScrollStartNotification) {
        // User started scrolling
        _scrollStopTimer?.cancel();
      } else if (notification is ScrollUpdateNotification) {
        final dy = (notification.scrollDelta ?? 0).abs();
        if (dy > 1.0) {
          // Actively scrolling: hide bottom bar
          _hideBar();
          // Reset stop debounce timer: reveal when movement pauses
          _scheduleShowOnStop();
        }
      } else if (notification is UserScrollNotification) {
        if (notification.direction == ScrollDirection.idle) {
          // Touch released / scrolling idle
          _scheduleShowOnStop();
        } else {
          // Actively moving up or down
          _hideBar();
          _scheduleShowOnStop();
        }
      } else if (notification is ScrollEndNotification) {
        // Drag or momentum fling has completely finished
        _scrollStopTimer?.cancel();
        _showBar();
      }
    }
    return false; // Allow other listeners to receive notification
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalBarHeight = _baseBarHeight + bottomPadding;

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? AppTheme.background,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _handleHorizontalSwipe,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        height: _isBarVisible ? totalBarHeight : 0.0,
        child: ClipRect(
          child: OverflowBox(
            minHeight: totalBarHeight,
            maxHeight: totalBarHeight,
            alignment: Alignment.topCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              offset: _isBarVisible ? Offset.zero : const Offset(0, 0.4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isBarVisible ? 1.0 : 0.0,
                child: Container(
                  height: totalBarHeight,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
                  ),
                  child: BottomNavigationBar(
                    backgroundColor: AppTheme.surface,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: AppTheme.primary,
                    unselectedItemColor: AppTheme.textMuted,
                    showUnselectedLabels: true,
                    selectedFontSize: widget.selectedFontSize,
                    unselectedFontSize: widget.unselectedFontSize,
                    currentIndex: widget.navigationShell.currentIndex,
                    onTap: _goBranch,
                    items: widget.items,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
