import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../navigation/navigation_session.dart';
import 'liquid_glass.dart';
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
    widget.onSelected(index);
  }

  Widget buildIcon(
    BuildContext context,
    ProfessionalBottomNavigationItem item,
    bool selected,
    bool isDesktop,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox(
      width: isDesktop ? 34 : 31,
      height: isDesktop ? 34 : 30,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: animationsDisabled
            ? Duration.zero
            : const Duration(milliseconds: 360),
        curve: selected ? Curves.easeOutBack : Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -2.2 * value),
            child: Transform.scale(scale: 1 + 0.065 * value, child: child),
          );
        },
        child: AnimatedSwitcher(
          duration: animationsDisabled ? Duration.zero : AppMotion.regular,
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: AppMotion.exitCurve,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            selected ? item.selectedIcon : item.icon,
            key: ValueKey('${item.label}-$selected'),
            size: isDesktop ? 21 : 20,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isDesktop = screenWidth >= 880;
    final panelHeight = isDesktop ? 74.0 : 72.0;
    final topSpacing = isDesktop ? 9.0 : 5.0;
    final bottomSpacing = isDesktop ? 14.0 : 10.0;
    final totalHeight = panelHeight + topSpacing + bottomSpacing + bottomInset;

    return SizedBox(
      key: const ValueKey('professional-bottom-navigation'),
      height: totalHeight,
      child: Material(
        type: MaterialType.transparency,
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
                maxWidth: isDesktop ? 840 : double.infinity,
              ),
              child: LiquidGlassSurface(
                key: const ValueKey('professional-bottom-navigation-panel'),
                blur: true,
                blurSigma: isDesktop ? 18 : 14,
                radius: isDesktop ? 30 : 26,
                padding: EdgeInsets.all(isDesktop ? 7 : 6),
                child: SizedBox(
                  height: panelHeight - (isDesktop ? 14 : 12),
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
                            pressedScale: 0.965,
                            hoverScale: isDesktop ? 1.012 : 1,
                            borderRadius: BorderRadius.circular(22),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: selected ? 1 : 0),
                              duration: animationsDisabled
                                  ? Duration.zero
                                  : Duration(milliseconds: selected ? 420 : 190),
                              curve: selected
                                  ? Curves.easeOutBack
                                  : Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.965 + 0.035 * value,
                                  child: Container(
                                    height: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isDesktop ? 13 : 4,
                                      vertical: isDesktop ? 6 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: value <= 0.001
                                          ? null
                                          : LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                scheme.primary.withValues(
                                                  alpha:
                                                      (dark ? 0.28 : 0.16) * value,
                                                ),
                                                scheme.primary.withValues(
                                                  alpha:
                                                      (dark ? 0.14 : 0.075) * value,
                                                ),
                                              ],
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        19 + 3 * value,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha:
                                              (dark ? 0.10 : 0.52) * value,
                                        ),
                                        width: 0.7 + 0.5 * value,
                                      ),
                                      boxShadow: value <= 0.001
                                          ? const <BoxShadow>[]
                                          : [
                                              BoxShadow(
                                                color: scheme.primary.withValues(
                                                  alpha:
                                                      (dark ? 0.16 : 0.10) * value,
                                                ),
                                                blurRadius: 8 + 10 * value,
                                                spreadRadius: -8,
                                                offset: Offset(0, 3 + 5 * value),
                                              ),
                                            ],
                                    ),
                                    child: child,
                                  ),
                                );
                              },
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
      ),
    );
  }
}
