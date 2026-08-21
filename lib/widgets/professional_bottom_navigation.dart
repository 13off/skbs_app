import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_ui_tokens.dart';
import '../navigation/navigation_session.dart';
import '../navigation/platform_tab_override_scope.dart';
import 'liquid_glass.dart';
import 'premium_pressable_v3.dart';

const _darkNavigationPanelTint = Color(0x8047525D);
const _lightNavigationPanelTint = Color(0x66F1F4F7);
const _nativeDarkNavigationPanelTint = Color(0x3047525D);
const _nativeLightNavigationPanelTint = Color(0x24F1F4F7);

const _darkNavigationPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xCC5B646E), Color(0xB34A5662), Color(0x99404B56)],
  stops: [0, 0.55, 1],
);

const _lightNavigationPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xB3FFFFFF), Color(0x99F4F7FA), Color(0x80E9EEF4)],
  stops: [0, 0.55, 1],
);

const _nativeDarkNavigationPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x705B646E), Color(0x504A5662), Color(0x38404B56)],
  stops: [0, 0.55, 1],
);

const _nativeLightNavigationPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x70FFFFFF), Color(0x4DF4F7FA), Color(0x2EE9EEF4)],
  stops: [0, 0.55, 1],
);

class ProfessionalBottomNavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const ProfessionalBottomNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class ProfessionalBottomNavigation extends StatefulWidget {
  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String? storageKey;

  const ProfessionalBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.storageKey,
  });

  @override
  State<ProfessionalBottomNavigation> createState() =>
      _ProfessionalBottomNavigationState();
}

class _ProfessionalBottomNavigationState
    extends State<ProfessionalBottomNavigation> {
  late String platformKey;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    platformKey = resolvePlatformKey(widget.items, widget.storageKey);
    scheduleRestore();
  }

  @override
  void didUpdateWidget(covariant ProfessionalBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPlatformKey = resolvePlatformKey(widget.items, widget.storageKey);
    if (nextPlatformKey != platformKey) {
      platformKey = nextPlatformKey;
      restored = false;
      scheduleRestore();
      return;
    }
    if (restored && oldWidget.selectedIndex != widget.selectedIndex) {
      unawaited(
        NavigationSession.writeTabIndex(platformKey, widget.selectedIndex),
      );
    }
  }

  String resolvePlatformKey(
    List<ProfessionalBottomNavigationItem> items,
    String? explicitKey,
  ) {
    final cleanExplicitKey = explicitKey?.trim() ?? '';
    if (cleanExplicitKey.isNotEmpty) return cleanExplicitKey;
    final labels = items.map((item) => item.label).toSet();
    if (labels.contains('Люди')) return 'admin';
    if (labels.contains('Документы') && labels.contains('Вопросы')) {
      return 'lawyer';
    }
    if (labels.contains('Выплаты') && labels.contains('Отчёты')) {
      return 'accountant';
    }
    return 'foreman';
  }

  void scheduleRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || restored) return;
      final savedIndex = NavigationSession.readTabIndex(platformKey);
      restored = true;
      if (savedIndex == null ||
          savedIndex < 0 ||
          savedIndex >= widget.items.length) {
        unawaited(
          NavigationSession.writeTabIndex(platformKey, widget.selectedIndex),
        );
        return;
      }
      if (savedIndex != widget.selectedIndex) widget.onSelected(savedIndex);
    });
  }

  Future<void> handleSelected(int index) async {
    final override = PlatformTabOverrideScope.resolve(
      context,
      storageKey: platformKey,
      index: index,
    );
    final handler = override?.onSelected;
    if (handler != null) {
      final handled = await handler(context);
      if (!mounted || handled) return;
    }
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isDesktop = AppUi.usesDesktopNavigation(context);
    final nativeMobile = !kIsWeb && !isDesktop;
    final panelHeight = AppUi.navigationPanelHeight(context);
    final topSpacing = AppUi.navigationTopSpacing(context);
    final bottomSpacing = AppUi.navigationBottomSpacing(context);
    final outerBottomSpacing = nativeMobile ? 0.0 : bottomSpacing + bottomInset;
    final panelPadding = isDesktop
        ? const EdgeInsets.all(8)
        : nativeMobile
        ? EdgeInsets.fromLTRB(7, 7, 7, 7 + bottomInset)
        : const EdgeInsets.all(7);

    return SizedBox(
      key: const ValueKey('professional-bottom-navigation'),
      height: AppUi.navigationTotalHeight(context),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? AppUi.pageDesktopHorizontalPadding : 12,
            topSpacing,
            isDesktop ? AppUi.pageDesktopHorizontalPadding : 12,
            outerBottomSpacing,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop
                    ? AppUi.desktopNavigationMaxWidth
                    : double.infinity,
              ),
              child: LiquidGlassSurface(
                key: const ValueKey('professional-bottom-navigation-panel'),
                blur: !kIsWeb || isDesktop,
                blurSigma: nativeMobile ? 18 : (isDesktop ? 24 : 20),
                tint: nativeMobile
                    ? dark
                          ? _nativeDarkNavigationPanelTint
                          : _nativeLightNavigationPanelTint
                    : dark
                    ? _darkNavigationPanelTint
                    : _lightNavigationPanelTint,
                gradient: nativeMobile
                    ? dark
                          ? _nativeDarkNavigationPanelGradient
                          : _nativeLightNavigationPanelGradient
                    : dark
                    ? _darkNavigationPanelGradient
                    : _lightNavigationPanelGradient,
                borderColor: nativeMobile
                    ? Colors.white.withValues(alpha: dark ? 0.16 : 0.62)
                    : null,
                radius: isDesktop ? 34 : 29,
                padding: panelPadding,
                child: SizedBox(
                  key: const ValueKey('professional-bottom-navigation-items'),
                  height: panelHeight - (isDesktop ? 16 : 14),
                  child: Row(
                    children: List<Widget>.generate(widget.items.length, (
                      index,
                    ) {
                      final baseItem = widget.items[index];
                      final override = PlatformTabOverrideScope.resolve(
                        context,
                        storageKey: platformKey,
                        index: index,
                      );
                      final item = ProfessionalBottomNavigationItem(
                        label: override?.label ?? baseItem.label,
                        icon: override?.icon ?? baseItem.icon,
                        selectedIcon:
                            override?.selectedIcon ?? baseItem.selectedIcon,
                      );
                      final selected = index == widget.selectedIndex;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: PremiumPressable(
                            onTap: () => unawaited(handleSelected(index)),
                            pressedScale: 0.955,
                            hoverScale: isDesktop ? 1.014 : 1,
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedContainer(
                              duration: animationsDisabled
                                  ? Duration.zero
                                  : AppMotion.regular,
                              curve: AppMotion.interactionCurve,
                              height: double.infinity,
                              clipBehavior: Clip.hardEdge,
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 14 : 4,
                                vertical: isDesktop ? 6 : 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          scheme.primary.withValues(
                                            alpha: dark ? 0.31 : 0.18,
                                          ),
                                          scheme.primary.withValues(
                                            alpha: dark ? 0.10 : 0.06,
                                          ),
                                        ],
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(23),
                                border: Border.all(
                                  color: selected
                                      ? Colors.white.withValues(
                                          alpha: dark ? 0.12 : 0.60,
                                        )
                                      : Colors.transparent,
                                  width: 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: dark ? 0.19 : 0.10,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: -10,
                                          offset: const Offset(0, 8),
                                        ),
                                      ]
                                    : const <BoxShadow>[],
                              ),
                              child: isDesktop
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _NavigationIcon(
                                          item: item,
                                          selected: selected,
                                          size: 23,
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: _NavigationLabel(
                                            item: item,
                                            selected: selected,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    )
                                  : _MobileNavigationItem(
                                      item: item,
                                      selected: selected,
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationItem extends StatelessWidget {
  final ProfessionalBottomNavigationItem item;
  final bool selected;

  const _MobileNavigationItem({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavigationIcon(item: item, selected: selected, size: 23),
                  const SizedBox(height: 3),
                  _NavigationLabel(
                    item: item,
                    selected: selected,
                    fontSize: 10.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  final ProfessionalBottomNavigationItem item;
  final bool selected;
  final double size;

  const _NavigationIcon({
    required this.item,
    required this.selected,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: AppMotion.regular,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.78, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        selected ? item.selectedIcon : item.icon,
        key: ValueKey('${item.label}-$selected'),
        size: size,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

class _NavigationLabel extends StatelessWidget {
  final ProfessionalBottomNavigationItem item;
  final bool selected;
  final double fontSize;

  const _NavigationLabel({
    required this.item,
    required this.selected,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedDefaultTextStyle(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      style:
          theme.textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            fontSize: fontSize,
            height: 1,
            letterSpacing: -0.2,
          ) ??
          const TextStyle(),
      child: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }
}
