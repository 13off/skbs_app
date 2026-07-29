import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/platform_tab_override_scope.dart';
import 'employee_passport_directory_screen.dart';
import 'employee_professional_passport_screen.dart';
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
  bool openingPassport = false;

  Future<bool> openPassport(BuildContext context) async {
    if (openingPassport) return true;
    setState(() => openingPassport = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => widget.profile.isRolePreview
              ? const EmployeePassportDirectoryScreen()
              : EmployeeProfessionalPassportScreen(profile: widget.profile),
        ),
      );
    } finally {
      if (mounted) setState(() => openingPassport = false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformTabOverrideScope(
      storageKey: 'employee',
      overrides: <int, PlatformTabOverride>{
        4: PlatformTabOverride(
          label: 'Паспорт',
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge_rounded,
          onSelected: openPassport,
        ),
      },
      child: legacy.EmployeeMainScreen(profile: widget.profile),
    );
  }
}
