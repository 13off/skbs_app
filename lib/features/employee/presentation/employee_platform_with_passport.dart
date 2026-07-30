import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'employee_work_cabinet_screen.dart';

class EmployeePlatformWithPassport extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeePlatformWithPassport({
    super.key,
    required this.profile,
  });

  @override
  State<EmployeePlatformWithPassport> createState() =>
      _EmployeePlatformWithPassportState();
}

class _EmployeePlatformWithPassportState
    extends State<EmployeePlatformWithPassport> {
  late final PersistentTabController controller;

  static const items = <ProfessionalBottomNavigationItem>[
    ProfessionalBottomNavigationItem(
      label: 'Задачи',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
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
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentProfile = widget.profile.isRolePreview
        ? widget.profile.copyWith(actualRole: 'employee')
        : widget.profile;
    return PersistentTabShell(
      controller: controller,
      items: items,
      returnToFirstTabOnBack: true,
      navigationStorageKey: 'employee-work-simple',
      tabBuilder: (context, index) {
        if (index == 0) {
          return EmployeeWorkTasksScreen(profile: contentProfile);
        }
        return EmployeeWorkTaskHistoryScreen(profile: contentProfile);
      },
    );
  }
}
