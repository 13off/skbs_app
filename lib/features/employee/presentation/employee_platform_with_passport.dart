import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/platform_tab_override_scope.dart';
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
  @override
  Widget build(BuildContext context) {
    // EmployeeTeamScreen remains represented by the embedded
    // EmployeeTeamTabScreen(profile: profile) workspace below.
    return PlatformTabOverrideScope(
      storageKey: 'employee',
      overrides: <int, PlatformTabOverride>{
        4: PlatformTabOverride(
          label: 'Команда',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          builder: (_) => EmployeeTeamTabScreen(profile: widget.profile),
        ),
      },
      child: legacy.EmployeeMainScreen(profile: widget.profile),
    );
  }
}
