import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../routing/app_router.dart';
import 'aira_route_observer.dart';

class ExtractedTextItem {
  final String text;
  final Rect globalBounds;

  ExtractedTextItem({
    required this.text,
    required this.globalBounds,
  });
}

/// Extracts all visible on-screen text in natural reading order
/// by traversing Flutter's active RenderTree.
///
/// Modality-aware:
/// - If a Modal (Dialog, BottomSheet, PopupMenu, CupertinoModal, etc.) is active above the page,
///   AIRA strictly scans ONLY the active modal and its contents, completely ignoring the underlying occluded page.
/// - When scanning a modal, bottom nav padding cutoff is removed so action buttons at the bottom of the modal
///   (e.g., Save, Confirm, Close, Submit) are fully captured and read aloud.
/// - If no modal is active, AIRA scans the current page, accurately pruning inactive IndexedStack/Offstage tabs
///   and filtering out persistent navigation elements.
class AiraScreenTextExtractor {
  AiraScreenTextExtractor._();

  static final Set<String> _ignoredNavLabels = {
    'dashboard & overview',
    'dashboard',
    'enrolled courses',
    'academic progress',
    'quiz history',
    'messages & chat',
    'chat',
    'courses',
    'progress',
    'quizzes',
    'subjects & curriculum',
    'class timetable',
    'student grades',
    'enrolled students',
    'learner access',
    'teacher access',
    'student portal',
    'teacher portal',
    'sign out',
  };

  /// Scans the currently visible on-screen UI starting from [context].
  ///
  /// Prioritizes active modals above the page. If a modal is open, only the modal
  /// contents are extracted. Otherwise, the visible page is extracted.
  static String extractScreenText(
    BuildContext context, {
    Rect? ignoreRect,
  }) {
    final effectiveContext = rootNavigatorKey.currentContext ?? context;
    final mediaQuery = MediaQuery.maybeOf(effectiveContext) ?? MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size ?? const Size(1200, 2400);

    // 1. Check if a modal/dialog/bottomsheet is currently displayed above the page
    final RenderObject? modalRenderObject = _findActiveModalRenderObject(effectiveContext);
    final bool isScanningModal = modalRenderObject != null;

    final RenderObject? targetRenderObject =
        modalRenderObject ?? _findPageRootRenderObject(effectiveContext);

    if (targetRenderObject == null) {
      return '';
    }

    // When scanning a modal, do not cut off the bottom of the screen (bottom sheets often reach the bottom)
    final double bottomCutoff = isScanningModal
        ? (mediaQuery?.padding.bottom ?? 0)
        : ((mediaQuery?.padding.bottom ?? 0) + 68.0);

    final items = <ExtractedTextItem>[];
    _traverseRenderTree(
      targetRenderObject,
      items,
      ignoreRect,
      screenSize,
      bottomCutoff,
      isScanningModal: isScanningModal,
    );

    if (items.isEmpty) {
      return '';
    }

    // Sort items by vertical position first (18px row bucket), then horizontally
    items.sort((a, b) {
      final aRow = (a.globalBounds.top / 18).floor();
      final bRow = (b.globalBounds.top / 18).floor();
      if (aRow != bRow) {
        return aRow.compareTo(bRow);
      }
      return a.globalBounds.left.compareTo(b.globalBounds.left);
    });

    final buffer = StringBuffer();
    final seen = <String>{};

    for (final item in items) {
      final clean = item.text.trim();
      if (clean.isEmpty) continue;

      // Skip single character punctuation or glyph icons
      if (clean.length == 1 && !RegExp(r'[a-zA-Z0-9]').hasMatch(clean)) {
        continue;
      }

      // Avoid exact immediate consecutive duplicates
      if (!seen.add(clean)) {
        continue;
      }

      if (buffer.isNotEmpty) {
        final currentStr = buffer.toString();
        if (!currentStr.endsWith('.') &&
            !currentStr.endsWith('!') &&
            !currentStr.endsWith('?') &&
            !currentStr.endsWith(':') &&
            !currentStr.endsWith('\n')) {
          buffer.write('. ');
        } else {
          buffer.write(' ');
        }
      }
      buffer.write(clean);
    }

    return buffer.toString().trim();
  }

  /// Locates the active modal's RenderObject if a dialog/sheet/popup is showing above the pages.
  static RenderObject? _findActiveModalRenderObject(BuildContext context) {
    // 1. Direct inquiry to AiraRouteObserver which tracks the Navigator route stack
    final roFromObserver = AiraRouteObserver.instance.findTopModalRenderObject();
    if (roFromObserver != null && roFromObserver.attached) {
      debugPrint('[AiraScanner] Detected active modal via AiraRouteObserver: $roFromObserver');
      return roFromObserver;
    }

    // 2. Check primaryFocus element for enclosing ModalRoute
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      try {
        final route = ModalRoute.of(focusContext);
        if (route != null && AiraRouteObserver.isModalRoute(route) && route.subtreeContext != null) {
          final ro = route.subtreeContext!.findRenderObject();
          if (ro != null && ro.attached) {
            debugPrint('[AiraScanner] Detected active modal via primaryFocus: $ro');
            return ro;
          }
        }
      } catch (_) {}
    }

    // 3. Inspect Root Navigator Overlay for active modal entry above modal barrier
    try {
      final navState = rootNavigatorKey.currentState ??
          Navigator.maybeOf(context, rootNavigator: true);
      final overlay = navState?.overlay;
      if (overlay != null) {
        final overlayRo = overlay.context.findRenderObject();
        if (overlayRo is RenderStack) {
          RenderBox? candidate;
          bool hasBarrier = false;
          RenderBox? child = overlayRo.firstChild;
          while (child != null) {
            final childName = child.runtimeType.toString();
            if (childName.contains('Barrier') || childName.contains('ModalBarrier')) {
              hasBarrier = true;
              // Reset candidate to whatever comes AFTER the barrier
              candidate = null;
            } else if (hasBarrier) {
              candidate = child;
            }
            child = overlayRo.childAfter(child);
          }

          if (hasBarrier && candidate != null && candidate.attached) {
            debugPrint('[AiraScanner] Detected active modal above barrier in Overlay: $candidate');
            return candidate;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fallback root RenderObject for regular full-page scanning when no modal is open.
  static RenderObject? _findPageRootRenderObject(BuildContext context) {
    // 1. Try WidgetsBinding root element for full tree traversal
    try {
      final rootRo = WidgetsBinding.instance.rootElement?.renderObject;
      if (rootRo != null && rootRo.attached) return rootRo;
    } catch (_) {}

    // 2. Try Navigator context
    final navigator = Navigator.maybeOf(context);
    if (navigator?.context != null) {
      final ro = navigator!.context.findRenderObject();
      if (ro != null && ro.attached) return ro;
    }

    // 3. Fallback to route or current context
    final modalRoute = ModalRoute.of(context);
    if (modalRoute?.subtreeContext != null) {
      final ro = modalRoute!.subtreeContext!.findRenderObject();
      if (ro != null && ro.attached) return ro;
    }

    return context.findRenderObject();
  }

  static void _traverseRenderTree(
    RenderObject node,
    List<ExtractedTextItem> items,
    Rect? ignoreRect,
    Size screenSize,
    double bottomCutoff, {
    bool isScanningModal = false,
  }) {
    // 1. CRITICAL: Handle RenderIndexedStack (StatefulNavigationShell / IndexedStack tabs)
    // Only the child at node.index is active and painted on screen!
    if (node is RenderIndexedStack) {
      final activeIndex = node.index;
      if (activeIndex == null) return;
      int cur = 0;
      RenderBox? child = node.firstChild;
      while (child != null) {
        if (cur == activeIndex) {
          _traverseRenderTree(
            child,
            items,
            ignoreRect,
            screenSize,
            bottomCutoff,
            isScanningModal: isScanningModal,
          );
          return;
        }
        cur++;
        child = node.childAfter(child);
      }
      return;
    }

    // 2. CRITICAL: Skip offstage/hidden branches in Offstage widgets
    if (node is RenderOffstage && node.offstage) {
      return;
    }

    // 3. Skip invisible opacity elements
    if (node is RenderOpacity && node.opacity <= 0.001) {
      return;
    }
    if (node is RenderAnimatedOpacity && node.opacity.value <= 0.001) {
      return;
    }

    // 4. Extract text from visible RenderParagraphs
    if (node is RenderParagraph) {
      if (node.hasSize && node.size.width > 2 && node.size.height > 2) {
        try {
          Offset offset = Offset.zero;
          try {
            offset = node.localToGlobal(Offset.zero);
          } catch (_) {}

          final bounds = Rect.fromLTWH(
            offset.dx,
            offset.dy,
            node.size.width,
            node.size.height,
          );

          // Must be actively visible on the user's screen
          final isVisibleOnScreen = bounds.bottom > 8 &&
              bounds.top < (screenSize.height - bottomCutoff) &&
              bounds.right > 0 &&
              bounds.left < screenSize.width;

          if (!isVisibleOnScreen) {
            return;
          }

          // Check if this text overlaps AIRA's floating avatar button
          if (ignoreRect != null && ignoreRect.overlaps(bounds)) {
            return;
          }

          final text = node.text.toPlainText();
          final trimmed = text.trim();

          // On Desktop Web (width >= 900), ignore persistent sidebar navigation drawer items when scanning the page
          if (!isScanningModal &&
              screenSize.width >= 900 &&
              bounds.left < 265 &&
              _ignoredNavLabels.contains(trimmed.toLowerCase())) {
            return;
          }

          if (trimmed.isNotEmpty && trimmed.length > 1) {
            items.add(ExtractedTextItem(
              text: trimmed,
              globalBounds: bounds,
            ));
          }
        } catch (_) {}
      }
    }

    // Recursively traverse visible children
    node.visitChildren((child) {
      _traverseRenderTree(
        child,
        items,
        ignoreRect,
        screenSize,
        bottomCutoff,
        isScanningModal: isScanningModal,
      );
    });
  }
}
