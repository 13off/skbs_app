import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

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

/// Мягкая iOS-подобная прокрутка для всех платформ.
///
/// Маленький жест продолжает движение без резкого обрыва, быстрые свайпы не
/// превращаются в неконтролируемый рывок, а выход за границу страницы плавно
/// возвращается на место. Работает также в Web/PWA.
class PremiumBouncingScrollPhysics extends BouncingScrollPhysics {
  const PremiumBouncingScrollPhysics({super.parent})
    : super(decelerationRate: ScrollDecelerationRate.normal);

  @override
  PremiumBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PremiumBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  /// Почти критически затухающая пружина: возврат остаётся живым, но не дёргает
  /// контент и не останавливается резко у границы.
  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.72,
    stiffness: 92,
    damping: 14.8,
  );

  /// Небольшие свайпы тоже получают инерцию, поэтому прокрутка не обрывается
  /// сразу после отпускания пальца.
  @override
  double get minFlingVelocity => 28;

  /// Ограничивает резкие ускорения при сильном свайпе или серии жестов.
  @override
  double get maxFlingVelocity => 7200;

  /// Последовательные свайпы подхватывают движение мягко, без внезапного скачка
  /// скорости, характерного для стандартной экспоненциальной формулы.
  @override
  double carriedMomentum(double existingVelocity) {
    final magnitude = math.min(
      0.00068 * math.pow(existingVelocity.abs(), 1.92),
      24000.0,
    );
    return existingVelocity.sign * magnitude;
  }

  /// В начале выхода за границу страница тянется свободнее, затем сопротивление
  /// нарастает постепенно. Это убирает ощущение жёсткого упора.
  @override
  double frictionFactor(double overscrollFraction) {
    return 0.74 * math.pow(1 - overscrollFraction, 2.15).toDouble();
  }
}
