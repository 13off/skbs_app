import 'dart:async';

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

      if (savedIndex != widget.selectedIndex) {
        widget.onSelected(savedIndex);
      }
    });
  }

  void handleSelected(int index) {
    // didUpdateWidget persists the final selected index once. Writing here as
    // well caused two SharedPreferences operations for every bottom-tab tap.
    widget.onSelected(index);
  }

  Widget buildIcon(
    BuildContext context,
    ProfessionalBottomNavigationItem item,
    bool selected,
    bool isDesktop,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: isDesktop ? 34 : 31,
      height: isDesktop ? 34 : 30,
      child: AnimatedSwitcher(
        duration: AppMotion.regular,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        child: Icon(
          selected ? item.selectedIcon : item.icon,
          key: ValueKey('${item.label}-$selected'),
          size: isDesktop ? 21 : 20,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedDefaultTextStyle(
      duration: AppMotion.regular,
      curve: AppMotion.interactionCurve,
      style:
          theme.textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: isDesktop ? 13 : 10.5,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled ? Duration.zero : AppMotion.regular;
    final screenWidth = MediaQuery.sizeOf(context).width;
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
        color: theme.scaffoldBackgroundColor,
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
                padding: EdgeInsets.all(isDesktop ? 7 : 6),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(isDesktop ? 21 : 24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: dark ? 0.95 : 0.72,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.22 : 0.08),
                      blurRadius: isDesktop ? 20 : 18,
                      spreadRadius: -10,
                      offset: Offset(0, isDesktop ? 10 : 8),
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
                          borderRadius: BorderRadius.circular(16),
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
                                  ? scheme.primary.withValues(alpha: 0.11)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: selected
                                  ? Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: dark ? 0.22 : 0.16,
                                      ),
                                    )
                                  : null,
                            ),
                            child: isDesktop
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      buildIcon(context, item, selected, true),
                                      const SizedBox(width: 9),
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
                                      buildIcon(context, item, selected, false),
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
