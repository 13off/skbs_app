import 'package:flutter/material.dart';

class OnboardingTargetRegistry {
  OnboardingTargetRegistry._();

  static final Map<int, GlobalKey> _professionalKeys = <int, GlobalKey>{};
  static final Map<int, GlobalKey> _employeeKeys = <int, GlobalKey>{};

  static GlobalKey professionalKey(int index) {
    return _professionalKeys.putIfAbsent(index, GlobalKey.new);
  }

  static GlobalKey employeeKey(int index) {
    return _employeeKeys.putIfAbsent(index, GlobalKey.new);
  }

  static Rect? professionalRect(int index) {
    return _rectFor(_professionalKeys[index]);
  }

  static Rect? employeeRect(int index) {
    return _rectFor(_employeeKeys[index]);
  }

  static Rect? _rectFor(GlobalKey? key) {
    final context = key?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
}
