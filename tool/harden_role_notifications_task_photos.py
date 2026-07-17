from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Pattern not found: {label} in {path}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


repository = 'lib/data/task_repository.dart'
replace_once(
    repository,
    """              .eq('task_date', _dateKey(date))
              .order('created_at', ascending: true)
""",
    """              .eq('task_date', _dateKey(date))
              .eq('is_draft', false)
              .order('created_at', ascending: true)
""",
    'global task query hides drafts',
)
replace_once(
    repository,
    """              .eq('task_date', _dateKey(date))
              .eq('object_name', cleanObject)
""",
    """              .eq('task_date', _dateKey(date))
              .eq('is_draft', false)
              .eq('object_name', cleanObject)
""",
    'object task query hides drafts',
)
replace_once(
    repository,
    """        .map((rows) {
          final filteredRows = cleanObject == null
              ? rows
              : rows.where((row) {
""",
    """        .map((rows) {
          final visibleRows = rows
              .where((row) => row['is_draft'] != true)
              .toList();
          final filteredRows = cleanObject == null
              ? visibleRows
              : visibleRows.where((row) {
""",
    'task stream hides drafts',
)
replace_once(
    repository,
    """    clearTaskListCache();
    final createdTask = TaskItemData.fromSupabase(row);
    _notifyTasksChanged(createdTask);

    return createdTask;
""",
    """    return TaskItemData.fromSupabase(row);
""",
    'draft creation stays silent',
)
replace_once(
    repository,
    """      await uploadPhotosForTask(
        taskId: taskId,
        photos: photos,
        photoStage: 'before',
      );

      final finalized = await _client
""",
    """      await uploadPhotosForTask(
        taskId: taskId,
        photos: photos,
        photoStage: 'before',
      );

      final createdWithLink = task.copyWith(id: taskId);
      await saveTaskMilestoneLink(createdWithLink);

      final finalized = await _client
""",
    'save milestone link before publishing',
)
replace_once(
    repository,
    """      final createdWithLink = task.copyWith(id: taskId);
      await saveTaskMilestoneLink(createdWithLink);
      clearTaskListCache();
""",
    """      clearTaskListCache();
""",
    'remove duplicate milestone link save',
)
replace_once(
    repository,
    """    } catch (_) {
      try {
        await _client.from('tasks').delete().eq('id', taskId);
      } catch (_) {
        // Черновик будет скрыт и может быть удалён служебной очисткой.
      }
      rethrow;
    }
""",
    """    } catch (_) {
      try {
        final draftPhotos = await fetchTaskPhotos(taskId);
        final paths = draftPhotos
            .map((photo) => photo.storagePath)
            .where((path) => path.trim().isNotEmpty)
            .toList();
        if (paths.isNotEmpty) {
          await _client.storage.from(taskPhotosBucket).remove(paths);
        }
      } catch (_) {
        // Удаление черновика продолжится даже при недоступности Storage.
      }
      try {
        await _client.from('tasks').delete().eq('id', taskId);
      } catch (_) {
        // Черновик скрыт из рабочих списков и может быть удалён служебно.
      }
      rethrow;
    }
""",
    'cleanup failed task draft',
)

legacy = 'lib/screens/task_details_legacy_screen.dart'
replace_once(
    legacy,
    """    if (selectedStatus == 'Выполнено' &&
        !photos.any((photo) => photo.isAfter)) {
""",
    """    if (selectedStatus == 'Выполнено' &&
        widget.task.status != 'Выполнено' &&
        !photos.any((photo) => photo.isAfter)) {
""",
    'grandfather existing completed task on save',
)
replace_once(
    legacy,
    """                    if (value && !photos.any((photo) => photo.isAfter)) {
""",
    """                    if (value &&
                        widget.task.status != 'Выполнено' &&
                        !photos.any((photo) => photo.isAfter)) {
""",
    'grandfather existing completed task toggle',
)

test = 'test/role_notifications_task_photos_contract_test.dart'
replace_once(
    test,
    """        'tasks_validate_photo_requirements',
      ],
""",
    """        'tasks_validate_photo_requirements',
        'appstroy.suppress_draft_task_id',
        "alter column source_role drop default",
      ],
""",
    'server hardening contracts',
)
replace_once(
    test,
    """      "'photo_stage': photoStage",
    ]);
""",
    """      "'photo_stage': photoStage",
      ".eq('is_draft', false)",
      "row['is_draft'] != true",
    ]);
""",
    'draft visibility contract',
)
replace_once(
    test,
    """      'Сначала добавьте хотя бы одно фото «После»',
    ]);
""",
    """      'Сначала добавьте хотя бы одно фото «После»',
      "widget.task.status != 'Выполнено'",
    ]);
""",
    'completed task grandfather contract',
)
