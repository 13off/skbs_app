part of '../task_details_legacy_screen.dart';

extension _TaskDetailsView on _TaskDetailsScreenState {
  Widget buildTaskDetailsView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задача'),
        actions: [
          if (canDeleteTask)
            IconButton(
              tooltip: 'Удалить',
              onPressed: isSaving ? null : confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.task.objectName,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Детали задачи',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          if (!canEdit) ...[
            buildLockedNotice(),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            onPressed: isSaving || !canEditDate ? null : pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('Дата задачи: ${formatDate(selectedDate)}'),
          ),
          const SizedBox(height: 14),
          buildStatusSection(),
          const SizedBox(height: 14),
          buildMilestoneSection(),
          const SizedBox(height: 16),
          buildAxesSection(),
          const SizedBox(height: 14),
          buildWorkSection(),
          if (!isGoalTask) const SizedBox(height: 16),
          if (!isLoading) buildAssigneesBlock(),
          const SizedBox(height: 16),
          buildPhotosBlock(
            photoStage: 'before',
            title: 'Фото «До»',
            emptyText: policy.requireBeforePhoto
                ? 'Обязательное фото «До» пока не прикреплено'
                : 'Фото «До» не прикреплено',
          ),
          const SizedBox(height: 14),
          buildPhotosBlock(
            photoStage: 'after',
            title: 'Фото «После»',
            emptyText: policy.requireAfterPhotoOnComplete
                ? 'Без нужного количества фото «После» задачу нельзя выполнить'
                : 'Фото «После» не прикреплено',
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            buildErrorBlock(),
          ],
          const SizedBox(height: 22),
          buildSaveButton(),
        ],
      ),
    );
  }
}
