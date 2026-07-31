import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'employee_simple_work_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  late final PersistentTabController controller;
  late final ValueNotifier<String> selectedEmployeeId;

  static const items = <ProfessionalBottomNavigationItem>[
    ProfessionalBottomNavigationItem(
      label: 'Профиль',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'История задач',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    controller = PersistentTabController(pageCount: items.length);
    selectedEmployeeId = ValueNotifier<String>('');
  }

  @override
  void dispose() {
    controller.dispose();
    selectedEmployeeId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: controller,
      items: items,
      returnToFirstTabOnBack: true,
      navigationStorageKey: 'employee-profile',
      tabBuilder: (context, index) {
        if (index == 0) {
          return ProfileScreen(profile: widget.profile);
        }
        return EmployeeWorkTaskHistoryScreen(
          profile: widget.profile,
          selectedEmployeeId: selectedEmployeeId,
        );
      },
    );
  }
}
