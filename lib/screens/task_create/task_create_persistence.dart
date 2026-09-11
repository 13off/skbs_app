part of '../add_task_screen.dart';

Future<List<TaskItemData>> persistTaskCreateDraft(
  TaskCreateDraft draft, {
  required String objectName,
}) async {
  final drafts = draft.allTasks;
  if (drafts.length == 1) {
    return <TaskItemData>[
      await OfflineTaskCreateService.queueTask(
        draft.task,
        objectName: objectName,
        assigneeIds: draft.assigneeIds,
        photos: draft.photos,
        plannedQuantity: draft.plannedQuantity,
        workUnit: draft.workUnit,
        isDraft: draft.saveAsDraft,
        preferredId: draft.sourceDraftId,
      ),
    ];
  }
  if (drafts.any((item) => item.photos.isNotEmpty)) {
    throw Exception('Пакет задач с фотографиями нужно сохранять по одной');
  }

  // A weak LTE connection must not turn batch creation into a long blocking
  // server request. Every task is accepted locally first and replayed by the
  // same durable queue as a single task.
  final created = <TaskItemData>[];
  for (final item in drafts) {
    created.add(
      await OfflineTaskCreateService.queueTask(
        item.task,
        objectName: objectName,
        assigneeIds: item.assigneeIds,
        photos: const <TaskPhotoFile>[],
        plannedQuantity: item.plannedQuantity,
        workUnit: item.workUnit,
        isDraft: item.saveAsDraft,
        preferredId: item.sourceDraftId,
      ),
    );
  }
  return created;
}
