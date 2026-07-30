import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/platform_tab_override_scope.dart';
import 'employee_team_screen.dart';
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
  bool openingTeam = false;

  Future<bool> openTeam(BuildContext context) async {
    if (openingTeam) return true;
    setState(() => openingTeam = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => widget.profile.isRolePreview
              ? const EmployeeTeamSeedDirectoryScreen()
              : const EmployeeTeamScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => openingTeam = false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformTabOverrideScope(
      storageKey: 'employee',
      overrides: <int, PlatformTabOverride>{
        4: PlatformTabOverride(
          label: 'Команда',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          onSelected: openTeam,
        ),
      },
      child: legacy.EmployeeMainScreen(profile: widget.profile),
    );
  }
}
