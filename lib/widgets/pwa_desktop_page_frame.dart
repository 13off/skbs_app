import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_ui_tokens.dart';

/// Gives every wide PWA route the same physical outer margin.
class PwaDesktopPageFrame extends StatelessWidget {
  final Widget child;

  const PwaDesktopPageFrame({super.key, required this.child});

  static bool isApplied(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_PwaDesktopPageFrameScope>() !=
        null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final enabled = kIsWeb && media.size.width >= AppUi.desktopBreakpoint;
    if (!enabled) return child;

    const horizontal = AppUi.pageDesktopHorizontalPadding;
    final contentWidth = (media.size.width - horizontal * 2).clamp(
      0.0,
      double.infinity,
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontal),
        child: MediaQuery(
          data: media.copyWith(
            size: Size(contentWidth.toDouble(), media.size.height),
          ),
          child: _PwaDesktopPageFrameScope(child: child),
        ),
      ),
    );
  }
}

class _PwaDesktopPageFrameScope extends InheritedWidget {
  const _PwaDesktopPageFrameScope({required super.child});

  @override
  bool updateShouldNotify(_PwaDesktopPageFrameScope oldWidget) => false;
}
