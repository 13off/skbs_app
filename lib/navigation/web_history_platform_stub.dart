import 'dart:async';

typedef BrowserBackCallback = FutureOr<bool> Function();

class WebHistoryPlatform {
  static void initialize(BrowserBackCallback onBack) {}

  static void dispose() {}

  static void pushRoute() {}

  static void appRoutePopped() {}
}
