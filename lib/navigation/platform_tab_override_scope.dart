import 'dart:async';

import 'package:flutter/material.dart';

typedef PlatformTabOverrideHandler =
    FutureOr<bool> Function(BuildContext context);

class PlatformTabOverride {
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;
  final PlatformTabOverrideHandler? onSelected;
  final WidgetBuilder? builder;

  const PlatformTabOverride({
    this.label,
    this.icon,
    this.selectedIcon,
    this.onSelected,
    this.builder,
  });
}

class PlatformTabOverrideScope extends InheritedWidget {
  final String storageKey;
  final Map<int, PlatformTabOverride> overrides;
  final WidgetBuilder? rootHeaderTrailingBuilder;

  const PlatformTabOverrideScope({
    super.key,
    required this.storageKey,
    required this.overrides,
    this.rootHeaderTrailingBuilder,
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

  static WidgetBuilder? resolveRootHeaderTrailing(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlatformTabOverrideScope>()
        ?.rootHeaderTrailingBuilder;
  }

  @override
  bool updateShouldNotify(covariant PlatformTabOverrideScope oldWidget) {
    return storageKey != oldWidget.storageKey ||
        overrides != oldWidget.overrides ||
        rootHeaderTrailingBuilder != oldWidget.rootHeaderTrailingBuilder;
  }
}
