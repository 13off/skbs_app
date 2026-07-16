import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import 'legal_dashboard_screen.dart';
import 'legal_documents_screen.dart';
import 'legal_matters_screen.dart';

// Юрист использует отдельную оболочку, чтобы не менять вкладки администратора и прораба.
class LegalMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const LegalMainScreen({super.key, required this.profile});

  @override
  State<LegalMainScreen> createState() => _LegalMainScreenState();
}

class _LegalMainScreenState extends State<LegalMainScreen> {
  static const int pageCount = 4;

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
      0 => LegalDashboardScreen(profile: widget.profile),
      1 => const LegalDocumentsScreen(),
      2 => const LegalMattersScreen(),
      3 => ProfileScreen(profile: widget.profile),
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
    );
  }
}
