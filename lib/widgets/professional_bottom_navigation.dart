import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../navigation/navigation_session.dart';
import 'premium_pressable_v3.dart';

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

class _DesktopNavigationSnapshot {
  final Object owner;
  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String platformKey;

  const _DesktopNavigationSnapshot({
    required this.owner,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.platformKey,
  });
}

class _DesktopNavigationRegistry {
  static final ValueNotifier<_DesktopNavigationSnapshot?> state =
      ValueNotifier<_DesktopNavigationSnapshot?>(null);

  static void update(_DesktopNavigationSnapshot snapshot) {
    state.value = snapshot;
  }

  static void clear(Object owner) {
    if (identical(state.value?.owner, owner)) {
      state.value = null;
    }
  }
}

class ProfessionalDesktopShell extends StatelessWidget {
  static const double desktopBreakpoint = 1100;

  final Widget child;

  const ProfessionalDesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopShell =
            kIsWeb && constraints.maxWidth >= desktopBreakpoint;
        if (!useDesktopShell) return child;

        return ValueListenableBuilder<_DesktopNavigationSnapshot?>(
          valueListenable: _DesktopNavigationRegistry.state,
          child: child,
          builder: (context, navigation, child) {
            if (navigation == null) return child!;

            return Row(
              children: [
                _ProfessionalDesktopSidebar(navigation: navigation),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: child!),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfessionalDesktopSidebar extends StatelessWidget {
  final _DesktopNavigationSnapshot navigation;

  const _ProfessionalDesktopSidebar({required this.navigation});

  String get platformTitle {
    return switch (navigation.platformKey) {
      'admin' => 'Платформа руководителя',
      'lawyer' => 'Юридическая платформа',
      'accountant' => 'Платформа бухгалтера',
      _ => 'Платформа прораба',
    };
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = navigation.selectedIndex >= 0 &&
            navigation.selectedIndex < navigation.items.length
        ? navigation.selectedIndex
        : 0;

    return Material(
      color: Colors.white.withValues(alpha: 0.98),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 244,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 18, 18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'AppСтрой',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 18, 14),
                child: Text(
                  platformTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: NavigationRail(
                  extended: true,
                  minWidth: 72,
                  minExtendedWidth: 243,
                  backgroundColor: Colors.transparent,
                  groupAlignment: -0.86,
                  selectedIndex: safeIndex,
                  onDestinationSelected: navigation.onSelected,
                  useIndicator: true,
                  indicatorColor: AppColors.surfaceSoft,
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.textPrimary,
                    size: 23,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  destinations: navigation.items
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 10, 18, 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.desktop_windows_outlined,
                      size: 17,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Режим для компьютера',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalBottomNavigation extends StatefulWidget {
  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const ProfessionalBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<ProfessionalBottomNavigation> createState() =>
      _ProfessionalBottomNavigationState();
}

class _ProfessionalBottomNavigationState
    extends State<ProfessionalBottomNavigation> {
  final Object desktopOwner = Object();
  late String platformKey;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    platformKey = resolvePlatformKey(widget.items);
    scheduleRestore();
    scheduleDesktopSync();
  }

  @override
  void didUpdateWidget(covariant ProfessionalBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextPlatformKey = resolvePlatformKey(widget.items);
    if (nextPlatformKey != platformKey) {
      platformKey = nextPlatformKey;
      restored = false;
      scheduleRestore();
      scheduleDesktopSync();
      return;
    }

    if (restored && oldWidget.selectedIndex != widget.selectedIndex) {
      unawaited(
        NavigationSession.writeTabIndex(platformKey, widget.selectedIndex),
      );
    }
    scheduleDesktopSync();
  }

  @override
  void dispose() {
    final owner = desktopOwner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _DesktopNavigationRegistry.clear(owner);
    });
    super.dispose();
  }

  String resolvePlatformKey(List<ProfessionalBottomNavigationItem> items) {
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

  void scheduleDesktopSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _DesktopNavigationRegistry.update(
        _DesktopNavigationSnapshot(
          owner: desktopOwner,
          items: List<ProfessionalBottomNavigationItem>.unmodifiable(
            widget.items,
          ),
          selectedIndex: widget.selectedIndex,
          onSelected: handleSelected,
          platformKey: platformKey,
        ),
      );
    });
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

      if (savedIndex != widget.selectedIndex) {
        widget.onSelected(savedIndex);
      }
    });
  }

  void handleSelected(int index) {
    unawaited(NavigationSession.writeTabIndex(platformKey, index));
    widget.onSelected(index);
  }

  Widget buildIcon(
    ProfessionalBottomNavigationItem item,
    bool selected,
    bool isDesktop,
  ) {
    return AnimatedContainer(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      width: isDesktop ? 36 : 31,
      height: isDesktop ? 36 : 30,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  blurRadius: 15,
                  spreadRadius: -5,
                  offset: const Offset(0, 7),
                ),
              ]
            : const [],
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.regular,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        child: Icon(
          selected ? item.selectedIcon : item.icon,
          key: ValueKey('${item.label}-$selected'),
          size: isDesktop ? 20 : 18,
          color: selected ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget buildLabel(
    BuildContext context,
    ProfessionalBottomNavigationItem item,
    bool selected,
    bool isDesktop,
  ) {
    return AnimatedDefaultTextStyle(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      style:
          Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: isDesktop ? 13 : 10.0,
            letterSpacing: isDesktop ? -0.1 : -0.2,
          ) ??
          const TextStyle(),
      child: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled ? Duration.zero : AppMotion.regular;
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (kIsWeb && screenWidth >= ProfessionalDesktopShell.desktopBreakpoint) {
      return const SizedBox(
        key: ValueKey('professional-bottom-navigation'),
        height: 0,
      );
    }

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isDesktop = screenWidth >= 880;
    final panelHeight = isDesktop ? 72.0 : 72.0;
    final topSpacing = isDesktop ? 8.0 : 4.0;
    final bottomSpacing = isDesktop ? 14.0 : 10.0;
    final totalHeight = panelHeight + topSpacing + bottomSpacing + bottomInset;

    return SizedBox(
      key: const ValueKey('professional-bottom-navigation'),
      height: totalHeight,
      child: Material(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 28 : 12,
            topSpacing,
            isDesktop ? 28 : 12,
            bottomSpacing + bottomInset,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 820 : double.infinity,
              ),
              child: Container(
                key: const ValueKey('professional-bottom-navigation-panel'),
                height: panelHeight,
                padding: EdgeInsets.all(isDesktop ? 8 : 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(isDesktop ? 23 : 26),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.96),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF17191C).withValues(alpha: 0.10),
                      blurRadius: isDesktop ? 30 : 24,
                      spreadRadius: -9,
                      offset: Offset(0, isDesktop ? 14 : 11),
                    ),
                  ],
                ),
                child: Row(
                  children: List<Widget>.generate(widget.items.length, (index) {
                    final item = widget.items[index];
                    final selected = index == widget.selectedIndex;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 3 : 2,
                        ),
                        child: PremiumPressable(
                          onTap: () => handleSelected(index),
                          pressedScale: 0.97,
                          hoverScale: isDesktop ? AppMotion.hoverScale : 1,
                          borderRadius: BorderRadius.circular(17),
                          child: AnimatedContainer(
                            duration: duration,
                            curve: AppMotion.interactionCurve,
                            height: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 13 : 4,
                              vertical: isDesktop ? 6 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.surfaceSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                              border: selected
                                  ? Border.all(
                                      color: AppColors.border.withValues(
                                        alpha: 0.92,
                                      ),
                                    )
                                  : null,
                            ),
                            child: isDesktop
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      buildIcon(item, selected, true),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: buildLabel(
                                          context,
                                          item,
                                          selected,
                                          true,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      buildIcon(item, selected, false),
                                      const SizedBox(height: 1),
                                      buildLabel(
                                        context,
                                        item,
                                        selected,
                                        false,
                                      ),
                                    ],
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
    );
  }
}
