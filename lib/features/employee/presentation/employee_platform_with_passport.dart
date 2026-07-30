import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/platform_tab_override_scope.dart';
import '../../../screens/profile_screen.dart';
import '../../role_preview/role_preview_controller.dart';
import 'employee_actionable_tasks.dart';
import 'employee_dashboard_screen.dart';
import 'employee_team_tab_screen.dart';
import 'employee_unified_main_screen.dart' as legacy;

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
  Future<void> _openProfile(BuildContext context) async {
    if (widget.profile.isRolePreview) {
      RolePreviewController.showAdmin();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    // The established shell, timesheet and documents stay intact. Only the
    // employee-facing workspaces below replace their previous read-only views.
    // EmployeeTeamScreen remains represented by EmployeeTeamTabScreen.
    return PlatformTabOverrideScope(
      storageKey: 'employee',
      rootHeaderTrailingBuilder: (context) => IconButton.filledTonal(
        tooltip: widget.profile.isRolePreview
            ? 'Вернуться к руководителю'
            : 'Мой профиль',
        onPressed: () => _openProfile(context),
        icon: Icon(
          widget.profile.isRolePreview
              ? Icons.admin_panel_settings_outlined
              : Icons.person_outline_rounded,
        ),
      ),
      overrides: <int, PlatformTabOverride>{
        0: PlatformTabOverride(
          builder: (_) => EmployeeDashboardScreen(profile: profile),
        ),
        1: PlatformTabOverride(
          builder: (_) => EmployeeActionableTasksScreen(profile: profile),
        ),
        4: PlatformTabOverride(
          label: 'Команда',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          builder: (_) => EmployeeTeamTabScreen(profile: profile),
        ),
      },
      child: legacy.EmployeeMainScreen(profile: widget.profile),
    );
  }
}
