from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Expected fragment not found in {path}: {old[:80]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/data/task_repository.dart",
    "  static Future<String> createTaskPhotoSignedUrl(TaskPhotoData photo) async {",
    """  static Future<void> deleteTaskPhoto(TaskPhotoData photo) async {
    final deletedRows = await _client
        .from('task_photos')
        .delete()
        .eq('id', photo.id)
        .eq('task_id', photo.taskId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw Exception('Фото уже удалено или редактирование закрыто');
    }

    try {
      await _client.storage.from(taskPhotosBucket).remove([photo.storagePath]);
    } catch (_) {
      // Запись уже удалена. Оставшийся файл можно убрать служебной очисткой.
    }

    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.tasks},
      context: <String, dynamic>{
        'table': 'task_photos',
        'task_id': photo.taskId,
      },
    );
  }

  static Future<String> createTaskPhotoSignedUrl(TaskPhotoData photo) async {""",
)

replace_once(
    "lib/screens/tasks_screen.dart",
    "import '../data/task_repository.dart';\n",
    "import '../data/task_repository.dart';\nimport '../features/tasks/task_edit_policy.dart';\n",
)
replace_once(
    "lib/screens/tasks_screen.dart",
    """    final draft = await Navigator.push<TaskCreateDraft>(
""",
    """    if (!TaskEditPolicy.canCreateForDate(widget.profile, selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прораб может добавлять задачи только на текущий день'),
        ),
      );
      return;
    }

    final draft = await Navigator.push<TaskCreateDraft>(
""",
)
replace_once(
    "lib/screens/tasks_screen.dart",
    "CupertinoPageRoute(builder: (_) => TaskDetailsScreen(task: task)),",
    """CupertinoPageRoute(
        builder: (_) => TaskDetailsScreen(task: task, profile: widget.profile),
      ),""",
)
replace_once(
    "lib/screens/tasks_screen.dart",
    """            onPressed: openAddTaskScreen,
""",
    """            onPressed: TaskEditPolicy.canCreateForDate(
              widget.profile,
              selectedDate,
            )
                ? openAddTaskScreen
                : null,
""",
)

replace_once(
    "lib/screens/task_details_screen.dart",
    "import '../data/employee_repository.dart';\n",
    """import '../data/employee_repository.dart';
import '../features/tasks/task_edit_policy.dart';
import '../models/app_user_profile.dart';
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """class TaskDetailsScreen extends StatefulWidget {
  final TaskItemData task;

  const TaskDetailsScreen({super.key, required this.task});
""",
    """class TaskDetailsScreen extends StatefulWidget {
  final TaskItemData task;
  final AppUserProfile profile;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.profile,
  });
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """  bool isPickingPhotos = false;
  String? errorText;

  final statuses = const ['Запланировано', 'Выполнено'];
""",
    """  bool isPickingPhotos = false;
  String? deletingPhotoId;
  String? errorText;

  final statuses = const ['Запланировано', 'Выполнено'];

  bool get canEdit => TaskEditPolicy.canEditTask(widget.profile, widget.task);
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """  Future<void> openAssigneesPicker() async {
    if (employees.isEmpty) {
""",
    """  Future<void> openAssigneesPicker() async {
    if (!canEdit) return;

    if (employees.isEmpty) {
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """  Future<void> addPhotos() async {
    final taskId = widget.task.id;
""",
    """  Future<void> addPhotos() async {
    if (!canEdit) return;

    final taskId = widget.task.id;
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """  Future<void> saveChanges() async {
    final taskId = widget.task.id;
""",
    """  Future<void> saveChanges() async {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TaskEditPolicy.lockedMessage(widget.task))),
      );
      return;
    }

    final taskId = widget.task.id;
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """  Future<void> openPhoto(TaskPhotoData photo) async {
    try {
      await TaskRepository.openTaskPhoto(photo);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка открытия фото: $e')));
    }
  }

""",
    """  Future<void> openPhoto(TaskPhotoData photo) async {
    try {
      await TaskRepository.openTaskPhoto(photo);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка открытия фото: $e')));
    }
  }

  Future<void> deletePhoto(TaskPhotoData photo) async {
    if (!canEdit || deletingPhotoId != null) return;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = 'Ошибка удаления фото: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          deletingPhotoId = null;
        });
      }
    }
  }

""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    "onTap: isLoading ? null : openAssigneesPicker,",
    "onTap: isLoading || !canEdit ? null : openAssigneesPicker,",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """            Positioned(
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
""",
    """            Positioned(
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
            if (canEdit)
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
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    "onPressed: isPickingPhotos ? null : addPhotos,",
    "onPressed: isPickingPhotos || !canEdit ? null : addPhotos,",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """        actions: [
          IconButton(
            tooltip: 'Удалить',
            onPressed: isSaving ? null : confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
""",
    """        actions: [
          if (widget.profile.isAdmin)
            IconButton(
              tooltip: 'Удалить',
              onPressed: isSaving ? null : confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: isSaving ? null : pickDate,
""",
    """          const SizedBox(height: 16),

          if (!canEdit) ...[
            Container(
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          OutlinedButton.icon(
            onPressed: isSaving || !widget.profile.isAdmin ? null : pickDate,
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """            onChanged: isSaving
                ? null
                : (value) {
""",
    """            onChanged: isSaving || !canEdit
                ? null
                : (value) {
""",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    "enabled: !isSaving,",
    "enabled: !isSaving && canEdit,",
)
# Остальные два TextField используют тот же фрагмент.
replace_once(
    "lib/screens/task_details_screen.dart",
    "enabled: !isSaving,",
    "enabled: !isSaving && canEdit,",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    "enabled: !isSaving,",
    "enabled: !isSaving && canEdit,",
)
replace_once(
    "lib/screens/task_details_screen.dart",
    """          SizedBox(
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
""",
    """          if (canEdit)
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
""",
)

print("Foreman task editing patch applied")
