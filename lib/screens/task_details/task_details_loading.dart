part of '../task_details_legacy_screen.dart';

extension _TaskDetailsLoading on _TaskDetailsScreenState {
  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String assigneeTitle() {
    if (selectedAssigneeIds.isEmpty) {
      return 'Исполнители не выбраны';
    }
    return 'Выбрано: ${selectedAssigneeIds.length}';
  }

  String selectedEmployeeNames() {
    final selectedEmployees = employees.where((employee) {
      return employee.id != null && selectedAssigneeIds.contains(employee.id);
    }).toList();

    if (selectedEmployees.isEmpty) {
      return 'Нажмите, чтобы выбрать сотрудников';
    }
    return selectedEmployees.map((employee) => employee.name).join(', ');
  }

  Future<String> signedUrlFuture(TaskPhotoData photo) {
    return signedUrlFutures.putIfAbsent(
      photo.id,
      () => TaskRepository.createTaskPhotoSignedUrl(photo),
    );
  }

  Future<void> loadTaskDetails() async {
    final taskId = widget.task.id;
    if (taskId == null || taskId.isEmpty) return;

    final token = ++loadToken;
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await Future.wait<dynamic>(<Future<dynamic>>[
        EmployeeRepository.fetchEmployees(objectName: widget.task.objectName),
        TaskRepository.fetchTaskAssigneeIds(taskId),
        TaskRepository.fetchTaskPhotos(taskId),
        TaskRepository.fetchTaskMilestoneLink(taskId),
        DeveloperPolicyRepository.ensurePolicy(widget.task.objectName),
      ]);

      if (!mounted || token != loadToken) return;

      final loadedEmployees = result[0] as List<Employee>;
      final loadedAssigneeIds = TaskRepository.cleanAssigneeIdSet(
        result[1] as List<String>,
      );
      final loadedPhotos = result[2] as List<TaskPhotoData>;
      final loadedMilestoneLink = result[3] as TaskMilestoneLinkData?;
      final loadedPolicy = result[4] as TaskPolicy;

      setState(() {
        employees = loadedEmployees.where((employee) {
          return employee.id != null && employee.id!.isNotEmpty;
        }).toList();
        selectedAssigneeIds
          ..clear()
          ..addAll(loadedAssigneeIds);
        originalAssigneeIds
          ..clear()
          ..addAll(loadedAssigneeIds);
        photos = loadedPhotos;
        selectedMilestoneId = loadedMilestoneLink?.milestoneId;
        selectedChecklistItemId = loadedMilestoneLink?.checklistItemId;
        isGoalTask = loadedMilestoneLink != null;
        policy = loadedPolicy;
        signedUrlFutures.clear();
        isLoading = false;
        errorText = null;
      });
    } catch (error) {
      if (!mounted || token != loadToken) return;
      setState(() {
        isLoading = false;
        errorText = 'Ошибка загрузки задачи: $error';
      });
    }
  }
}
