import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
/// Accurately targets ONLY the screen the user is currently viewing:
/// - Skips inactive branches in RenderIndexedStack (StatefulNavigationShell tabs)
/// - Skips inactive/offstage navigation tabs (Offstage branches)
/// - Skips invisible opacity elements
/// - Skips offscreen elements scrolled outside the current viewport
/// - Filters out bottom navigation bar buttons, desktop sidebar menu items, and AIRA's own floating widget
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

  /// Scans the current active screen starting from [context].
  static String extractScreenText(
    BuildContext context, {
    Rect? ignoreRect,
  }) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size ?? const Size(1200, 2400);
    final bottomNavHeight = (mediaQuery?.padding.bottom ?? 0) + 68.0;

    final RenderObject? rootRenderObject = _findRootRenderObject(context);
    if (rootRenderObject == null) {
      return '';
    }

    final items = <ExtractedTextItem>[];
    _traverseRenderTree(
      rootRenderObject,
      items,
      ignoreRect,
      screenSize,
      bottomNavHeight,
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

  static RenderObject? _findRootRenderObject(BuildContext context) {
    // 1. Try WidgetsBinding root element for full tree traversal with branch pruning
    try {
      final rootRo = WidgetsBinding.instance.rootElement?.renderObject;
      if (rootRo != null) return rootRo;
    } catch (_) {}

    // 2. Try Navigator context
    final navigator = Navigator.maybeOf(context);
    if (navigator?.context != null) {
      final ro = navigator!.context.findRenderObject();
      if (ro != null) return ro;
    }

    // 3. Fallback to route or current context
    final modalRoute = ModalRoute.of(context);
    if (modalRoute?.subtreeContext != null) {
      final ro = modalRoute!.subtreeContext!.findRenderObject();
      if (ro != null) return ro;
    }

    return context.findRenderObject();
  }

  static void _traverseRenderTree(
    RenderObject node,
    List<ExtractedTextItem> items,
    Rect? ignoreRect,
    Size screenSize,
    double bottomNavHeight,
  ) {
    // 1. CRITICAL: Handle RenderIndexedStack (StatefulNavigationShell / IndexedStack tabs)
    // Only the child at node.index is active and painted on screen!
    // All other children (such as Dashboard at index 0 when viewing Courses/Progress)
    // are completely hidden from the user and must NEVER be traversed.
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
            bottomNavHeight,
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

          // Must be actively visible on the user's screen (excluding bottom nav bar)
          final isVisibleOnScreen = bounds.bottom > 12 &&
              bounds.top < (screenSize.height - bottomNavHeight) &&
              bounds.right > 0 &&
              bounds.left < screenSize.width;

          if (!isVisibleOnScreen) {
            return;
          }

          // Check if this text overlaps AIRA's floating widget or speech HUD
          if (ignoreRect != null && ignoreRect.overlaps(bounds)) {
            return;
          }

          final text = node.text.toPlainText();
          final trimmed = text.trim();

          // On Desktop Web (width >= 900), ignore persistent sidebar navigation drawer items
          if (screenSize.width >= 900 &&
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
        bottomNavHeight,
      );
    });
  }
}
