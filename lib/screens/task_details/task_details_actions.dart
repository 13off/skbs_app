part of 'task_details_editor_screen.dart';

extension _TaskDetailsActions on _TaskDetailsScreenState {
  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату задачи',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (!mounted || pickedDate == null) return;
    setState(() => selectedDate = pickedDate);
  }

  Future<void> openAssigneesPicker() async {
    if (!canEditAssignees) return;

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

  Future<void> addPhotos(String photoStage) async {
    if (!canEdit) return;

    final taskId = widget.task.id;
    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала сохраните задачу')),
      );
      return;
    }

    setState(() {
      isPickingPhotos = true;
      errorText = null;
    });

    try {
      final pickedPhotos = await TaskRepository.pickPhotoFiles();
      if (pickedPhotos.isEmpty) return;

      final uploadedPhotos = await TaskRepository.uploadPhotosForTask(
        taskId: taskId,
        photos: pickedPhotos,
        photoStage: photoStage,
      );
      if (!mounted) return;

      setState(() => photos = <TaskPhotoData>[...uploadedPhotos, ...photos]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoStage == 'before'
                ? 'Фото «До» добавлены'
                : 'Фото «После» добавлены',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка загрузки фото: $error');
    } finally {
      if (mounted) setState(() => isPickingPhotos = false);
    }
  }

  Future<void> openPhoto(TaskPhotoData photo) async {
    try {
      await TaskRepository.openTaskPhoto(photo);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка открытия фото: $error')),
      );
    }
  }

  Future<void> deletePhoto(TaskPhotoData photo) async {
    final allowed = TaskEditPolicy.canDeletePhoto(
      widget.profile,
      widget.task,
      photo.photoStage,
    );
    if (!allowed || deletingPhotoId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить фотографию?'),
          content: Text(photo.originalName),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      deletingPhotoId = photo.id;
      errorText = null;
    });

    try {
      await TaskRepository.deleteTaskPhoto(photo);
      if (!mounted) return;
      setState(() {
        photos = photos.where((item) => item.id != photo.id).toList();
        signedUrlFutures.remove(photo.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фотография удалена')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка удаления фото: $error');
    } finally {
      if (mounted) setState(() => deletingPhotoId = null);
    }
  }

  void changeCompletionStatus(bool value) {
    final afterCount = photos.where((photo) => photo.isAfter).length;
    if (value &&
        policy.requireAfterPhotoOnComplete &&
        widget.task.status != 'Выполнено' &&
        afterCount < policy.minAfterPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сначала добавьте фото «После»: минимум ${policy.minAfterPhotos}',
          ),
        ),
      );
      return;
    }

    setState(() {
      selectedStatus = value ? 'Выполнено' : 'Запланировано';
      if (value) notDoneCommentController.clear();
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

  Future<void> saveChanges() async {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TaskEditPolicy.lockedMessage(widget.task))),
      );
      return;
    }

    final taskId = widget.task.id;
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final linkedToGoal = isGoalTask;
    final goalWork = selectedChecklistTitle?.trim() ?? '';
    final savedWork = linkedToGoal ? goalWork : work;
    final notDoneComment = notDoneCommentController.text.trim();

    if (taskId == null || taskId.isEmpty) return;

    final coreError = TaskDraftValidation.coreFields(
      axes: axes,
      work: work,
      linkedToGoal: linkedToGoal,
    );
    if (coreError != null) {
      showValidationError(coreError);
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

    final taskDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isPastOrToday = !taskDate.isAfter(TaskEditPolicy.operationalToday);
    final afterCount = photos.where((photo) => photo.isAfter).length;
    final photoError = TaskDraftValidation.requiredPhotos(
      required: policy.requireAfterPhotoOnComplete &&
          selectedStatus == 'Выполнено' &&
          widget.task.status != 'Выполнено',
      actualCount: afterCount,
      minimumCount: policy.minAfterPhotos,
      stageTitle: 'После',
    );
    if (photoError != null) {
      showValidationError(photoError);
      return;
    }

    if (policy.requireNotDoneComment &&
        selectedStatus != 'Выполнено' &&
        isPastOrToday &&
        notDoneComment.isEmpty) {
      showValidationError('Укажи причину, почему задача не выполнена');
      return;
    }

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      final updatedTask = widget.task.copyWith(
        axes: axes,
        work: savedWork,
        status: selectedStatus,
        date: selectedDate,
        notDoneComment: selectedStatus == 'Выполнено' ? '' : notDoneComment,
        milestoneId: selectedMilestoneId ?? '',
        checklistItemId: selectedChecklistItemId ?? '',
      );

      await TaskRepository.saveTaskAssigneesIfChanged(
        taskId: taskId,
        previousAssigneeIds: originalAssigneeIds,
        nextAssigneeIds: selectedAssigneeIds,
      );
      if (!mounted) return;

      originalAssigneeIds
        ..clear()
        ..addAll(selectedAssigneeIds);
      Navigator.pop(context, updatedTask);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка сохранения задачи: $error');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить задачу?'),
          content: const Text('Задача, исполнители и фото будут удалены.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    Navigator.pop(context, 'delete');
  }
}
