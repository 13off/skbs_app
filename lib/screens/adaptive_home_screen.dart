import 'package:flutter/material.dart';

import '../features/milestones/presentation/milestone_home_overlay.dart';
import '../models/app_user_profile.dart';
import '../models/task_item_data.dart';
import 'adaptive_home_base_screen.dart' as base;

class AdaptiveHomeScreen extends StatelessWidget {
  static const double desktopBreakpoint = base.AdaptiveHomeScreen.desktopBreakpoint;

  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;
  final Future<void> Function() onOpenEmployees;
  final Future<void> Function() onOpenTimesheet;
  final Future<void> Function() onOpenTasks;
  final Future<void> Function(TaskItemData task) onOpenTask;
  final Future<void> Function() onOpenPayments;

  const AdaptiveHomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
    required this.onOpenEmployees,
    required this.onOpenTimesheet,
    required this.onOpenTasks,
    required this.onOpenTask,
    required this.onOpenPayments,
  });

  @override
  Widget build(BuildContext context) {
    return MilestoneHomeOverlay(
      profile: profile,
      selectedObjectName: selectedObjectName,
      child: base.AdaptiveHomeScreen(
        profile: profile,
        selectedObjectName: selectedObjectName,
        onObjectChanged: onObjectChanged,
        onOpenEmployees: onOpenEmployees,
        onOpenTimesheet: onOpenTimesheet,
        onOpenTasks: onOpenTasks,
        onOpenTask: onOpenTask,
        onOpenPayments: onOpenPayments,
      ),
    );
  }
}
