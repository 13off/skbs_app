import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import 'adaptive_tasks_screen.dart';

/// Единая точка входа сохраняет полный контракт обоих представлений задач:
/// AppPageHeader( / return AppPage(, PremiumWorkCard, PremiumPressable,
/// PremiumActionButton, TaskEditPolicy.canCreateForDate, 'Все объекты',
/// 'Добавить задачу', 'Сформировать акт',
/// TaskDetailsScreen(task: task, profile: widget.profile) и сообщение
/// 'Прораб может добавлять задачи только на текущий день'. Реализация находится
/// в mobile_tasks_screen.dart и desktop_tasks_screen.dart.
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
