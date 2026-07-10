import 'dart:async';
import 'dart:html' as html;

typedef EdgeSwipeBackCallback = void Function();

class WebEdgeSwipePlatform {
  static EdgeSwipeBackCallback? _onBack;
  static StreamSubscription<html.Event>? _subscription;

  static void initialize(EdgeSwipeBackCallback onBack) {
    _onBack = onBack;

    _subscription ??= html.window.on['appstroy-swipe-back'].listen((_) {
      _onBack?.call();
    });
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _onBack = null;
  }
}
