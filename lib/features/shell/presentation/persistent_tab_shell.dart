import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

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
    // immediately avoids painting two heavyweight screens during 280 ms.
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _ensureTabBuilt(widget.controller.currentIndex);
  }

  @override
  void didUpdateWidget(covariant PersistentTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _tabNavigators.clear();
      widget.controller.addListener(_handleControllerChanged);
      _ensureTabBuilt(widget.controller.currentIndex);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _ensureTabBuilt(int index) {
    _tabNavigators.putIfAbsent(index, () => _buildTabNavigator(index));
  }

  Widget _buildTabNavigator(int index) {
    return RepaintBoundary(
      child: Navigator(
        key: widget.controller.navigatorKeys[index],
        onGenerateRoute: (settings) => CupertinoPageRoute<void>(
          settings: settings,
          builder: (context) => widget.tabBuilder(context, index),
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
    return WillPopScope(
      onWillPop: () => widget.controller.handleBack(
        returnToFirstTab: widget.returnToFirstTabOnBack,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: activeIndex,
          children: List<Widget>.generate(widget.controller.pageCount, (index) {
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
    );
  }
}
