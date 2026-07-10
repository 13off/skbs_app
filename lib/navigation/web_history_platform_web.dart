import 'dart:async';
import 'dart:html' as html;

typedef BrowserBackCallback = FutureOr<bool> Function();

class WebHistoryPlatform {
  static BrowserBackCallback? _onBack;
  static StreamSubscription<html.PopStateEvent>? _subscription;

  static bool _initialized = false;
  static bool _handlingBrowserBack = false;
  static bool _ignoreNextPop = false;
  static int _depth = 0;

  static void initialize(BrowserBackCallback onBack) {
    _onBack = onBack;

    if (_initialized) return;

    _initialized = true;
    _depth = 0;

    try {
      html.window.history.replaceState(
        <String, Object>{'appstroy': true, 'depth': 0},
        html.document.title,
        html.window.location.href,
      );
      _pushGuardState();
    } catch (_) {
      // Some embedded browsers can reject History API calls. In that case the
      // normal Flutter back button still works, and the app must not crash.
    }

    _subscription = html.window.onPopState.listen(_handlePopState);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _onBack = null;
    _initialized = false;
    _handlingBrowserBack = false;
    _ignoreNextPop = false;
    _depth = 0;
  }

  static void pushRoute() {
    if (!_initialized || _handlingBrowserBack) return;

    _depth++;
    _pushRouteState();
  }

  static void appRoutePopped() {
    if (!_initialized || _handlingBrowserBack || _depth <= 0) return;

    _depth--;
    _ignoreNextPop = true;

    try {
      html.window.history.back();
    } catch (_) {
      _ignoreNextPop = false;
    }
  }

  static void _handlePopState(html.PopStateEvent event) {
    if (_ignoreNextPop) {
      _ignoreNextPop = false;
      return;
    }

    if (_depth <= 0) {
      _pushGuardState();
      return;
    }

    _handlingBrowserBack = true;
    _depth--;

    Future<bool>.sync(() async {
      final callback = _onBack;
      if (callback == null) return false;

      return await callback();
    }).then((didPop) {
      if (didPop) return;

      _depth++;
      _pushRouteState();
    }).whenComplete(() {
      scheduleMicrotask(() {
        _handlingBrowserBack = false;
      });
    });
  }

  static void _pushGuardState() {
    try {
      html.window.history.pushState(
        <String, Object>{'appstroy': true, 'guard': true, 'depth': _depth},
        html.document.title,
        html.window.location.href,
      );
    } catch (_) {}
  }

  static void _pushRouteState() {
    try {
      html.window.history.pushState(
        <String, Object>{'appstroy': true, 'route': true, 'depth': _depth},
        html.document.title,
        html.window.location.href,
      );
    } catch (_) {}
  }
}
