import 'package:flutter/widgets.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppWebHistoryObserver extends NavigatorObserver {
  // Browser history больше не трогаем.
  // На мобильном вебе это давало долгую перерисовку после свайпа.
}

class AppBrowserBackBridge extends StatefulWidget {
  const AppBrowserBackBridge({super.key, required this.child});

  final Widget child;

  @override
  State<AppBrowserBackBridge> createState() => _AppBrowserBackBridgeState();
}

class _AppBrowserBackBridgeState extends State<AppBrowserBackBridge> {
  static const double _edgeWidth = 28;
  static const double _minSwipeDistance = 72;

  double _startX = 0;
  double _startY = 0;
  double _deltaX = 0;
  double _deltaY = 0;

  void _resetSwipe() {
    _startX = 0;
    _startY = 0;
    _deltaX = 0;
    _deltaY = 0;
  }

  bool _canPop() {
    final navigator = appNavigatorKey.currentState;

    return navigator != null && navigator.canPop();
  }

  void _popOneScreen() {
    final navigator = appNavigatorKey.currentState;

    if (navigator == null || !navigator.canPop()) return;

    navigator.pop();
  }

  bool get _isBackSwipe {
    return _deltaX >= _minSwipeDistance &&
        _deltaX.abs() > _deltaY.abs() * 1.35;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) {
              _resetSwipe();

              if (!_canPop()) return;

              _startX = details.globalPosition.dx;
              _startY = details.globalPosition.dy;
            },
            onHorizontalDragUpdate: (details) {
              if (!_canPop()) return;

              _deltaX = details.globalPosition.dx - _startX;
              _deltaY = details.globalPosition.dy - _startY;
            },
            onHorizontalDragEnd: (_) {
              if (_canPop() && _isBackSwipe) {
                _popOneScreen();
              }

              _resetSwipe();
            },
            onHorizontalDragCancel: _resetSwipe,
          ),
        ),
      ],
    );
  }
}
