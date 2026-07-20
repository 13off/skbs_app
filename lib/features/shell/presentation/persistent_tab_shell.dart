import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';

class PersistentTabController {
  final int pageCount;
  final PageController pageController;
  final List<GlobalKey<NavigatorState>> navigatorKeys;

  int currentIndex;
  bool _disposed = false;

  PersistentTabController({
    required this.pageCount,
    int initialIndex = 0,
  })  : assert(pageCount > 0),
        assert(initialIndex >= 0 && initialIndex < pageCount),
        currentIndex = initialIndex,
        pageController = PageController(initialPage: initialIndex),
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

    await pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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

  void updateCurrentIndex(int index) {
    if (_disposed || index < 0 || index >= pageCount) return;
    currentIndex = index;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pageController.dispose();
  }
}

class PersistentTabShell extends StatefulWidget {
  final PersistentTabController controller;
  final List<ProfessionalBottomNavigationItem> items;
  final IndexedWidgetBuilder tabBuilder;
  final bool returnToFirstTabOnBack;
  final ValueChanged<int>? onPageChanged;

  const PersistentTabShell({
    super.key,
    required this.controller,
    required this.items,
    required this.tabBuilder,
    this.returnToFirstTabOnBack = false,
    this.onPageChanged,
  });

  @override
  State<PersistentTabShell> createState() => _PersistentTabShellState();
}

class _PersistentTabShellState extends State<PersistentTabShell> {
  Widget tabNavigator(int index) {
    return Navigator(
      key: widget.controller.navigatorKeys[index],
      onGenerateRoute: (settings) => CupertinoPageRoute<void>(
        settings: settings,
        builder: (context) => widget.tabBuilder(context, index),
      ),
    );
  }

  void handlePageChanged(int index) {
    widget.controller.updateCurrentIndex(index);
    widget.onPageChanged?.call(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.items.length == widget.controller.pageCount);
    return WillPopScope(
      onWillPop: () => widget.controller.handleBack(
        returnToFirstTab: widget.returnToFirstTabOnBack,
      ),
      child: Scaffold(
        body: PageView.builder(
          controller: widget.controller.pageController,
          itemCount: widget.controller.pageCount,
          allowImplicitScrolling: true,
          onPageChanged: handlePageChanged,
          itemBuilder: (context, index) => tabNavigator(index),
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
          items: widget.items,
          selectedIndex: widget.controller.currentIndex,
          onSelected: widget.controller.select,
        ),
      ),
    );
  }
}
