import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../models/legal_models.dart';
import 'adaptive_legal_dashboard_screen.dart';
import 'adaptive_legal_documents_screen.dart';
import 'adaptive_legal_matters_screen.dart';
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
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: pageCount);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> select(int index) => tabs.select(index);

  Widget rootPage(int index) {
    return switch (index) {
      0 => AdaptiveLegalDashboardScreen(
        profile: widget.profile,
        onOpenDocuments: () => select(1),
        onOpenMatters: () => select(2),
        onOpenDocument: openDocumentFromDashboard,
        onOpenMatter: openMatterFromDashboard,
      ),
      1 => const AdaptiveLegalDocumentsScreen(),
      2 => AdaptiveLegalMattersScreen(profile: widget.profile),
      3 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  Future<NavigatorState?> selectTabNavigator(int index) async {
    final navigator = await tabs.selectNavigator(index);
    if (!mounted) return null;
    return navigator;
  }

  Future<void> openDocumentFromDashboard(LegalDocument document) async {
    final navigator = await selectTabNavigator(1);
    if (navigator == null) return;
    await navigator.push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => LegalDocumentDetailsScreen(document: document),
      ),
    );
  }

  Future<void> openMatterFromDashboard(LegalMatter matter) async {
    final navigator = await selectTabNavigator(2);
    if (navigator == null) return;
    await navigator.push<void>(
      CupertinoPageRoute<void>(
        builder: (_) =>
            LegalMatterDetailsScreen(matter: matter, canDecide: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'lawyer',
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
      tabBuilder: (context, index) => rootPage(index),
    );
  }
}
