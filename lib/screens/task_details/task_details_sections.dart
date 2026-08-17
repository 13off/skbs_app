// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of 'task_details_editor_screen.dart';

extension _TaskDetailsSections on _TaskDetailsScreenState {
  Widget buildLockedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            size: 21,
            color: AppAdaptivePalette.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              TaskEditPolicy.lockedMessage(widget.task),
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusSection() {
    final done = selectedStatus == 'Выполнено';
    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          value: done,
          onChanged: isSaving || !canEditStatus ? null : changeCompletionStatus,
          title: const Text(
            'Задача выполнена',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(done ? 'Статус: Выполнено' : 'Статус: Запланировано'),
        ),
        if (!done) ...[
          const SizedBox(height: 14),
          TextField(
            controller: notDoneCommentController,
            enabled: !isSaving && canEditStatus,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Причина невыполнения',
              hintText: 'Например: не успели, не было материала, не вышли люди',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget buildMilestoneSection() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return TaskMilestonePicker(
      objectName: widget.task.objectName,
      initialMilestoneId: selectedMilestoneId,
      initialChecklistItemId: selectedChecklistItemId,
      canSelect: canEditAxesWork,
      canEditChecklist: false,
      onChanged: changeMilestone,
    );
  }

  Widget buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget buildAxesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel('Оси'),
        TextField(
          controller: axesController,
          enabled: !isSaving && canEditAxesWork,
          decoration: InputDecoration(
            hintText: 'Укажите оси',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget buildWorkSection() {
    if (isGoalTask) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel('Вид работ'),
        TextField(
          controller: workController,
          enabled: !isSaving && canEditAxesWork,
          minLines: 3,
          maxLines: 7,
          decoration: InputDecoration(
            hintText: 'Опишите работы',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget buildAssigneesBlock() {
    return TaskAssigneeSummaryCard(
      title: assigneeTitle(),
      subtitle: selectedEmployeeNames(),
      enabled: !isLoading && canEditAssignees,
      onTap: openAssigneesPicker,
    );
  }

  Widget buildPhotoTile(TaskPhotoData photo) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openPhoto(photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<String>(
              future: signedUrlFuture(photo),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: AppAdaptivePalette.surfaceSoft,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Container(
                    color: AppAdaptivePalette.surfaceSoft,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                }
                return Image.network(snapshot.data!, fit: BoxFit.cover);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(7),
                color: Colors.black54,
                child: Text(
                  photo.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (TaskEditPolicy.canDeletePhoto(
              widget.profile,
              widget.task,
              photo.photoStage,
            ))
              Positioned(
                top: 5,
                right: 5,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.68),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Удалить фото',
                    visualDensity: VisualDensity.compact,
                    onPressed: deletingPhotoId == null
                        ? () => deletePhoto(photo)
                        : null,
                    icon: deletingPhotoId == photo.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorBlock() {
    final message = errorText;
    if (message == null) return const SizedBox.shrink();
    return Text(message, style: TextStyle(color: AppAdaptivePalette.danger));
  }

  Future<void> saveCurrentToDraft() async {
    if (!canEdit || isSaving) return;

    final objectName = widget.task.objectName.trim();
    if (objectName.isEmpty) {
      showValidationError('У задачи не указан объект');
      return;
    }

    final axes = axesController.text.trim();
    final visibleWork = workController.text.trim();
    final goalWork = selectedChecklistTitle?.trim() ?? '';
    final savedWork = isGoalTask && goalWork.isNotEmpty ? goalWork : visibleWork;
    final draftTask = TaskItemData(
      axes,
      savedWork,
      'Запланировано',
      selectedDate,
      objectName: objectName,
      milestoneId: selectedMilestoneId ?? '',
      checklistItemId: selectedChecklistItemId ?? '',
    );

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await TaskRepository.saveTaskDraftWithDetails(
        draftTask,
        objectName: objectName,
        assigneeIds: selectedAssigneeIds.toList(),
        sourceDraftId: null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача сохранена в черновики')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Не удалось сохранить в черновики: $error');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget buildActionButtons() {
    if (!canEdit && !canRepeatTask) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canEdit)
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isSaving ? null : saveChanges,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Сохранить'),
            ),
          ),
        if (canEdit) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: isSaving ? null : saveCurrentToDraft,
              icon: const Icon(Icons.drafts_outlined),
              label: const Text('В черновики'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: canRepeatTask && !isSaving && !isLoading
                ? repeatTask
                : null,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Повторить'),
          ),
        ),
      ],
    );
  }
}
