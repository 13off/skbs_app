from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding='utf-8')


def replace_once(path: str, old: str, new: str, marker: str | None = None) -> None:
    text = read(path)
    if marker and marker in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, got {count}: {old[:80]!r}')
    write(path, text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str, marker: str | None = None) -> None:
    text = read(path)
    if marker and marker in text:
        return
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{path}: regex expected one match, got {count}: {pattern[:80]!r}')
    write(path, updated)


# Task model: store the contribution of one daily task to its checklist item.
path = 'lib/models/task_item_data.dart'
replace_once(
    path,
    "  final String? checklistItemId;\n",
    "  final String? checklistItemId;\n\n  /// Процент, который эта дневная задача добавляет к пункту чек-листа.\n  /// null — значение связи не загружалось; 0 — вклад отсутствует.\n  final int? progressPercent;\n",
    marker='final int? progressPercent;',
)
replace_once(
    path,
    "    this.checklistItemId,\n  });",
    "    this.checklistItemId,\n    this.progressPercent,\n  });",
    marker='this.progressPercent,',
)
replace_once(
    path,
    "      checklistItemId: json['checklist_item_id'] as String?,\n",
    "      checklistItemId: json['checklist_item_id'] as String?,\n      progressPercent: (json['progress_percent'] as num?)?.toInt(),\n",
)
# The same fragment appears once more in fromSupabase after the first replacement.
replace_once(
    path,
    "      checklistItemId: json['checklist_item_id'] as String?,\n",
    "      checklistItemId: json['checklist_item_id'] as String?,\n      progressPercent: (json['progress_percent'] as num?)?.toInt(),\n",
)
replace_once(
    path,
    "      'checklist_item_id': checklistItemId,\n",
    "      'checklist_item_id': checklistItemId,\n      'progress_percent': progressPercent,\n",
)
replace_once(
    path,
    "    String? checklistItemId,\n  }) {",
    "    String? checklistItemId,\n    int? progressPercent,\n  }) {",
)
replace_once(
    path,
    "      checklistItemId: checklistItemId ?? this.checklistItemId,\n",
    "      checklistItemId: checklistItemId ?? this.checklistItemId,\n      progressPercent: progressPercent ?? this.progressPercent,\n",
)

# Task repository: load/save progress_percent together with the existing link.
path = 'lib/data/task_repository.dart'
replace_once(
    path,
    "  final String checklistItemId;\n\n  const TaskMilestoneLinkData({\n    required this.milestoneId,\n    required this.checklistItemId,\n  });",
    "  final String checklistItemId;\n  final int progressPercent;\n\n  const TaskMilestoneLinkData({\n    required this.milestoneId,\n    required this.checklistItemId,\n    required this.progressPercent,\n  });",
    marker='final int progressPercent;',
)
replace_once(
    path,
    ".select('milestone_id, checklist_item_id')",
    ".select('milestone_id, checklist_item_id, progress_percent')",
)
replace_once(
    path,
    "      checklistItemId: checklistItemId,\n    );",
    "      checklistItemId: checklistItemId,\n      progressPercent: ((row['progress_percent'] as num?)?.toInt() ?? 0)\n          .clamp(0, 100),\n    );",
)
replace_once(
    path,
    "    await _client.from('task_milestone_links').upsert(\n      {",
    "    final progressPercent = (task.progressPercent ?? 0).clamp(0, 100);\n\n    await _client.from('task_milestone_links').upsert(\n      {",
    marker='final progressPercent = (task.progressPercent ?? 0).clamp(0, 100);',
)
replace_once(
    path,
    "        'checklist_item_id': cleanChecklistItemId,\n",
    "        'checklist_item_id': cleanChecklistItemId,\n        'progress_percent': progressPercent,\n",
)
replace_once(
    path,
    "      checklistItemId: task.checklistItemId,\n    );",
    "      checklistItemId: task.checklistItemId,\n      progressPercent: task.progressPercent,\n    );",
)

# Milestone models: completed daily task percentages accumulate to item progress.
path = 'lib/features/milestones/models/milestone_models.dart'
replace_once(
    path,
    "  final DateTime date;\n\n  const MilestoneTaskData({",
    "  final DateTime date;\n  final int progressPercent;\n\n  const MilestoneTaskData({",
    marker='final int progressPercent;',
)
replace_once(
    path,
    "    required this.date,\n  });",
    "    required this.date,\n    required this.progressPercent,\n  });",
)
regex_once(
    path,
    r"  int get doneTaskCount => tasks\.where\(\(task\) => task\.isDone\)\.length;\n\n  double get completionFraction \{.*?\n  \}\n\n  bool get isEffectivelyDone => completionFraction >= 1;\n  bool get isBlocked => state == 'blocked';\n\n  String get stateTitle \{.*?\n  \}",
    """  int get doneTaskCount => tasks.where((task) => task.isDone).length;

  int get progressPercent {
    final total = tasks
        .where((task) => task.isDone)
        .fold<int>(0, (sum, task) => sum + task.progressPercent);
    if (state == 'done') return 100;
    if (state == 'blocked') return 0;
    return total.clamp(0, 100);
  }

  int get remainingProgressPercent => (100 - progressPercent).clamp(0, 100);

  double get completionFraction => progressPercent / 100;

  bool get isEffectivelyDone => progressPercent >= 100;
  bool get isBlocked => state == 'blocked';

  String get stateTitle {
    if (isBlocked) return 'Заблокировано';
    if (isEffectivelyDone) return 'Готово';
    if (progressPercent > 0 || state == 'in_progress') return 'В работе';
    return 'Не начато';
  }""",
    marker='int get remainingProgressPercent',
)

# Repository hydrates every linked task contribution.
path = 'lib/features/milestones/data/milestone_repository.dart'
replace_once(
    path,
    "'task_id, milestone_id, checklist_item_id, tasks(id, work, axes, status, task_date)',",
    "'task_id, milestone_id, checklist_item_id, progress_percent, tasks(id, work, axes, status, task_date)',",
)
replace_once(
    path,
    "              date: DateTime.tryParse(task['task_date']?.toString() ?? '') ??\n                  DateTime.now(),\n",
    "              date: DateTime.tryParse(task['task_date']?.toString() ?? '') ??\n                  DateTime.now(),\n              progressPercent:\n                  ((row['progress_percent'] as num?)?.toInt() ?? 0)\n                      .clamp(0, 100),\n",
)

# Picker returns the selected goal/item details and shows real accumulated progress.
path = 'lib/features/milestones/presentation/task_milestone_picker.dart'
replace_once(
    path,
    "  final String? checklistItemId;\n\n  const TaskMilestoneSelection({\n    required this.milestoneId,\n    required this.checklistItemId,\n  });",
    "  final String? checklistItemId;\n  final String milestoneTitle;\n  final String milestoneLocation;\n  final String checklistTitle;\n  final int checklistProgressPercent;\n\n  const TaskMilestoneSelection({\n    required this.milestoneId,\n    required this.checklistItemId,\n    this.milestoneTitle = '',\n    this.milestoneLocation = '',\n    this.checklistTitle = '',\n    this.checklistProgressPercent = 0,\n  });",
    marker='final int checklistProgressPercent;',
)
replace_once(
    path,
    "  String? selectedChecklistItemId;\n  bool busy = false;",
    "  String? selectedChecklistItemId;\n  List<ProjectMilestone> loadedMilestones = const <ProjectMilestone>[];\n  bool busy = false;",
    marker='loadedMilestones = const <ProjectMilestone>[];',
)
replace_once(
    path,
    "    final selectedMilestone = rows.where((milestone) {",
    "    loadedMilestones = rows;\n\n    final selectedMilestone = rows.where((milestone) {",
)
replace_once(
    path,
    "    if (!itemExists) {\n      selectedChecklistItemId = selectedMilestone.items.isEmpty\n          ? null\n          : selectedMilestone.items.first.id;\n    }",
    "    if (!itemExists) {\n      selectedChecklistItemId = null;\n    }",
)
regex_once(
    path,
    r"  void _notifySelection\(\) \{\n    widget\.onChanged\(\n      TaskMilestoneSelection\(\n        milestoneId: selectedMilestoneId,\n        checklistItemId: selectedChecklistItemId,\n      \),\n    \);\n  \}",
    """  void _notifySelection() {
    final milestone = loadedMilestones.where((value) {
      return value.id == selectedMilestoneId;
    }).firstOrNull;
    final item = milestone?.items.where((value) {
      return value.id == selectedChecklistItemId;
    }).firstOrNull;

    widget.onChanged(
      TaskMilestoneSelection(
        milestoneId: selectedMilestoneId,
        checklistItemId: selectedChecklistItemId,
        milestoneTitle: milestone?.title ?? '',
        milestoneLocation: milestone?.location ?? '',
        checklistTitle: item?.title ?? '',
        checklistProgressPercent: item?.progressPercent ?? 0,
      ),
    );
  }""",
    marker='checklistProgressPercent: item?.progressPercent ?? 0,',
)
replace_once(
    path,
    "      selectedChecklistItemId = milestone.items.isEmpty\n          ? null\n          : milestone.items.first.id;",
    "      selectedChecklistItemId = null;",
)
replace_once(
    path,
    "                        _statusChip(item.stateTitle, stateColor),\n                        _statusChip('Вес ${item.weight}%', const Color(0xFF6B7075)),",
    "                        _statusChip(item.stateTitle, stateColor),\n                        _statusChip(\n                          'Выполнено ${item.progressPercent}%',\n                          const Color(0xFF6B7075),\n                        ),\n                        _statusChip('Вес ${item.weight}%', const Color(0xFF6B7075)),",
)

# Add task: selecting a checklist item creates an editable task draft from it.
path = 'lib/screens/add_task_screen.dart'
replace_once(
    path,
    "  String? selectedChecklistItemId;\n\n  bool isLoadingEmployees = false;",
    "  String? selectedChecklistItemId;\n  String? autoFilledAxes;\n  String? autoFilledWork;\n\n  bool isLoadingEmployees = false;",
    marker='String? autoFilledAxes;',
)
replace_once(
    path,
    "  void saveTask() {",
    """  void applyMilestoneSelection(TaskMilestoneSelection selection) {
    final previousAxes = axesController.text.trim();
    final previousWork = workController.text.trim();
    final nextAxes = selection.milestoneLocation.trim();
    final nextWork = selection.checklistTitle.trim();

    setState(() {
      selectedMilestoneId = selection.milestoneId;
      selectedChecklistItemId = selection.checklistItemId;

      if (selection.isLinked &&
          nextAxes.isNotEmpty &&
          (previousAxes.isEmpty || previousAxes == autoFilledAxes)) {
        axesController.text = nextAxes;
        autoFilledAxes = nextAxes;
      }
      if (selection.isLinked &&
          nextWork.isNotEmpty &&
          (previousWork.isEmpty || previousWork == autoFilledWork)) {
        workController.text = nextWork;
        autoFilledWork = nextWork;
      }
    });
  }

  void saveTask() {""",
    marker='void applyMilestoneSelection(TaskMilestoneSelection selection)',
)
replace_once(
    path,
    "      checklistItemId: selectedChecklistItemId ?? '',\n    );",
    "      checklistItemId: selectedChecklistItemId ?? '',\n      progressPercent: 0,\n    );",
)
replace_once(
    path,
    "            onChanged: (selection) {\n              selectedMilestoneId = selection.milestoneId;\n              selectedChecklistItemId = selection.checklistItemId;\n            },",
    "            onChanged: applyMilestoneSelection,",
)

# Task details: enter the daily percentage when completing a linked task.
path = 'lib/screens/task_details_screen.dart'
replace_once(
    path,
    "  String? selectedChecklistItemId;\n\n  List<Employee> employees = [];",
    "  String? selectedChecklistItemId;\n  String? originalChecklistItemId;\n  String selectedChecklistTitle = '';\n  int selectedChecklistProgressPercent = 0;\n  int selectedProgressPercent = 0;\n  int originalProgressPercent = 0;\n\n  List<Employee> employees = [];",
    marker='int selectedProgressPercent = 0;',
)
replace_once(
    path,
    "        selectedMilestoneId = loadedMilestoneLink?.milestoneId;\n        selectedChecklistItemId = loadedMilestoneLink?.checklistItemId;",
    "        selectedMilestoneId = loadedMilestoneLink?.milestoneId;\n        selectedChecklistItemId = loadedMilestoneLink?.checklistItemId;\n        originalChecklistItemId = loadedMilestoneLink?.checklistItemId;\n        selectedProgressPercent = loadedMilestoneLink?.progressPercent ?? 0;\n        originalProgressPercent = loadedMilestoneLink?.progressPercent ?? 0;",
)
replace_once(
    path,
    "  Future<void> saveChanges() async {",
    """  int get maxProgressForSelectedItem {
    if (selectedChecklistItemId == null || selectedChecklistItemId!.isEmpty) {
      return 0;
    }
    final existingOwnProgress =
        selectedChecklistItemId == originalChecklistItemId
            ? originalProgressPercent
            : 0;
    return (100 - selectedChecklistProgressPercent + existingOwnProgress)
        .clamp(0, 100);
  }

  int get projectedChecklistProgress {
    final existingOwnProgress =
        selectedChecklistItemId == originalChecklistItemId
            ? originalProgressPercent
            : 0;
    return (selectedChecklistProgressPercent -
            existingOwnProgress +
            selectedProgressPercent)
        .clamp(0, 100);
  }

  void applyMilestoneSelection(TaskMilestoneSelection selection) {
    final previousItemId = selectedChecklistItemId;
    setState(() {
      selectedMilestoneId = selection.milestoneId;
      selectedChecklistItemId = selection.checklistItemId;
      selectedChecklistTitle = selection.checklistTitle;
      selectedChecklistProgressPercent = selection.checklistProgressPercent;

      if (selection.checklistItemId != previousItemId) {
        selectedProgressPercent =
            selection.checklistItemId == originalChecklistItemId
                ? originalProgressPercent
                : 0;
      }
      selectedProgressPercent = selectedProgressPercent
          .clamp(0, maxProgressForSelectedItem);
    });
  }

  Widget buildProgressBlock() {
    final linked = selectedMilestoneId != null &&
        selectedMilestoneId!.isNotEmpty &&
        selectedChecklistItemId != null &&
        selectedChecklistItemId!.isNotEmpty;
    if (!linked) return const SizedBox.shrink();

    final maxProgress = maxProgressForSelectedItem;
    final sliderMax = maxProgress <= 0 ? 1.0 : maxProgress.toDouble();
    final sliderValue = selectedProgressPercent.clamp(0, maxProgress).toDouble();
    final quickValues = <int>{10, 20, 25, 30, 50, maxProgress}
        .where((value) => value > 0 && value <= maxProgress)
        .toList()
      ..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E4E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выполнение за эту задачу',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            selectedChecklistTitle.isEmpty
                ? 'Укажите, сколько процентов выполнено сегодня.'
                : '$selectedChecklistTitle: сейчас $selectedChecklistProgressPercent%',
            style: const TextStyle(color: Color(0xFF6B7075)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0,
                  max: sliderMax,
                  divisions: maxProgress <= 0 ? 1 : maxProgress,
                  value: sliderValue,
                  onChanged: isSaving || !canEdit || maxProgress <= 0
                      ? null
                      : (value) {
                          setState(() {
                            selectedProgressPercent = value.round();
                          });
                        },
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  '+$selectedProgressPercent%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (quickValues.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickValues.map((value) {
                return ChoiceChip(
                  label: Text('+$value%'),
                  selected: selectedProgressPercent == value,
                  onSelected: isSaving || !canEdit
                      ? null
                      : (_) => setState(() => selectedProgressPercent = value),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            maxProgress <= 0
                ? 'Пункт уже выполнен на 100%.'
                : 'После сохранения: $projectedChecklistProgress% из 100%. '
                    'Можно добавить не больше $maxProgress%.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> saveChanges() async {""",
    marker='Widget buildProgressBlock()',
)
replace_once(
    path,
    "    if (selectedStatus != 'Выполнено' &&\n        isPastOrToday &&",
    "    final linkedToChecklist = selectedMilestoneId != null &&\n        selectedMilestoneId!.isNotEmpty &&\n        selectedChecklistItemId != null &&\n        selectedChecklistItemId!.isNotEmpty;\n    if (selectedStatus == 'Выполнено' &&\n        linkedToChecklist &&\n        maxProgressForSelectedItem > 0 &&\n        selectedProgressPercent <= 0) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Укажи процент, выполненный по этой задаче сегодня'),\n        ),\n      );\n      return;\n    }\n\n    if (selectedStatus != 'Выполнено' &&\n        isPastOrToday &&",
    marker="Укажи процент, выполненный по этой задаче сегодня",
)
replace_once(
    path,
    "        checklistItemId: selectedChecklistItemId ?? '',\n      );",
    "        checklistItemId: selectedChecklistItemId ?? '',\n        progressPercent: selectedProgressPercent,\n      );",
)
replace_once(
    path,
    "              onChanged: (selection) {\n                selectedMilestoneId = selection.milestoneId;\n                selectedChecklistItemId = selection.checklistItemId;\n              },\n            ),\n            const SizedBox(height: 16),\n            buildAssigneesBlock(),",
    "              onChanged: applyMilestoneSelection,\n            ),\n            const SizedBox(height: 16),\n            buildProgressBlock(),\n            const SizedBox(height: 16),\n            buildAssigneesBlock(),",
)

# Goal detail uses the new real percentage instead of task-count based status.
path = 'lib/features/milestones/presentation/milestone_detail_screen.dart'
replace_once(
    path,
    "                      '${item.stateTitle} · вес ${item.weight}% · '",
    "                      '${item.progressPercent}% выполнено · вес ${item.weight}% · '",
)

# Act context includes today's contribution.
path = 'lib/models/task_act_context.dart'
replace_once(
    path,
    "  final int checklistProgressPercent;\n",
    "  final int checklistProgressPercent;\n  final int taskProgressPercent;\n",
    marker='final int taskProgressPercent;',
)
replace_once(
    path,
    "    required this.checklistProgressPercent,\n",
    "    required this.checklistProgressPercent,\n    required this.taskProgressPercent,\n",
)

path = 'lib/data/act_context_repository.dart'
replace_once(
    path,
    ".select('task_id, milestone_id, checklist_item_id')",
    ".select('task_id, milestone_id, checklist_item_id, progress_percent')",
)
replace_once(
    path,
    "        checklistProgressPercent: (item.completionFraction * 100).round(),\n",
    "        checklistProgressPercent: item.progressPercent,\n        taskProgressPercent:\n            ((row['progress_percent'] as num?)?.toInt() ?? 0)\n                .clamp(0, 100),\n",
)

path = 'lib/data/act_generator.dart'
replace_once(
    path,
    "        'Готовность цели — ${context.milestoneProgressPercent}%. '",
    "        'Выполнение за день — ${context.taskProgressPercent}%. '\n        'Готовность цели — ${context.milestoneProgressPercent}%. '",
)

path = 'lib/screens/act_preview_screen.dart'
replace_once(
    path,
    "              Text(\n                'Цель: ${goalContext.milestoneTitle} — '",
    "              Text(\n                'Выполнение за день: +${goalContext.taskProgressPercent}%',\n                style: const TextStyle(fontWeight: FontWeight.w900),\n              ),\n              const SizedBox(height: 6),\n              Text(\n                'Цель: ${goalContext.milestoneTitle} — '",
    marker='Выполнение за день: +${goalContext.taskProgressPercent}%',
)

# Supabase migration: one daily contribution per linked task, with safe backfill.
migration = Path('supabase/migrations/20260717110000_add_task_progress_percent.sql')
migration.write_text("""alter table public.task_milestone_links
  add column if not exists progress_percent integer not null default 0;

alter table public.task_milestone_links
  drop constraint if exists task_milestone_links_progress_percent_check;

alter table public.task_milestone_links
  add constraint task_milestone_links_progress_percent_check
  check (progress_percent between 0 and 100);

-- Preserve the previous behaviour for already completed linked tasks.
update public.task_milestone_links as link
set progress_percent = 100
from public.tasks as task
where task.id = link.task_id
  and task.status = 'Выполнено'
  and link.progress_percent = 0;
""", encoding='utf-8')

# Regression contract.
test = Path('test/cumulative_task_progress_contract_test.dart')
test.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('daily task progress accumulates into checklist and milestone', () {
    final model = source('lib/features/milestones/models/milestone_models.dart');
    final repository = source('lib/features/milestones/data/milestone_repository.dart');
    final taskRepository = source('lib/data/task_repository.dart');

    expect(model, contains('sum + task.progressPercent'));
    expect(model, contains('return total.clamp(0, 100)'));
    expect(repository, contains('progress_percent'));
    expect(taskRepository, contains("'progress_percent': progressPercent"));
  });

  test('task form selects a checklist item and records todays percent', () {
    final addTask = source('lib/screens/add_task_screen.dart');
    final details = source('lib/screens/task_details_screen.dart');
    final picker = source(
      'lib/features/milestones/presentation/task_milestone_picker.dart',
    );

    expect(addTask, contains('applyMilestoneSelection'));
    expect(addTask, contains('autoFilledWork'));
    expect(picker, contains('checklistProgressPercent'));
    expect(details, contains('Выполнение за эту задачу'));
    expect(details, contains('maxProgressForSelectedItem'));
    expect(details, contains('progressPercent: selectedProgressPercent'));
  });

  test('completed-work act contains daily and accumulated percentages', () {
    final context = source('lib/models/task_act_context.dart');
    final generator = source('lib/data/act_generator.dart');
    final preview = source('lib/screens/act_preview_screen.dart');

    expect(context, contains('taskProgressPercent'));
    expect(generator, contains('Выполнение за день'));
    expect(preview, contains('Выполнение за день: +'));
  });
}
""", encoding='utf-8')
