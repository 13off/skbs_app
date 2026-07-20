import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_repository.dart';
import '../data/task_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../features/developer/models/task_policy.dart';
import '../features/milestones/presentation/task_milestone_picker.dart';
import '../features/tasks/presentation/task_assignee_controls.dart';
import '../features/tasks/presentation/task_photo_grid.dart';
import '../features/tasks/task_draft_support.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';

part 'task_create/task_create_actions.dart';
part 'task_create/task_create_loading.dart';
part 'task_create/task_create_sections.dart';
part 'task_create/task_create_view.dart';

class TaskCreateDraft {
  final TaskItemData task;
  final List<String> assigneeIds;
  final List<TaskPhotoFile> photos;

  const TaskCreateDraft({
    required this.task,
    required this.assigneeIds,
    required this.photos,
  });
}

class AddTaskScreen extends StatefulWidget {
  final DateTime initialDate;
  final String objectName;
  final String? initialMilestoneId;
  final String? initialChecklistItemId;
  final bool allowAnyDate;

  const AddTaskScreen({
    super.key,
    required this.initialDate,
    required this.objectName,
    this.initialMilestoneId,
    this.initialChecklistItemId,
    this.allowAnyDate = false,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController axesController = TextEditingController();
  final TextEditingController workController = TextEditingController();

  late DateTime selectedDate;

  List<Employee> employees = <Employee>[];
  final Set<String> selectedAssigneeIds = <String>{};
  final List<TaskPhotoFile> selectedPhotos = <TaskPhotoFile>[];
  String? selectedMilestoneId;
  String? selectedChecklistItemId;
  String? selectedChecklistTitle;
  bool isGoalTask = false;

  bool isLoadingEmployees = false;
  bool isPickingPhotos = false;
  bool isLoadingPolicy = true;
  TaskPolicy policy = TaskPolicy.defaults;
  String? errorText;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    selectedMilestoneId = widget.initialMilestoneId;
    selectedChecklistItemId = widget.initialChecklistItemId;
    isGoalTask = selectedMilestoneId?.trim().isNotEmpty == true;
    loadEmployees();
    loadPolicy();
  }

  @override
  void dispose() {
    axesController.dispose();
    workController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildTaskCreateView();
}
