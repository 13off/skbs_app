part of '../task_details_legacy_screen.dart';

extension _TaskDetailsSections on _TaskDetailsScreenState {
  Widget buildLockedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1D8C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock_outlined, size: 21),
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
          subtitle: Text(
            done ? 'Статус: Выполнено' : 'Статус: Запланировано',
          ),
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
          style: const TextStyle(
            color: Color(0xFF6B7075),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAssigneesBlock() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoading || !canEditAssignees ? null : openAssigneesPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assigneeTitle(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedEmployeeNames(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
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
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Container(
                    color: Colors.grey.shade200,
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

  Widget buildPhotosBlock({
    required String photoStage,
    required String title,
    required String emptyText,
  }) {
    final stagePhotos = photos
        .where((photo) => photo.photoStage == photoStage)
        .toList();
    final description = photoStage == 'before'
        ? policy.requireBeforePhoto
            ? 'Обязательное состояние участка перед началом работ: минимум ${policy.minBeforePhotos}.'
            : 'Фотография участка перед началом работ — по желанию.'
        : policy.requireAfterPhotoOnComplete
            ? 'Обязательный результат после завершения: минимум ${policy.minAfterPhotos}.'
            : 'Фотография результата — по желанию.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(description),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isPickingPhotos || !canEdit
                  ? null
                  : () => addPhotos(photoStage),
              icon: isPickingPhotos
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text('Добавить $title'),
            ),
          ),
          if (stagePhotos.isEmpty) ...[
            const SizedBox(height: 12),
            Text(emptyText),
          ] else ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stagePhotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return buildPhotoTile(stagePhotos[index]);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget buildErrorBlock() {
    final message = errorText;
    if (message == null) return const SizedBox.shrink();
    return Text(message, style: const TextStyle(color: Colors.red));
  }

  Widget buildSaveButton() {
    if (!canEdit) return const SizedBox.shrink();
    return SizedBox(
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
    );
  }
}
