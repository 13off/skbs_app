part of '../task_details_legacy_screen.dart';

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

    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('На объекте нет сотрудников')),
      );
      return;
    }

    final tempSelectedIds = Set<String>.from(selectedAssigneeIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Исполнители',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: employees.map((employee) {
                          final employeeId = employee.id!;
                          final selected = tempSelectedIds.contains(employeeId);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelectedIds.add(employeeId);
                                } else {
                                  tempSelectedIds.remove(employeeId);
                                }
                              });
                            },
                            title: Text(
                              employee.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(employee.position),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(tempSelectedIds.clear);
                            },
                            child: const Text('Очистить'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context, tempSelectedIds);
                            },
                            child: const Text('Готово'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    final previousTitle = selectedChecklistTitle;
    setState(() {
      isGoalTask = selection.goalMode;
      selectedMilestoneId = selection.milestoneId;
      selectedChecklistItemId = selection.checklistItemId;
      selectedChecklistTitle = selection.checklistTitle;

      final nextTitle = selection.checklistTitle?.trim() ?? '';
      if (selection.isLinked && nextTitle.isNotEmpty) {
        workController.text = nextTitle;
      } else if (previousTitle != null &&
          workController.text.trim() == previousTitle.trim()) {
        workController.clear();
      }
    });
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

    if (axes.isEmpty || (!linkedToGoal && work.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(axes.isEmpty ? 'Заполни оси' : 'Укажи вид работ')),
      );
      return;
    }

    if (linkedToGoal && (selectedChecklistItemId == null || goalWork.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбери работу по цели')),
      );
      return;
    }

    final taskDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isPastOrToday = !taskDate.isAfter(TaskEditPolicy.operationalToday);
    final afterCount = photos.where((photo) => photo.isAfter).length;

    if (policy.requireAfterPhotoOnComplete &&
        selectedStatus == 'Выполнено' &&
        widget.task.status != 'Выполнено' &&
        afterCount < policy.minAfterPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Добавьте фото «После»: минимум ${policy.minAfterPhotos}',
          ),
        ),
      );
      return;
    }

    if (policy.requireNotDoneComment &&
        selectedStatus != 'Выполнено' &&
        isPastOrToday &&
        notDoneComment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажи причину, почему задача не выполнена'),
        ),
      );
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
