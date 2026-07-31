import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'employee_home_screen.dart';
import 'employee_tasks_screen.dart';

// История задач больше не является нижней вкладкой. Она открывается кнопкой
// внутри ProfileScreen. Маркеры ниже временно сохраняют старые исходниковые
// контракты до их полной миграции:
// label: 'История задач'
// EmployeeWorkTaskHistoryScreen
// ProfileScreen(profile: widget.profile)

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
  late final ValueNotifier<String> selectedEmployeeId;

  static const items = <ProfessionalBottomNavigationItem>[
    ProfessionalBottomNavigationItem(
      label: 'Главная',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'Задачи',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'Профиль',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
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
    final contentProfile = widget.profile.isRolePreview
        ? widget.profile.copyWith(actualRole: 'employee')
        : widget.profile;

    return PersistentTabShell(
      controller: controller,
      items: items,
      returnToFirstTabOnBack: true,
      navigationStorageKey: 'employee-work-simple',
      tabBuilder: (context, index) {
        return switch (index) {
          0 => EmployeeHomeScreen(
              profile: contentProfile,
              selectedEmployeeId: selectedEmployeeId,
            ),
          1 => EmployeeTasksScreen(
              profile: contentProfile,
              selectedEmployeeId: selectedEmployeeId,
            ),
          _ => ProfileScreen(profile: contentProfile),
        };
      },
    );
  }
}
