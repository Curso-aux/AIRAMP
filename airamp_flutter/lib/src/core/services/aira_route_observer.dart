import 'package:flutter/material.dart';

/// Real-time route tracking observer that records active routes in the Navigator,
/// specifically identifying whether a Modal (Dialog, BottomSheet, PopupMenu, etc.)
/// is currently displaying above the base pages.
class AiraRouteObserver extends NavigatorObserver {
  AiraRouteObserver._();
  static final AiraRouteObserver instance = AiraRouteObserver._();

  final List<Route<dynamic>> _routeStack = [];

  List<Route<dynamic>> get routeStack => List.unmodifiable(_routeStack);

  Route<dynamic>? get topRoute => _routeStack.isNotEmpty ? _routeStack.last : null;

  /// Returns true if [route] represents an active modal displaying above the base page.
  static bool isModalRoute(Route<dynamic>? route) {
    if (route == null) return false;

    // Direct popup routes (DialogRoute, ModalBottomSheetRoute, RawDialogRoute, PopupMenuRoute, etc.)
    if (route is PopupRoute) return true;
    if (route is RawDialogRoute) return true;
    if (route is ModalBottomSheetRoute) return true;
    if (route is DialogRoute) return true;

    // Any ModalRoute that is not the base/first route and has modal characteristics (non-opaque, barrier)
    if (route is ModalRoute) {
      if (!route.isFirst) {
        if (!route.opaque || route.barrierDismissible || route.barrierColor != null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns the current active topmost modal route if one is showing above the pages.
  Route<dynamic>? get topModalRoute {
    for (int i = _routeStack.length - 1; i >= 0; i--) {
      final r = _routeStack[i];
      if (isModalRoute(r) && r.isActive) {
        return r;
      }
    }
    return null;
  }

  /// Finds the RenderObject for the active topmost modal, if one exists.
  RenderObject? findTopModalRenderObject() {
    final modal = topModalRoute;
    if (modal is ModalRoute && modal.subtreeContext != null) {
      try {
        final ro = modal.subtreeContext!.findRenderObject();
        if (ro != null && ro.attached) {
          return ro;
        }
      } catch (_) {}
    }

    // Secondary heuristic: check if primaryFocus context is inside a ModalRoute
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      try {
        final route = ModalRoute.of(focusContext);
        if (route != null && isModalRoute(route) && route.subtreeContext != null) {
          final ro = route.subtreeContext!.findRenderObject();
          if (ro != null && ro.attached) {
            return ro;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _routeStack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _routeStack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _routeStack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      final index = _routeStack.indexOf(oldRoute);
      if (index != -1) {
        if (newRoute != null) {
          _routeStack[index] = newRoute;
        } else {
          _routeStack.removeAt(index);
        }
        return;
      }
    }
    if (newRoute != null) {
      _routeStack.add(newRoute);
    }
  }
}
