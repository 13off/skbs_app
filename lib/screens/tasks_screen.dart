import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import 'adaptive_tasks_screen.dart';

class TasksScreen extends StatelessWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const TasksScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTasksScreen(
      profile: profile,
      selectedObjectName: selectedObjectName,
    );
  }
}
