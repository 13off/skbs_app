import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../dispatcher/presentation/dispatcher_settings_screen.dart';
import 'developer_panel_screen.dart';
import 'developer_system_screen.dart';
import 'task_governance_screen.dart';

class DeveloperMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DeveloperMainScreen({super.key, required this.profile});

  @override
  State<DeveloperMainScreen> createState() => _DeveloperMainScreenState();
}

class _DeveloperMainScreenState extends State<DeveloperMainScreen> {
  static const int pageCount = 5;

  int currentIndex = 0;
  late final PageController controller;
  late final List<GlobalKey<NavigatorState>> navigatorKeys;

  @override
  void initState() {
    super.initState();
    controller = PageController();
    navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      pageCount,
      (_) => GlobalKey<NavigatorState>(),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget rootPage(int index) {
    return switch (index) {
      0 => DeveloperSystemScreen(profile: widget.profile),
      1 => const DispatcherSettingsScreen(),
      2 => DeveloperPanelScreen(profile: widget.profile),
      3 => const TaskGovernanceScreen(),
      4 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  Widget buildTabNavigator(int index) {
    return Navigator(
      key: navigatorKeys[index],
      onGenerateRoute: (settings) => CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) => rootPage(index),
      ),
    );
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= pageCount) return;
    if (index == currentIndex) {
      final navigator = navigatorKeys[index].currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    }
    await controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> handleBack() async {
    final navigator = navigatorKeys[currentIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
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
              label: 'Система',
              icon: Icons.settings_suggest_outlined,
              selectedIcon: Icons.settings_suggest_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Диспетчер',
              icon: Icons.auto_awesome_outlined,
              selectedIcon: Icons.auto_awesome_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Ограничения',
              icon: Icons.rule_outlined,
              selectedIcon: Icons.rule_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Контроль',
              icon: Icons.manage_history_outlined,
              selectedIcon: Icons.manage_history_rounded,
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
    );
  }
}
