import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef EdgeSwipeBackCallback = void Function();

class WebEdgeSwipePlatform {
  static const int _minimumEventGapMs = 450;
  static const String _eventName = 'appstroy-swipe-back';

  static EdgeSwipeBackCallback? _onBack;
  static web.EventListener? _listener;
  static DateTime? _lastBackAt;

  static void initialize(EdgeSwipeBackCallback onBack) {
    _onBack = onBack;
    if (_listener != null) return;

    final listener = ((web.Event _) {
      final now = DateTime.now();
      final lastBackAt = _lastBackAt;

      if (lastBackAt != null &&
          now.difference(lastBackAt).inMilliseconds < _minimumEventGapMs) {
        return;
      }

      _lastBackAt = now;
      _onBack?.call();
    }).toJS;
    _listener = listener;
    web.window.addEventListener(_eventName, listener);
  }

  static void dispose() {
    final listener = _listener;
    if (listener != null) {
      web.window.removeEventListener(_eventName, listener);
    }
    _listener = null;
    _onBack = null;
    _lastBackAt = null;
  }
}
