// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

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
      if (isGoalTask) voiceBatchDrafts = const <TaskVoiceDraft>[];
    });
  }

  void showValidationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<TaskCreateDraft> buildVoiceAdditionalResults() {
    if (voiceBatchDrafts.length <= 1 || isGoalTask) {
      return const <TaskCreateDraft>[];
    }
    return voiceBatchDrafts.skip(1).map((voiceDraft) {
      final voiceDate = voiceDraft.date;
      final taskDate = widget.allowAnyDate && voiceDate != null
          ? voiceDate
          : selectedDate;
      final task = TaskItemData(
        voiceDraft.axes.trim(),
        normalizeTaskVoiceWork(voiceDraft.work),
        'Запланировано',
        taskDate,
        objectName: widget.objectName,
      );
      return TaskCreateDraft(
        task: task,
        assigneeIds: List<String>.from(voiceDraft.assigneeIds),
        photos: const <TaskPhotoFile>[],
      );
    }).toList(growable: false);
  }

  TaskCreateDraft buildResult({required bool asDraft}) {
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final goalWork = selectedChecklistTitle?.trim() ?? '';
    final savedWork = isGoalTask && goalWork.isNotEmpty ? goalWork : work;
    final task = TaskItemData(
      axes,
      savedWork,
      'Запланировано',
      selectedDate,
      objectName: widget.objectName,
      milestoneId: selectedMilestoneId ?? '',
      checklistItemId: selectedChecklistItemId ?? '',
    );

    return TaskCreateDraft(
      task: task,
      assigneeIds: selectedAssigneeIds.toList(),
      photos: asDraft
          ? const <TaskPhotoFile>[]
          : List<TaskPhotoFile>.from(selectedPhotos),
      saveAsDraft: asDraft,
      sourceDraftId: widget.sourceDraftId,
    );
  }

  void saveDraft() {
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final goalWork = selectedChecklistTitle?.trim() ?? '';
    if (axes.isEmpty && work.isEmpty && goalWork.isEmpty) {
      showValidationError('Заполни хотя бы оси или вид работ');
      return;
    }
    Navigator.pop(context, buildResult(asDraft: true));
  }

  Future<void> saveTask() async {
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final linkedToGoal = isGoalTask;
    final goalWork = selectedChecklistTitle?.trim() ?? '';

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
      required: requiresBeforePhoto,
      actualCount: selectedPhotos.length,
      minimumCount: minimumBeforePhotos,
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

    final additional = buildVoiceAdditionalResults();
    if (additional.isNotEmpty) {
      if (requiresBeforePhoto) {
        showValidationError(
          'На объекте обязательны фото «До». Пакет из нескольких задач сохраните по одной, чтобы у каждой были свои фото.',
        );
        return;
      }
      for (var index = 0; index < additional.length; index += 1) {
        final draft = additional[index];
        final error = TaskDraftValidation.coreFields(
          axes: draft.task.axes.trim(),
          work: draft.task.work.trim(),
          linkedToGoal: false,
        );
        if (error != null) {
          showValidationError('Задача ${index + 2}: $error');
          return;
        }
      }

      try {
        for (final draft in additional) {
          await TaskRepository.addTaskWithDetails(
            draft.task,
            objectName: widget.objectName,
            assigneeIds: draft.assigneeIds,
            photos: const <TaskPhotoFile>[],
          );
        }
      } catch (error) {
        if (!mounted) return;
        showValidationError('Не удалось сохранить пакет задач: $error');
        return;
      }
      if (!mounted) return;
    }

    Navigator.pop(context, buildResult(asDraft: false));
  }
}
