import 'package:flutter/widgets.dart';

import 'web_edge_swipe_platform_stub.dart'
    if (dart.library.html) 'web_edge_swipe_platform_web.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

typedef AppBackHandler = Future<bool> Function();

AppBackHandler? _activeBackHandler;

void setActiveAppBackHandler(AppBackHandler? handler) {
  _activeBackHandler = handler;
}

class AppWebHistoryObserver extends NavigatorObserver {
  // Историей браузера управляет оболочка приложения.
  // Свайп с левого края приходит из web/index.html отдельным событием.
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
    WebEdgeSwipePlatform.initialize(_popOneScreen);
  }

  @override
  void dispose() {
    WebEdgeSwipePlatform.dispose();
    super.dispose();
  }

  Future<void> _popOneScreen() async {
    final handler = _activeBackHandler;

    if (handler != null && await handler()) {
      return;
    }

    final navigator = appNavigatorKey.currentState;

    if (navigator == null || !navigator.canPop()) return;

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
