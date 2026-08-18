// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Фотография удалена')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> repeatTask() async {
    if (!canRepeatTask || isLoading || isSaving) return;

    final objectName = widget.task.objectName.trim();
    if (objectName.isEmpty) {
      showValidationError('У задачи не указан объект');
      return;
    }

    final draft = await Navigator.of(context).push<TaskCreateDraft>(
      MaterialPageRoute<TaskCreateDraft>(
        builder: (_) => AddTaskScreen(
          initialDate: TaskEditPolicy.operationalToday,
          objectName: objectName,
          initialAxes: widget.task.axes,
          initialWork: widget.task.work,
          initialAssigneeIds: originalAssigneeIds.toList(),
          initialMilestoneId: selectedMilestoneId,
          initialChecklistItemId: selectedChecklistItemId,
          initialChecklistTitle: widget.task.work,
          allowAnyDate:
              widget.profile.isAdmin ||
              TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,
          allowDraft: widget.profile.isForeman,
          isRepeat: true,
        ),
      ),
    );

    if (!mounted || draft == null) return;

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      if (draft.saveAsDraft) {
        await TaskRepository.saveTaskDraftWithDetails(
          draft.task,
          objectName: objectName,
          assigneeIds: draft.assigneeIds,
          sourceDraftId: null,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Копия сохранена как черновик')),
        );
        return;
      }

      await persistTaskCreateDraft(draft, objectName: objectName);
      if (!mounted) return;

      final date = DateFormat('dd.MM.yyyy').format(draft.task.date);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Задача повторена на $date')));
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Не удалось повторить задачу: $error');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
      required:
          policy.requireAfterPhotoOnComplete &&
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
          title: const Text('Переместить задачу в корзину?'),
          content: const Text(
            'Задача исчезнет из рабочих списков, но исполнители, фотографии и связь с целью сохранятся. Администратор или разработчик сможет восстановить её.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('В корзину'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    Navigator.pop(context, 'delete');
  }
}
