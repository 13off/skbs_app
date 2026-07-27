import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class PremiumScrollBehavior extends MaterialScrollBehavior {
  const PremiumScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const PremiumBouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Более заметная, но контролируемая iOS-пружина для всех платформ.
///
/// Она разрешает слегка вытянуть страницу за верхнюю и нижнюю границы, после
/// чего контент мягко возвращается на место. Работает также на Web/PWA.
class PremiumBouncingScrollPhysics extends BouncingScrollPhysics {
  const PremiumBouncingScrollPhysics({super.parent});

  @override
  PremiumBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PremiumBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.58,
    stiffness: 118,
    damping: 13.2,
  );

  @override
  double frictionFactor(double overscrollFraction) {
    return 0.68 * math.pow(1 - overscrollFraction, 2).toDouble();
  }
}
