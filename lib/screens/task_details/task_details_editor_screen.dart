import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/employee_repository.dart';
import '../../data/task_repository.dart';
import '../../features/developer/data/developer_policy_repository.dart';
import '../../features/developer/models/task_policy.dart';
import '../../features/milestones/presentation/task_milestone_picker.dart';
import '../../features/tasks/task_edit_policy.dart';
import '../../models/app_user_profile.dart';
import '../../models/employee.dart';
import '../../models/task_item_data.dart';

part 'task_details_actions.dart';
part 'task_details_loading.dart';
part 'task_details_sections.dart';
part 'task_details_view.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskItemData task;
  final AppUserProfile profile;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.profile,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late final TextEditingController axesController;
  late final TextEditingController workController;
  late final TextEditingController notDoneCommentController;

  late DateTime selectedDate;
  late String selectedStatus;
  String? selectedMilestoneId;
  String? selectedChecklistItemId;
  String? selectedChecklistTitle;
  bool isGoalTask = false;

  List<Employee> employees = <Employee>[];
  final Set<String> selectedAssigneeIds = <String>{};
  final Set<String> originalAssigneeIds = <String>{};
  List<TaskPhotoData> photos = <TaskPhotoData>[];
  final Map<String, Future<String>> signedUrlFutures =
      <String, Future<String>>{};
  int loadToken = 0;

  bool isLoading = false;
  bool isSaving = false;
  bool isPickingPhotos = false;
  TaskPolicy policy = TaskPolicy.defaults;
  String? deletingPhotoId;
  String? errorText;

  static const List<String> statuses = <String>[
    'Запланировано',
    'Выполнено',
  ];

  bool get canEdit => TaskEditPolicy.canEditTask(widget.profile, widget.task);
  bool get canEditDate =>
      TaskEditPolicy.canEditDate(widget.profile, widget.task);
  bool get canEditAxesWork =>
      TaskEditPolicy.canEditAxesWork(widget.profile, widget.task);
  bool get canEditAssignees =>
      TaskEditPolicy.canEditAssignees(widget.profile, widget.task);
  bool get canEditStatus =>
      TaskEditPolicy.canEditStatus(widget.profile, widget.task);
  bool get canDeleteTask =>
      TaskEditPolicy.canDeleteTask(widget.profile, widget.task);

  @override
  void initState() {
    super.initState();
    axesController = TextEditingController(text: widget.task.axes);
    workController = TextEditingController(text: widget.task.work);
    notDoneCommentController = TextEditingController(
      text: widget.task.notDoneComment,
    );
    selectedDate = widget.task.date;
    selectedStatus = statuses.contains(widget.task.status)
        ? widget.task.status
        : 'Запланировано';
    loadTaskDetails();
  }

  @override
  void dispose() {
    loadToken++;
    axesController.dispose();
    workController.dispose();
    notDoneCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildTaskDetailsView();
}
