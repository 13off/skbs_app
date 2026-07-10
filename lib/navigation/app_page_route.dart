import 'package:flutter/cupertino.dart';

class AppPageRoute<T> extends CupertinoPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.title,
    super.fullscreenDialog = false,
    super.maintainState = true,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 270);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 230);
}
