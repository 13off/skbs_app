import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import 'desktop_timesheet_screen.dart';
import 'timesheet_screen.dart';

class AdaptiveTimesheetScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final AppUserProfile profile;
  final String? selectedObjectName;

  const AdaptiveTimesheetScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktop =
            kIsWeb && constraints.maxWidth >= desktopBreakpoint;

        if (!useDesktop) {
          return TimesheetScreen(
            profile: profile,
            selectedObjectName: selectedObjectName,
          );
        }

        return DesktopTimesheetScreen(
          profile: profile,
          selectedObjectName: selectedObjectName,
        );
      },
    );
  }
}
