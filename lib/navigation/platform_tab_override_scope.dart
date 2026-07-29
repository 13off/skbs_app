import 'dart:async';

import 'package:flutter/material.dart';

typedef PlatformTabOverrideHandler = FutureOr<bool> Function(
  BuildContext context,
);

class PlatformTabOverride {
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;
  final PlatformTabOverrideHandler? onSelected;

  const PlatformTabOverride({
    this.label,
    this.icon,
    this.selectedIcon,
    this.onSelected,
  });
}

class PlatformTabOverrideScope extends InheritedWidget {
  final String storageKey;
  final Map<int, PlatformTabOverride> overrides;

  const PlatformTabOverrideScope({
    super.key,
    required this.storageKey,
    required this.overrides,
    required super.child,
  });

  static PlatformTabOverride? resolve(
    BuildContext context, {
    required String storageKey,
    required int index,
  }) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PlatformTabOverrideScope>();
    if (scope == null || scope.storageKey != storageKey) return null;
    return scope.overrides[index];
  }

  @override
  bool updateShouldNotify(covariant PlatformTabOverrideScope oldWidget) {
    return storageKey != oldWidget.storageKey || overrides != oldWidget.overrides;
  }
}
