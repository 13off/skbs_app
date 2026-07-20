part of '../add_task_screen.dart';

extension _TaskCreateActions on _AddTaskScreenState {
  Future<void> pickDate() async {
    if (!widget.allowAnyDate) return;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату задачи',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null) return;
    setState(() {
      selectedDate = pickedDate;
    });
  }

  Future<void> openAssigneesPicker() async {
    final result = await showTaskAssigneePicker(
      context: context,
      employees: employees,
      selectedIds: selectedAssigneeIds,
    );
    if (!mounted || result == null) return;

    setState(() {
      selectedAssigneeIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> pickPhotos() async {
    setState(() {
      isPickingPhotos = true;
      errorText = null;
    });

    try {
      final photos = await TaskRepository.pickPhotoFiles();
      if (!mounted || photos.isEmpty) return;
      setState(() {
        selectedPhotos.addAll(photos);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = 'Ошибка выбора фото: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isPickingPhotos = false;
        });
      }
    }
  }

  void removePhoto(TaskPhotoFile photo) {
    setState(() {
      selectedPhotos.remove(photo);
    });
  }

  void changeMilestone(TaskMilestoneSelection selection) {
    final next = TaskMilestoneDraftController.apply(
      selection: selection,
      currentWorkText: workController.text,
      previousChecklistTitle: selectedChecklistTitle,
    );

    setState(() {
      isGoalTask = next.goalMode;
      selectedMilestoneId = next.milestoneId;
      selectedChecklistItemId = next.checklistItemId;
      selectedChecklistTitle = next.checklistTitle;
      workController.text = next.workText;
    });
  }

  void showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void saveTask() {
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final linkedToGoal = isGoalTask;
    final goalWork = selectedChecklistTitle?.trim() ?? '';
    final savedWork = linkedToGoal ? goalWork : work;

    final coreError = TaskDraftValidation.coreFields(
      axes: axes,
      work: work,
      linkedToGoal: linkedToGoal,
    );
    if (coreError != null) {
      showValidationError(coreError);
      return;
    }

    final photoError = TaskDraftValidation.requiredPhotos(
      required: policy.requireBeforePhoto,
      actualCount: selectedPhotos.length,
      minimumCount: policy.minBeforePhotos,
      stageTitle: 'До',
    );
    if (photoError != null) {
      showValidationError(photoError);
      return;
    }

    final goalError = TaskDraftValidation.goalLink(
      linkedToGoal: linkedToGoal,
      checklistItemId: selectedChecklistItemId,
      goalWork: goalWork,
    );
    if (goalError != null) {
      showValidationError(goalError);
      return;
    }

    final newTask = TaskItemData(
      axes,
      savedWork,
      'Запланировано',
      selectedDate,
      objectName: widget.objectName,
      milestoneId: selectedMilestoneId ?? '',
      checklistItemId: selectedChecklistItemId ?? '',
    );

    Navigator.pop(
      context,
      TaskCreateDraft(
        task: newTask,
        assigneeIds: selectedAssigneeIds.toList(),
        photos: List<TaskPhotoFile>.from(selectedPhotos),
      ),
    );
  }
}
