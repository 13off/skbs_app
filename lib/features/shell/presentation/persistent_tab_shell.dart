import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme_controller.dart';
import '../../../navigation/app_page_route.dart';
import '../../../navigation/navigation_session.dart';
import '../../../navigation/platform_tab_override_scope.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';

class PersistentTabController extends ChangeNotifier {
  final int pageCount;
  final List<GlobalKey<NavigatorState>> navigatorKeys;

  int currentIndex;
  bool _disposed = false;

  PersistentTabController({required this.pageCount, int initialIndex = 0})
    : assert(pageCount > 0),
      assert(initialIndex >= 0 && initialIndex < pageCount),
      currentIndex = initialIndex,
      navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
        pageCount,
        (_) => GlobalKey<NavigatorState>(),
      );

  NavigatorState? navigatorState(int index) {
    if (index < 0 || index >= pageCount) return null;
    return navigatorKeys[index].currentState;
  }

  Future<void> select(int index) async {
    if (_disposed || index < 0 || index >= pageCount) return;
    if (index == currentIndex) {
      final navigator = navigatorState(index);
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    }

    // Tabs are independent workspaces. Desktop and mobile both switch
    // immediately so heavyweight work screens are never animated together.
    currentIndex = index;
    notifyListeners();
  }

  Future<NavigatorState?> selectNavigator(int index) async {
    await select(index);
    if (_disposed) return null;
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed) return null;
    return navigatorState(index);
  }

  Future<bool> handleBack({required bool returnToFirstTab}) async {
    final navigator = navigatorState(currentIndex);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    if (returnToFirstTab && currentIndex != 0) {
      await select(0);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class PersistentTabShell extends StatefulWidget {
  static const double workDepth = 1.28;
  static const double workCardRadius = 22;

  /// A desktop shell needs enough room for both the permanent rail and the
  /// actual wide work canvas. Below this width we keep the compact navigation
  /// without forcing wide tables into a narrow center column.
  static const double desktopShellBreakpoint = 1280;
  static const double desktopRailWidth = 224;

  final PersistentTabController controller;
  final List<ProfessionalBottomNavigationItem> items;
  final IndexedWidgetBuilder tabBuilder;
  final bool returnToFirstTabOnBack;
  final ValueChanged<int>? onPageChanged;
  final String? navigationStorageKey;

  const PersistentTabShell({
    super.key,
    required this.controller,
    required this.items,
    required this.tabBuilder,
    this.returnToFirstTabOnBack = false,
    this.onPageChanged,
    this.navigationStorageKey,
  });

  @override
  State<PersistentTabShell> createState() => _PersistentTabShellState();
}

class _PersistentTabShellState extends State<PersistentTabShell> {
  final Map<int, Widget> _tabNavigators = <int, Widget>{};
  int _prewarmGeneration = 0;

  Widget workVisualScope({
    required Widget child,
    bool hidePageSubtitles = false,
  }) {
    return LiquidGlassStyleScope(
      depth: PersistentTabShell.workDepth,
      cardRadius: PersistentTabShell.workCardRadius,
      hidePageSubtitles: hidePageSubtitles,
      compactPageLayout: true,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _ensureTabBuilt(widget.controller.currentIndex);
    _scheduleTabPrewarm();
  }

  @override
  void didUpdateWidget(covariant PersistentTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _prewarmGeneration++;
      _tabNavigators.clear();
      widget.controller.addListener(_handleControllerChanged);
      _ensureTabBuilt(widget.controller.currentIndex);
      _scheduleTabPrewarm();
    }
  }

  @override
  void dispose() {
    _prewarmGeneration++;
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _ensureTabBuilt(int index) {
    _tabNavigators.putIfAbsent(index, () => _buildTabNavigator(index));
  }

  void _scheduleTabPrewarm() {
    final generation = ++_prewarmGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _prewarmGeneration) return;
      _prewarmNextTab(generation);
    });
  }

  void _prewarmNextTab(int generation) {
    if (!mounted || generation != _prewarmGeneration) return;

    int? nextIndex;
    for (var index = 0; index < widget.controller.pageCount; index++) {
      if (!_tabNavigators.containsKey(index)) {
        nextIndex = index;
        break;
      }
    }
    if (nextIndex == null) return;
    final indexToBuild = nextIndex;

    SchedulerBinding.instance.scheduleTask<void>(
      () {
        if (!mounted || generation != _prewarmGeneration) return;
        setState(() => _ensureTabBuilt(indexToBuild));

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _prewarmGeneration) return;
          _prewarmNextTab(generation);
        });
      },
      Priority.idle,
      debugLabel: 'AppStroy.prewarmTab.$indexToBuild',
    );
  }

  Widget _buildTabNavigator(int index) {
    return RepaintBoundary(
      child: Navigator(
        key: widget.controller.navigatorKeys[index],
        onGenerateRoute: (settings) => AppPageRoute<void>(
          settings: settings,
          builder: (context) => AnimatedBuilder(
            animation: AppThemeController.instance,
            builder: (context, _) {
              Theme.of(context);
              final storageKey = widget.navigationStorageKey;
              final override = storageKey == null
                  ? null
                  : PlatformTabOverrideScope.resolve(
                      context,
                      storageKey: storageKey,
                      index: index,
                    );
              final overrideBuilder = override?.builder;
              final rootPage = overrideBuilder != null
                  ? overrideBuilder(context)
                  : widget.tabBuilder(context, index);

              return workVisualScope(hidePageSubtitles: true, child: rootPage);
            },
          ),
        ),
      ),
    );
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final index = widget.controller.currentIndex;
    setState(() => _ensureTabBuilt(index));
    widget.onPageChanged?.call(index);
  }

  Widget _buildWorkspace(int activeIndex) {
    return IndexedStack(
      index: activeIndex,
      children: List<Widget>.generate(widget.controller.pageCount, (index) {
        final child = _tabNavigators[index];
        if (child == null) return const SizedBox.shrink();
        return TickerMode(enabled: index == activeIndex, child: child);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.items.length == widget.controller.pageCount);
    final activeIndex = widget.controller.currentIndex;
    final useDesktopShell =
        MediaQuery.sizeOf(context).width >=
        PersistentTabShell.desktopShellBreakpoint;

    return workVisualScope(
      // ignore: deprecated_member_use
      child: WillPopScope(
        onWillPop: () => widget.controller.handleBack(
          returnToFirstTab: widget.returnToFirstTabOnBack,
        ),
        child: AppSurfaceBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: useDesktopShell
                ? Row(
                    children: [
                      _DesktopTabRail(
                        width: PersistentTabShell.desktopRailWidth,
                        items: widget.items,
                        selectedIndex: activeIndex,
                        storageKey: widget.navigationStorageKey,
                        onSelected: widget.controller.select,
                      ),
                      Expanded(child: _buildWorkspace(activeIndex)),
                    ],
                  )
                : _buildWorkspace(activeIndex),
            bottomNavigationBar: useDesktopShell
                ? null
                : ProfessionalBottomNavigation(
                    items: widget.items,
                    selectedIndex: activeIndex,
                    storageKey: widget.navigationStorageKey,
                    onSelected: widget.controller.select,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTabRail extends StatefulWidget {
  final double width;
  final List<ProfessionalBottomNavigationItem> items;
  final int selectedIndex;
  final String? storageKey;
  final ValueChanged<int> onSelected;

  const _DesktopTabRail({
    required this.width,
    required this.items,
    required this.selectedIndex,
    required this.storageKey,
    required this.onSelected,
  });

  @override
  State<_DesktopTabRail> createState() => _DesktopTabRailState();
}

class _DesktopTabRailState extends State<_DesktopTabRail> {
  late String platformKey;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    platformKey = _resolvePlatformKey(widget.items, widget.storageKey);
    _scheduleRestore();
  }

  @override
  void didUpdateWidget(covariant _DesktopTabRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPlatformKey = _resolvePlatformKey(widget.items, widget.storageKey);
    if (nextPlatformKey != platformKey) {
      platformKey = nextPlatformKey;
      restored = false;
      _scheduleRestore();
      return;
    }
    if (restored && oldWidget.selectedIndex != widget.selectedIndex) {
      unawaited(
        NavigationSession.writeTabIndex(platformKey, widget.selectedIndex),
      );
    }
  }

  String _resolvePlatformKey(
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

  void _scheduleRestore() {
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

  Future<void> _handleSelected(int index) async {
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

  ProfessionalBottomNavigationItem _resolvedItem(int index) {
    final baseItem = widget.items[index];
    final override = PlatformTabOverrideScope.resolve(
      context,
      storageKey: platformKey,
      index: index,
    );
    return ProfessionalBottomNavigationItem(
      label: override?.label ?? baseItem.label,
      icon: override?.icon ?? baseItem.icon,
      selectedIcon: override?.selectedIcon ?? baseItem.selectedIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return SizedBox(
      key: const ValueKey('professional-desktop-navigation'),
      width: widget.width,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: dark ? 0.82 : 0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: dark ? 0.55 : 0.70,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.20 : 0.07),
                  blurRadius: 32,
                  spreadRadius: -14,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.apartment_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AppСтрой',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.35,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Рабочая панель',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: widget.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = _resolvedItem(index);
                        final selected = index == widget.selectedIndex;
                        return _DesktopNavigationTile(
                          item: item,
                          selected: selected,
                          onTap: () => unawaited(_handleSelected(index)),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                    child: Text(
                      'ПК-версия',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavigationTile extends StatelessWidget {
  final ProfessionalBottomNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNavigationTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
