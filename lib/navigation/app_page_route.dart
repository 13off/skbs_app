import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog = false,
    super.maintainState = true,
  }) : super(
         opaque: true,
         transitionDuration: const Duration(milliseconds: 260),
         reverseTransitionDuration: const Duration(milliseconds: 220),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final enter = CurvedAnimation(
             parent: animation,
             curve: const Cubic(0.22, 1, 0.36, 1),
             reverseCurve: const Cubic(0.4, 0, 1, 1),
           );
           final exit = CurvedAnimation(
             parent: secondaryAnimation,
             curve: const Cubic(0.22, 1, 0.36, 1),
           );

           return SlideTransition(
             position: Tween<Offset>(
               begin: const Offset(0.045, 0),
               end: Offset.zero,
             ).animate(enter),
             child: FadeTransition(
               opacity: Tween<double>(begin: 0.96, end: 1).animate(enter),
               child: SlideTransition(
                 position: Tween<Offset>(
                   begin: Offset.zero,
                   end: const Offset(-0.018, 0),
                 ).animate(exit),
                 child: child,
               ),
             ),
           );
         },
       );
}
