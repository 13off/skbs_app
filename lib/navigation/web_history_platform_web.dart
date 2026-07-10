import 'dart:async';
import 'dart:html' as html;

typedef BrowserBackCallback = FutureOr<bool> Function();

class WebHistoryPlatform {
  static BrowserBackCallback? _onBack;
  static StreamSubscription<html.PopStateEvent>? _subscription;

  static bool _initialized = false;
  static bool _handlingBrowserBack = false;

  static void initialize(BrowserBackCallback onBack) {
    _onBack = onBack;

    if (_initialized) return;

    _initialized = true;

    try {
      html.window.history.replaceState(
        <String, Object>{'appstroy': true, 'base': true},
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
  }

  static void pushRoute() {
    // Не пишем каждый экран Flutter в browser history.
    // На мобильном свайп назад может проскочить сразу несколько history entries.
    // Поэтому держим только один защитный слой и делаем ровно один Navigator.pop().
  }

  static void appRoutePopped() {
    // Обычная стрелка назад внутри Flutter не должна двигать browser history.
  }

  static void _handlePopState(html.PopStateEvent event) {
    if (_handlingBrowserBack) return;

    _handlingBrowserBack = true;

    Future<bool>.sync(() async {
      final callback = _onBack;
      if (callback == null) return false;

      return await callback();
    }).whenComplete(() {
      _pushGuardState();

      scheduleMicrotask(() {
        _handlingBrowserBack = false;
      });
    });
  }

  static void _pushGuardState() {
    try {
      html.window.history.pushState(
        <String, Object>{'appstroy': true, 'guard': true},
        html.document.title,
        html.window.location.href,
      );
    } catch (_) {}
  }
}
