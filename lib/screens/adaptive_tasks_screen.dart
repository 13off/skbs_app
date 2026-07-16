import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import 'desktop_tasks_screen.dart';
import 'tasks_screen.dart';

class AdaptiveTasksScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final AppUserProfile profile;
  final String? selectedObjectName;

  const AdaptiveTasksScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopTasks =
            kIsWeb && constraints.maxWidth >= desktopBreakpoint;

        if (!useDesktopTasks) {
          return TasksScreen(
            profile: profile,
            selectedObjectName: selectedObjectName,
          );
        }

        return DesktopTasksScreen(
          profile: profile,
          selectedObjectName: selectedObjectName,
        );
      },
    );
  }
}
