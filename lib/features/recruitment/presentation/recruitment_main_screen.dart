import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import 'recruitment_applications_screen.dart';
import 'recruitment_dashboard_screen.dart';

class RecruitmentMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentMainScreen({
    super.key,
    required this.profile,
  });

  @override
  State<RecruitmentMainScreen> createState() => _RecruitmentMainScreenState();
}

class _RecruitmentMainScreenState extends State<RecruitmentMainScreen> {
  static const int pageCount = 3;

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
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: (_) {},
    );
  }

  @override
  void dispose() {
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    controller.dispose();
    super.dispose();
  }

  Widget rootPage(int index) {
    return switch (index) {
      0 => RecruitmentDashboardScreen(
          profile: widget.profile,
          onOpenApplications: () => select(1),
        ),
      1 => RecruitmentApplicationsScreen(profile: widget.profile),
      2 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  Widget buildTabNavigator(int index) {
    return Navigator(
      key: navigatorKeys[index],
      onGenerateRoute: (settings) {
        return CupertinoPageRoute<void>(
          settings: settings,
          builder: (_) => rootPage(index),
        );
      },
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
              label: 'Сегодня',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Заявки',
              icon: Icons.view_kanban_outlined,
              selectedIcon: Icons.view_kanban_rounded,
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
