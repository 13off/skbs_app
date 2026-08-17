import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'legal_base_complete_screen.dart';
import 'legal_documents_complete_screen.dart';
import 'legal_matters_complete_screen.dart';
import 'legal_today_complete_screen.dart';

// Рабочая оболочка юриста: очередь → база → документы → дела → профиль.
class LegalMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const LegalMainScreen({super.key, required this.profile});

  @override
  State<LegalMainScreen> createState() => _LegalMainScreenState();
}

class _LegalMainScreenState extends State<LegalMainScreen> {
  static const int pageCount = 5;
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

  Widget legalRoot(Widget child) {
    return LiquidGlassStyleScope(
      depth: 1.28,
      cardRadius: 22,
      hidePageSubtitles: true,
      compactPageLayout: true,
      child: child,
    );
  }

  Widget rootPage(int index) {
    return switch (index) {
      0 => legalRoot(LegalTodayCompleteScreen(profile: widget.profile)),
      1 => legalRoot(const LegalBaseCompleteScreen()),
      2 => legalRoot(const LegalDocumentsCompleteScreen()),
      3 => legalRoot(LegalMattersCompleteScreen(profile: widget.profile)),
      4 => LiquidGlassStyleScope(
          depth: 1,
          hidePageSubtitles: false,
          compactPageLayout: false,
          child: ProfileScreen(profile: widget.profile),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassStyleScope(
      depth: 1.28,
      cardRadius: 22,
      hidePageSubtitles: false,
      compactPageLayout: true,
      child: PersistentTabShell(
        controller: tabs,
        navigationStorageKey: 'lawyer',
        items: const <ProfessionalBottomNavigationItem>[
          ProfessionalBottomNavigationItem(
            label: 'Сегодня',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'База',
            icon: Icons.hub_outlined,
            selectedIcon: Icons.hub_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Документы',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description_rounded,
          ),
          ProfessionalBottomNavigationItem(
            label: 'Дела',
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
      ),
    );
  }
}
