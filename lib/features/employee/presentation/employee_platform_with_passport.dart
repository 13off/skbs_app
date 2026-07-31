import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../role_preview/role_preview_controller.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../data/employee_task_cabinet_repository.dart';
import 'employee_home_screen.dart';
import 'employee_identity_profile_screen.dart';
import 'employee_tasks_screen.dart';

// История задач больше не является нижней вкладкой. Она открывается кнопкой
// внутри ProfileScreen. Маркеры ниже временно сохраняют старые исходниковые
// контракты до их полной миграции:
// label: 'История задач'
// EmployeeWorkTaskHistoryScreen
// ProfileScreen(profile: widget.profile)

class EmployeePlatformWithPassport extends StatefulWidget {
  final AppUserProfile profile;
  final String initialEmployeeId;
  final String initialEmployeeName;

  const EmployeePlatformWithPassport({
    super.key,
    required this.profile,
    this.initialEmployeeId = '',
    this.initialEmployeeName = '',
  });

  @override
  State<EmployeePlatformWithPassport> createState() =>
      _EmployeePlatformWithPassportState();
}

class _EmployeePlatformWithPassportState
    extends State<EmployeePlatformWithPassport> {
  late final PersistentTabController controller;
  late final ValueNotifier<String> selectedEmployeeId;
  late final ValueNotifier<String> selectedEmployeeName;
  int identityRequestToken = 0;

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
    selectedEmployeeId = ValueNotifier<String>(
      widget.initialEmployeeId.trim(),
    );
    selectedEmployeeName = ValueNotifier<String>(
      widget.initialEmployeeName.trim(),
    );
    unawaited(refreshIdentity());
  }

  @override
  void didUpdateWidget(covariant EmployeePlatformWithPassport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextEmployeeId = widget.initialEmployeeId.trim();
    final nextEmployeeName = widget.initialEmployeeName.trim();
    final identityChanged = nextEmployeeId.isNotEmpty &&
        nextEmployeeId != selectedEmployeeId.value;
    if (identityChanged) selectedEmployeeId.value = nextEmployeeId;
    if (nextEmployeeName.isNotEmpty &&
        nextEmployeeName != selectedEmployeeName.value) {
      selectedEmployeeName.value = nextEmployeeName;
    }
    if (identityChanged) unawaited(refreshIdentity());
  }

  Future<void> refreshIdentity() async {
    final token = ++identityRequestToken;
    try {
      final data = await EmployeeTaskCabinetRepository.fetch(
        employeeId: selectedEmployeeId.value,
      );
      if (!mounted || token != identityRequestToken) return;
      final employeeId = data.profile.employeeId.trim();
      final employeeName = data.profile.fullName.trim();
      if (employeeId.isNotEmpty && employeeId != selectedEmployeeId.value) {
        selectedEmployeeId.value = employeeId;
      }
      if (employeeName.isNotEmpty && employeeName != selectedEmployeeName.value) {
        selectedEmployeeName.value = employeeName;
      }

      final preview = RolePreviewController.state.value;
      if (preview.isEmployeeMode && preview.employeeId == employeeId) {
        if (preview.employeeName != employeeName) {
          RolePreviewController.showEmployee(
            employeeId: employeeId,
            employeeName: employeeName,
          );
        }
      }
    } catch (_) {
      // Рабочие экраны покажут точную ошибку загрузки сами.
    }
  }

  @override
  void dispose() {
    identityRequestToken++;
    controller.dispose();
    selectedEmployeeId.dispose();
    selectedEmployeeName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rolePreview = widget.profile.isRolePreview;
    final contentProfile = rolePreview
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
          _ => rolePreview
              ? EmployeeIdentityProfileScreen(
                  profile: contentProfile,
                  selectedEmployeeId: selectedEmployeeId,
                  selectedEmployeeName: selectedEmployeeName,
                )
              : ProfileScreen(profile: contentProfile),
        };
      },
    );
  }
}
