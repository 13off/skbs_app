import 'dart:async';
import 'dart:html' as html;

typedef EdgeSwipeBackCallback = void Function();

class WebEdgeSwipePlatform {
  static const int _minimumEventGapMs = 450;

  static EdgeSwipeBackCallback? _onBack;
  static StreamSubscription<html.Event>? _subscription;
  static DateTime? _lastBackAt;

  static void initialize(EdgeSwipeBackCallback onBack) {
    _onBack = onBack;

    _subscription ??= html.window.on['appstroy-swipe-back'].listen((_) {
      final now = DateTime.now();
      final lastBackAt = _lastBackAt;

      if (lastBackAt != null &&
          now.difference(lastBackAt).inMilliseconds < _minimumEventGapMs) {
        return;
      }

      _lastBackAt = now;
      _onBack?.call();
    });
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _onBack = null;
    _lastBackAt = null;
  }
}
