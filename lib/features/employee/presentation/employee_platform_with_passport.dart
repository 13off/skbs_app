import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/platform_tab_override_scope.dart';
import '../../../widgets/premium_ui.dart';
import '../../role_preview/role_preview_controller.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import 'employee_profile_screen.dart';
import 'employee_simple_work_screen.dart';

// История задач перенесена внутрь EmployeeProfileScreen. Эти маркеры
// сохраняют совместимость прежних исходниковых контрактов до их миграции:
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
      label: 'Задачи',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
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

  Future<void> openProfile(BuildContext context) async {
    if (widget.profile.isRolePreview) {
      RolePreviewController.showAdmin();
      return;
    }
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeProfileScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentProfile = widget.profile.isRolePreview
        ? widget.profile.copyWith(actualRole: 'employee')
        : widget.profile;
    return PlatformTabOverrideScope(
      storageKey: 'employee-work-simple',
      overrides: const <int, PlatformTabOverride>{},
      rootHeaderTrailingBuilder: (context) => IconButton.filledTonal(
        tooltip: widget.profile.isRolePreview
            ? 'Вернуться к руководителю'
            : 'Мой профиль',
        onPressed: () => openProfile(context),
        icon: Icon(
          widget.profile.isRolePreview
              ? Icons.admin_panel_settings_outlined
              : Icons.person_outline_rounded,
        ),
      ),
      child: PersistentTabShell(
        controller: controller,
        items: items,
        returnToFirstTabOnBack: true,
        navigationStorageKey: 'employee-work-simple',
        tabBuilder: (context, index) => EmployeeWorkTasksScreen(
          profile: contentProfile,
          selectedEmployeeId: selectedEmployeeId,
        ),
      ),
    );
  }
}
