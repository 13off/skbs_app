import 'dart:async';

import 'package:flutter/widgets.dart';

import 'web_history_platform_stub.dart'
    if (dart.library.html) 'web_history_platform_web.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppWebHistoryObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (previousRoute != null) {
      WebHistoryPlatform.pushRoute();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    WebHistoryPlatform.appRoutePopped();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    WebHistoryPlatform.appRoutePopped();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (oldRoute == null && newRoute != null) {
      WebHistoryPlatform.pushRoute();
    }
  }
}

class AppBrowserBackBridge extends StatefulWidget {
  const AppBrowserBackBridge({super.key, required this.child});

  final Widget child;

  @override
  State<AppBrowserBackBridge> createState() => _AppBrowserBackBridgeState();
}

class _AppBrowserBackBridgeState extends State<AppBrowserBackBridge> {
  @override
  void initState() {
    super.initState();

    WebHistoryPlatform.initialize(_handleBrowserBack);
  }

  @override
  void dispose() {
    WebHistoryPlatform.dispose();

    super.dispose();
  }

  FutureOr<bool> _handleBrowserBack() {
    final navigator = appNavigatorKey.currentState;

    if (navigator == null || !navigator.canPop()) return false;

    navigator.pop();

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
