import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog = false,
    super.maintainState = true,
  }) : super(
         opaque: true,
         transitionDuration: const Duration(milliseconds: 190),
         reverseTransitionDuration: const Duration(milliseconds: 160),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final disabled =
               MediaQuery.maybeOf(context)?.disableAnimations ?? false;
           if (disabled) return child;
           final enter = CurvedAnimation(
             parent: animation,
             curve: const Cubic(0.22, 1, 0.36, 1),
             reverseCurve: const Cubic(0.4, 0, 1, 1),
           );

           // Keep the horizontal cue, but do not repaint the previous screen.
           return FadeTransition(
             opacity: Tween<double>(begin: 0.985, end: 1).animate(enter),
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0.035, 0),
                 end: Offset.zero,
               ).animate(enter),
               child: RepaintBoundary(child: child),
             ),
           );
         },
       );
}
