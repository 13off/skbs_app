import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/platform_tab_override_scope.dart';
import '../../../screens/profile_screen.dart';
import 'employee_team_tab_screen.dart';
import 'employee_unified_main_screen.dart' as legacy;
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
  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final contentProfile = profile.isRolePreview
        ? profile.copyWith(actualRole: 'employee')
        : profile;

    // EmployeeTeamScreen остаётся экраном карточки коллеги, а сама команда
    // встроена в пятую вкладку через EmployeeTeamTabScreen.
    return PlatformTabOverrideScope(
      storageKey: 'employee',
      rootHeaderTrailingBuilder: profile.isRolePreview
          ? null
          : (context) => IconButton.filledTonal(
                tooltip: 'Мой профиль',
                onPressed: () => _openProfile(context),
                icon: const Icon(Icons.person_outline_rounded),
              ),
      overrides: <int, PlatformTabOverride>{
        0: PlatformTabOverride(
          builder: (_) => EmployeeWorkHomeScreen(profile: contentProfile),
        ),
        1: PlatformTabOverride(
          builder: (_) => EmployeeWorkTasksScreen(profile: contentProfile),
        ),
        4: PlatformTabOverride(
          label: 'Команда',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          builder: (_) => EmployeeTeamTabScreen(profile: profile),
        ),
      },
      child: legacy.EmployeeMainScreen(profile: contentProfile),
    );
  }
}
