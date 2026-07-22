part of 'task_details_editor_screen.dart';

extension _TaskDetailsView on _TaskDetailsScreenState {
  Widget buildTaskDetailsView() {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
      body: AdaptiveDetailBody(
        desktopMaxWidth: 1280,
        children: [
          Text(
            widget.task.objectName,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Детали задачи',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final primary = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                ],
              );

              final media = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 18),
                  buildSaveButton(),
                ],
              );

              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [primary, const SizedBox(height: 16), media],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: primary),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: media),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
