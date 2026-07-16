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
  late String platformKey;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    platformKey = resolvePlatformKey(widget.items);
    scheduleRestore();
  }

  @override
  void didUpdateWidget(covariant ProfessionalBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextPlatformKey = resolvePlatformKey(widget.items);
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
