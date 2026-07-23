import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../dispatcher/presentation/dispatcher_settings_screen.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'data_governance_screen.dart';
import 'developer_panel_screen.dart';
import 'developer_system_screen.dart';
import 'role_permission_matrix_screen.dart';

class DeveloperMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DeveloperMainScreen({super.key, required this.profile});

  @override
  State<DeveloperMainScreen> createState() => _DeveloperMainScreenState();
}

class _DeveloperMainScreenState extends State<DeveloperMainScreen> {
  static const int pageCount = 6;
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

  Widget rootPage(int index) {
    return switch (index) {
      0 => DeveloperSystemScreen(profile: widget.profile),
      1 => const DispatcherSettingsScreen(),
      2 => DeveloperPanelScreen(profile: widget.profile),
      3 => const RolePermissionMatrixScreen(),
      4 => const DataGovernanceScreen(),
      5 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'developer',
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
          label: 'Права',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings_rounded,
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
      tabBuilder: (context, index) => rootPage(index),
    );
  }
}
