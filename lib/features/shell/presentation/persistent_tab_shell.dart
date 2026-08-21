import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme_controller.dart';
import '../../../navigation/app_page_route.dart';
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

    // Bottom tabs are workspaces, not pages in one long carousel. Switching
    // immediately avoids painting two heavyweight screens during a transition.
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

        // Wait for this hidden tab to finish a real frame before scheduling the
        // next idle build. A post-frame handoff avoids Timer/Future.delayed
        // wakeups and keeps both production and widget tests free of pending
        // timers while still spreading prewarm work across frames.
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
              // PersistentTabShell keeps nested Navigators alive between tabs.
              // Rebuild only their page content when the theme changes, while
              // preserving the selected tab, route stack and screen state.
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

  @override
  Widget build(BuildContext context) {
    assert(widget.items.length == widget.controller.pageCount);
    final activeIndex = widget.controller.currentIndex;
    return workVisualScope(
      // ignore: deprecated_member_use
      child: WillPopScope(
        onWillPop: () => widget.controller.handleBack(
          returnToFirstTab: widget.returnToFirstTabOnBack,
        ),
        child: AppSurfaceBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: IndexedStack(
              index: activeIndex,
              children: List<Widget>.generate(widget.controller.pageCount, (
                index,
              ) {
                final child = _tabNavigators[index];
                if (child == null) return const SizedBox.shrink();
                return TickerMode(enabled: index == activeIndex, child: child);
              }),
            ),
            bottomNavigationBar: ProfessionalBottomNavigation(
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
