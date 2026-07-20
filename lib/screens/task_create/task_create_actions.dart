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

    if (result == null) return;
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

  void saveTask() {
    final axes = axesController.text.trim();
    final work = workController.text.trim();
    final linkedToGoal = isGoalTask;
    final goalWork = selectedChecklistTitle?.trim() ?? '';
    final savedWork = linkedToGoal ? goalWork : work;

    if (axes.isEmpty || (!linkedToGoal && work.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(axes.isEmpty ? 'Заполни оси' : 'Укажи вид работ'),
        ),
      );
      return;
    }

    if (policy.requireBeforePhoto &&
        selectedPhotos.length < policy.minBeforePhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Добавьте фото «До»: минимум ${policy.minBeforePhotos}',
          ),
        ),
      );
      return;
    }

    if (linkedToGoal && (selectedChecklistItemId == null || goalWork.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбери работу по цели')),
      );
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
