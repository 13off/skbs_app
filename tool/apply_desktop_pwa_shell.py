from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"Ожидался ровно один фрагмент в {path}, найдено: {count}"
        )
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


adaptive_navigation = r'''import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../navigation/navigation_session.dart';
import 'professional_bottom_navigation.dart';

class ProfessionalAdaptiveScaffold extends StatelessWidget {
  static const double desktopBreakpoint = 1100;

  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final String title;
  final String? subtitle;

  const ProfessionalAdaptiveScaffold({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;
        if (!isDesktop) {
          return Scaffold(
            body: body,
            bottomNavigationBar: ProfessionalBottomNavigation(
              items: items,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _ProfessionalDesktopNavigation(
                items: items,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                title: title,
                subtitle: subtitle,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _ProfessionalDesktopNavigation extends StatefulWidget {
  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String title;
  final String? subtitle;

  const _ProfessionalDesktopNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_ProfessionalDesktopNavigation> createState() =>
      _ProfessionalDesktopNavigationState();
}

class _ProfessionalDesktopNavigationState
    extends State<_ProfessionalDesktopNavigation> {
  late String platformKey;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    platformKey = resolvePlatformKey(widget.items);
    scheduleRestore();
  }

  @override
  void didUpdateWidget(covariant _ProfessionalDesktopNavigation oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                padding: const EdgeInsets.fromLTRB(22, 0, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (widget.subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
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
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: handleSelected,
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
                  destinations: widget.items
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
'''

Path('lib/widgets/professional_adaptive_navigation.dart').write_text(
    adaptive_navigation,
    encoding='utf-8',
)

premium_ui_path = Path('lib/widgets/premium_ui.dart')
premium_ui = premium_ui_path.read_text(encoding='utf-8')
export_line = "export 'professional_adaptive_navigation.dart';\n"
if export_line not in premium_ui:
    premium_ui_path.write_text(export_line + premium_ui, encoding='utf-8')

premium_old = r'''    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: Scaffold(
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: handlePointerDown,
          onPointerUp: handlePointerUp,
          onPointerCancel: (_) => topTapStart = null,
          child: PageView.builder(
            controller: pageController,
            itemCount: pageCount,
            allowImplicitScrolling: true,
            physics: supportsAppSwipes
                ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)
                : const NeverScrollableScrollPhysics(),
            onPageChanged: handlePageChanged,
            itemBuilder: (context, index) {
              return buildTabNavigator(index);
            },
          ),
        ),
        bottomNavigationBar: _PremiumBottomBar(
          items: tabItems,
          selectedIndex: activeIndex,
          onSelected: selectTab,
        ),
      ),
    );'''

premium_new = r'''    final navigationItems = tabItems
        .map(
          (item) => ProfessionalBottomNavigationItem(
            label: item.label,
            icon: item.icon,
            selectedIcon: item.selectedIcon,
          ),
        )
        .toList(growable: false);

    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: ProfessionalAdaptiveScaffold(
        title: widget.profile.isAdmin
            ? 'Платформа руководителя'
            : 'Платформа прораба',
        subtitle: widget.profile.isAdmin
            ? 'Компания и все объекты'
            : widget.profile.objectName,
        items: navigationItems,
        selectedIndex: activeIndex,
        onSelected: selectTab,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: handlePointerDown,
          onPointerUp: handlePointerUp,
          onPointerCancel: (_) => topTapStart = null,
          child: PageView.builder(
            controller: pageController,
            itemCount: pageCount,
            allowImplicitScrolling: true,
            physics: supportsAppSwipes
                ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)
                : const NeverScrollableScrollPhysics(),
            onPageChanged: handlePageChanged,
            itemBuilder: (context, index) {
              return buildTabNavigator(index);
            },
          ),
        ),
      ),
    );'''

replace_once(
    'lib/features/shell/presentation/premium_main_screen.dart',
    premium_old,
    premium_new,
)

premium_bar = r'''class _PremiumBottomBar extends StatelessWidget {
  final List<_TabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PremiumBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalBottomNavigation(
      items: items
          .map(
            (item) => ProfessionalBottomNavigationItem(
              label: item.label,
              icon: item.icon,
              selectedIcon: item.selectedIcon,
            ),
          )
          .toList(growable: false),
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}

'''
replace_once(
    'lib/features/shell/presentation/premium_main_screen.dart',
    premium_bar,
    '',
)

legal_old = r'''    return WillPopScope(
      onWillPop: handleBack,
      child: Scaffold(
        body: PageView.builder(
          controller: controller,
          itemCount: pageCount,
          allowImplicitScrolling: true,
          onPageChanged: (index) => setState(() => currentIndex = index),
          itemBuilder: (context, index) => buildTabNavigator(index),
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
          items: const <ProfessionalBottomNavigationItem>[
            ProfessionalBottomNavigationItem(
              label: 'Сегодня',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Документы',
              icon: Icons.description_outlined,
              selectedIcon: Icons.description_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Вопросы',
              icon: Icons.gavel_outlined,
              selectedIcon: Icons.gavel_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Профиль',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
            ),
          ],
          selectedIndex: currentIndex,
          onSelected: select,
        ),
      ),
    );'''

legal_new = r'''    return WillPopScope(
      onWillPop: handleBack,
      child: ProfessionalAdaptiveScaffold(
        title: 'Юридическая платформа',
        subtitle: 'Документы, вопросы и риски',
        items: const <ProfessionalBottomNavigationItem>[
          ProfessionalBottomNavigationItem(
            label: 'Сегодня',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Документы',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Вопросы',
            icon: Icons.gavel_outlined,
            selectedIcon: Icons.gavel_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Профиль',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
          ),
        ],
        selectedIndex: currentIndex,
        onSelected: select,
        body: PageView.builder(
          controller: controller,
          itemCount: pageCount,
          allowImplicitScrolling: true,
          onPageChanged: (index) => setState(() => currentIndex = index),
          itemBuilder: (context, index) => buildTabNavigator(index),
        ),
      ),
    );'''

replace_once(
    'lib/features/legal/presentation/legal_main_screen.dart',
    legal_old,
    legal_new,
)

accounting_old = r'''    return WillPopScope(
      onWillPop: handleBack,
      child: Scaffold(
        body: PageView.builder(
          controller: controller,
          itemCount: pageCount,
          allowImplicitScrolling: true,
          onPageChanged: (index) => setState(() => currentIndex = index),
          itemBuilder: (context, index) => buildTabNavigator(index),
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
          items: const <ProfessionalBottomNavigationItem>[
            ProfessionalBottomNavigationItem(
              label: 'Сегодня',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Выплаты',
              icon: Icons.payments_outlined,
              selectedIcon: Icons.payments_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Отчёты',
              icon: Icons.summarize_outlined,
              selectedIcon: Icons.summarize_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Профиль',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
            ),
          ],
          selectedIndex: currentIndex,
          onSelected: select,
        ),
      ),
    );'''

accounting_new = r'''    return WillPopScope(
      onWillPop: handleBack,
      child: ProfessionalAdaptiveScaffold(
        title: 'Платформа бухгалтера',
        subtitle: 'Выплаты, остатки и отчёты',
        items: const <ProfessionalBottomNavigationItem>[
          ProfessionalBottomNavigationItem(
            label: 'Сегодня',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Выплаты',
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Отчёты',
            icon: Icons.summarize_outlined,
            selectedIcon: Icons.summarize_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Профиль',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
          ),
        ],
        selectedIndex: currentIndex,
        onSelected: select,
        body: PageView.builder(
          controller: controller,
          itemCount: pageCount,
          allowImplicitScrolling: true,
          onPageChanged: (index) => setState(() => currentIndex = index),
          itemBuilder: (context, index) => buildTabNavigator(index),
        ),
      ),
    );'''

replace_once(
    'lib/features/accounting/presentation/accounting_main_screen.dart',
    accounting_old,
    accounting_new,
)

contract_test = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('широкая веб-версия использует боковую навигацию без изменения мобильной', () {
    final adaptive = source(
      'lib/widgets/professional_adaptive_navigation.dart',
    );
    expect(adaptive, contains('desktopBreakpoint = 1100'));
    expect(adaptive, contains('NavigationRail('));
    expect(adaptive, contains('ProfessionalBottomNavigation('));
    expect(adaptive, contains('NavigationSession.writeTabIndex'));

    for (final path in const [
      'lib/features/shell/presentation/premium_main_screen.dart',
      'lib/features/legal/presentation/legal_main_screen.dart',
      'lib/features/accounting/presentation/accounting_main_screen.dart',
    ]) {
      final contents = source(path);
      expect(contents, contains('ProfessionalAdaptiveScaffold('));
      expect(contents, contains('PageView.builder('));
    }

    expect(
      source('lib/widgets/premium_ui.dart'),
      contains("export 'professional_adaptive_navigation.dart';"),
    );
  });
}
'''
Path('test/desktop_pwa_shell_contract_test.dart').write_text(
    contract_test,
    encoding='utf-8',
)
