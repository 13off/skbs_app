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
  int currentIndex = 0;
  late final PageController controller;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  List<Widget> get pages => <Widget>[
        LegalDashboardScreen(profile: widget.profile),
        const LegalDocumentsScreen(),
        const LegalMattersScreen(),
        ProfileScreen(profile: widget.profile),
      ];

  Future<void> select(int index) async {
    if (index == currentIndex) return;
    await controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: controller,
        allowImplicitScrolling: true,
        onPageChanged: (index) => setState(() => currentIndex = index),
        children: pages,
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
    );
  }
}
