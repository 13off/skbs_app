from pathlib import Path


def replace_once(path: str, old: str, new: str, marker: str | None = None) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if marker and marker in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, got {count}')
    file.write_text(text.replace(old, new), encoding='utf-8')


replace_once(
    'lib/features/milestones/presentation/task_milestone_picker.dart',
    "var weight = (item?.weight ?? 10).toDouble().clamp(5, 50);",
    "var weight = (item?.weight ?? 10).toDouble().clamp(5, 50).toDouble();",
    marker="clamp(5, 50).toDouble();",
)

replace_once(
    'lib/data/task_repository.dart',
    'class TaskRepository {',
    '''class TaskMilestoneLinkData {
  final String milestoneId;
  final String checklistItemId;

  const TaskMilestoneLinkData({
    required this.milestoneId,
    required this.checklistItemId,
  });
}

class TaskRepository {''',
    marker='class TaskMilestoneLinkData',
)

replace_once(
    'lib/data/task_repository.dart',
    '''  static void clearTaskListCache() {
    _tasksCache.clear();
  }
''',
    '''  static void clearTaskListCache() {
    _tasksCache.clear();
  }

  static Future<TaskMilestoneLinkData?> fetchTaskMilestoneLink(
    String taskId,
  ) async {
    final row = await _client
        .from('task_milestone_links')
        .select('milestone_id, checklist_item_id')
        .eq('task_id', taskId)
        .maybeSingle();

    if (row == null) return null;
    final milestoneId = row['milestone_id']?.toString().trim() ?? '';
    final checklistItemId =
        row['checklist_item_id']?.toString().trim() ?? '';
    if (milestoneId.isEmpty || checklistItemId.isEmpty) return null;

    return TaskMilestoneLinkData(
      milestoneId: milestoneId,
      checklistItemId: checklistItemId,
    );
  }

  static Future<void> saveTaskMilestoneLink(TaskItemData task) async {
    final taskId = task.id?.trim() ?? '';
    if (taskId.isEmpty) return;

    final milestoneId = task.milestoneId;
    final checklistItemId = task.checklistItemId;

    // null means that the link was not loaded and must stay untouched.
    if (milestoneId == null && checklistItemId == null) return;

    final cleanMilestoneId = milestoneId?.trim() ?? '';
    final cleanChecklistItemId = checklistItemId?.trim() ?? '';
    if (cleanMilestoneId.isEmpty || cleanChecklistItemId.isEmpty) {
      await _client
          .from('task_milestone_links')
          .delete()
          .eq('task_id', taskId);
      return;
    }

    await _client.from('task_milestone_links').upsert(
      {
        'task_id': taskId,
        'milestone_id': cleanMilestoneId,
        'checklist_item_id': cleanChecklistItemId,
      },
      onConflict: 'task_id',
    );
  }
''',
    marker='fetchTaskMilestoneLink',
)

replace_once(
    'lib/data/task_repository.dart',
    '''    if (photos.isNotEmpty) {
      await uploadPhotosForTask(taskId: taskId, photos: photos);
    }

    return createdTask;
''',
    '''    if (photos.isNotEmpty) {
      await uploadPhotosForTask(taskId: taskId, photos: photos);
    }

    final createdWithLink = task.copyWith(id: taskId);
    await saveTaskMilestoneLink(createdWithLink);

    return createdTask.copyWith(
      milestoneId: task.milestoneId,
      checklistItemId: task.checklistItemId,
    );
''',
    marker='final createdWithLink = task.copyWith',
)

replace_once(
    'lib/data/task_repository.dart',
    '''        .eq('id', task.id!);

    clearTaskListCache();
    _notifyTasksChanged(task);
''',
    '''        .eq('id', task.id!);

    await saveTaskMilestoneLink(task);
    clearTaskListCache();
    _notifyTasksChanged(task);
''',
    marker='await saveTaskMilestoneLink(task);',
)

replace_once(
    'lib/features/milestones/data/milestone_repository.dart',
    '''  static Future<void> linkTask({
''',
    '''  static Future<void> updateChecklistItem({
    required String itemId,
    required String title,
    required int weight,
    required bool isCritical,
  }) async {
    await _client.from('milestone_checklist_items').update({
      'title': title.trim(),
      'weight': weight,
      'is_critical': isCritical,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
  }

  static Future<void> deleteChecklistItem(String itemId) async {
    await _client
        .from('milestone_checklist_items')
        .delete()
        .eq('id', itemId);
  }

  static Future<void> linkTask({
''',
    marker='updateChecklistItem({',
)

replace_once(
    'lib/screens/add_task_screen.dart',
    "import '../data/task_repository.dart';",
    "import '../data/task_repository.dart';\nimport '../features/milestones/presentation/task_milestone_picker.dart';",
    marker='task_milestone_picker.dart',
)

replace_once(
    'lib/screens/add_task_screen.dart',
    '''  final DateTime initialDate;
  final String objectName;

  const AddTaskScreen({
    super.key,
    required this.initialDate,
    required this.objectName,
  });
''',
    '''  final DateTime initialDate;
  final String objectName;
  final String? initialMilestoneId;
  final String? initialChecklistItemId;

  const AddTaskScreen({
    super.key,
    required this.initialDate,
    required this.objectName,
    this.initialMilestoneId,
    this.initialChecklistItemId,
  });
''',
    marker='final String? initialMilestoneId;',
)

replace_once(
    'lib/screens/add_task_screen.dart',
    '''  final List<TaskPhotoFile> selectedPhotos = [];

  bool isLoadingEmployees = false;
''',
    '''  final List<TaskPhotoFile> selectedPhotos = [];
  String? selectedMilestoneId;
  String? selectedChecklistItemId;

  bool isLoadingEmployees = false;
''',
    marker='String? selectedMilestoneId;',
)

replace_once(
    'lib/screens/add_task_screen.dart',
    '''    selectedDate = widget.initialDate;
    loadEmployees();
''',
    '''    selectedDate = widget.initialDate;
    selectedMilestoneId = widget.initialMilestoneId;
    selectedChecklistItemId = widget.initialChecklistItemId;
    loadEmployees();
''',
    marker='selectedMilestoneId = widget.initialMilestoneId;',
)

replace_once(
    'lib/screens/add_task_screen.dart',
    '''    if (axes.isEmpty || work.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполни оси и вид работ')));
      return;
    }

    final newTask = TaskItemData(
''',
    '''    if (axes.isEmpty || work.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполни оси и вид работ')));
      return;
    }

    if (selectedMilestoneId != null && selectedChecklistItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выбери пункт чек-листа выбранной цели'),
        ),
      );
      return;
    }

    final newTask = TaskItemData(
''',
    marker='Выбери пункт чек-листа выбранной цели',
)

replace_once(
    'lib/screens/add_task_screen.dart',
    '''      selectedDate,
      objectName: widget.objectName,
    );
''',
    '''      selectedDate,
      objectName: widget.objectName,
      milestoneId: selectedMilestoneId ?? '',
      checklistItemId: selectedChecklistItemId ?? '',
    );
''',
    marker="milestoneId: selectedMilestoneId ?? '',",
)

replace_once(
    'lib/screens/add_task_screen.dart',
    '''          const SizedBox(height: 16),

          buildAssigneesBlock(),
''',
    '''          const SizedBox(height: 16),

          TaskMilestonePicker(
            objectName: widget.objectName,
            initialMilestoneId: selectedMilestoneId,
            initialChecklistItemId: selectedChecklistItemId,
            canSelect: true,
            canEditChecklist: true,
            onChanged: (selection) {
              selectedMilestoneId = selection.milestoneId;
              selectedChecklistItemId = selection.checklistItemId;
            },
          ),

          const SizedBox(height: 16),

          buildAssigneesBlock(),
''',
    marker='TaskMilestonePicker(',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    "import '../features/tasks/task_edit_policy.dart';",
    "import '../features/milestones/presentation/task_milestone_picker.dart';\nimport '../features/tasks/task_edit_policy.dart';",
    marker='task_milestone_picker.dart',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''  late DateTime selectedDate;
  late String selectedStatus;

  List<Employee> employees = [];
''',
    '''  late DateTime selectedDate;
  late String selectedStatus;
  String? selectedMilestoneId;
  String? selectedChecklistItemId;

  List<Employee> employees = [];
''',
    marker='String? selectedMilestoneId;',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''        TaskRepository.fetchTaskAssigneeIds(taskId),
        TaskRepository.fetchTaskPhotos(taskId),
      ]);
''',
    '''        TaskRepository.fetchTaskAssigneeIds(taskId),
        TaskRepository.fetchTaskPhotos(taskId),
        TaskRepository.fetchTaskMilestoneLink(taskId),
      ]);
''',
    marker='TaskRepository.fetchTaskMilestoneLink(taskId)',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''      final loadedPhotos = result[2] as List<TaskPhotoData>;

      setState(() {
''',
    '''      final loadedPhotos = result[2] as List<TaskPhotoData>;
      final loadedMilestoneLink = result[3] as TaskMilestoneLinkData?;

      setState(() {
''',
    marker='final loadedMilestoneLink = result[3]',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''        photos = loadedPhotos;
        signedUrlFutures.clear();
''',
    '''        photos = loadedPhotos;
        selectedMilestoneId = loadedMilestoneLink?.milestoneId;
        selectedChecklistItemId = loadedMilestoneLink?.checklistItemId;
        signedUrlFutures.clear();
''',
    marker='selectedMilestoneId = loadedMilestoneLink?.milestoneId;',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''    if (axes.isEmpty || work.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполни оси и вид работ')));
      return;
    }

    final taskDate = DateTime(
''',
    '''    if (axes.isEmpty || work.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполни оси и вид работ')));
      return;
    }

    if (selectedMilestoneId != null && selectedChecklistItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выбери пункт чек-листа выбранной цели'),
        ),
      );
      return;
    }

    final taskDate = DateTime(
''',
    marker='Выбери пункт чек-листа выбранной цели',
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''        date: selectedDate,
        notDoneComment: selectedStatus == 'Выполнено' ? '' : notDoneComment,
      );
''',
    '''        date: selectedDate,
        notDoneComment: selectedStatus == 'Выполнено' ? '' : notDoneComment,
        milestoneId: selectedMilestoneId ?? '',
        checklistItemId: selectedChecklistItemId ?? '',
      );
''',
    marker="milestoneId: selectedMilestoneId ?? '',",
)

replace_once(
    'lib/screens/task_details_screen.dart',
    '''          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            buildAssigneesBlock(),
''',
    '''          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            TaskMilestonePicker(
              objectName: widget.task.objectName,
              initialMilestoneId: selectedMilestoneId,
              initialChecklistItemId: selectedChecklistItemId,
              canSelect: canEdit,
              canEditChecklist:
                  widget.profile.isAdmin || widget.profile.isForeman,
              onChanged: (selection) {
                selectedMilestoneId = selection.milestoneId;
                selectedChecklistItemId = selection.checklistItemId;
              },
            ),
            const SizedBox(height: 16),
            buildAssigneesBlock(),
          ],
''',
    marker='canEditChecklist:',
)

replace_once(
    'lib/features/milestones/presentation/milestone_detail_screen.dart',
    '''        builder: (_) => AddTaskScreen(
          initialDate: initialDate,
          objectName: milestone.objectName,
        ),
''',
    '''        builder: (_) => AddTaskScreen(
          initialDate: initialDate,
          objectName: milestone.objectName,
          initialMilestoneId: milestone.id,
          initialChecklistItemId: item.id,
        ),
''',
    marker='initialMilestoneId: milestone.id,',
)

replace_once(
    'lib/features/milestones/presentation/milestone_detail_screen.dart',
    '''      await MilestoneRepository.linkTask(
        taskId: taskId,
        milestoneId: milestone.id,
        checklistItemId: item.id,
      );
      await refresh();
''',
    '''      await refresh();
''',
    marker='initialChecklistItemId: item.id,',
)

replace_once(
    'test/key_milestones_contract_test.dart',
    "expect(detail, contains('MilestoneRepository.linkTask'));",
    "expect(detail, contains('initialMilestoneId: milestone.id'));",
    marker="contains('initialMilestoneId: milestone.id')",
)

Path('.github/workflows/apply-task-goal-linking.yml').unlink(missing_ok=True)
Path('tool/apply_task_goal_linking.py').unlink(missing_ok=True)
