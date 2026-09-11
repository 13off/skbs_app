import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/app_adaptive_palette.dart';
import '../data/offline_master_repository.dart';
import '../data/offline_task_create_service.dart';
import '../data/task_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../features/developer/models/task_policy.dart';
import '../features/milestones/presentation/task_milestone_picker.dart';
import '../features/tasks/presentation/task_assignee_controls.dart';
import '../features/tasks/presentation/task_photo_grid.dart';
import '../features/tasks/task_draft_support.dart';
import '../features/tasks/voice/task_voice_active_field.dart';
import '../features/tasks/voice/task_voice_dictionaries.dart';
import '../features/tasks/voice/task_voice_employee_matcher.dart';
import '../features/tasks/voice/task_voice_parser.dart';
import '../features/tasks/voice/task_voice_recognition.dart';
import '../features/tasks/voice/task_voice_strict_session.dart';
import '../features/work_orders/work_order_repository.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';
part 'task_create/task_create_actions.dart';
part 'task_create/task_create_loading.dart';
part 'task_create/task_create_sections.dart';
part 'task_create/task_create_view.dart';
part 'task_create/task_create_voice.dart';

class TaskCreateDraft {
  final TaskItemData task;
  final List<String> assigneeIds;
  final List<TaskPhotoFile> photos;
  final double? plannedQuantity;
  final String workUnit;
  final bool saveAsDraft;
  final String? sourceDraftId;
  final List<TaskCreateDraft> additionalTasks;

  const TaskCreateDraft({
    required this.task,
    required this.assigneeIds,
    required this.photos,
    this.plannedQuantity,
    this.workUnit = '',
    this.saveAsDraft = false,
    this.sourceDraftId,
    this.additionalTasks = const <TaskCreateDraft>[],
  });

  List<TaskCreateDraft> get allTasks => <TaskCreateDraft>[
    this,
    ...additionalTasks,
  ];

  TaskBatchCreateInput toBatchInput() {
    return TaskBatchCreateInput(task: task, assigneeIds: assigneeIds);
  }
}

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

class AddTaskScreen extends StatefulWidget {
  final DateTime initialDate;
  final String objectName;
  final String? initialMilestoneId,
      initialChecklistItemId,
      initialChecklistTitle;
  final String initialAxes;
  final String initialWork;
  final double? initialPlannedQuantity;
  final String initialWorkUnit;
  final List<String> initialAssigneeIds;
  final bool initialRequireBeforePhoto,
      allowAnyDate,
      allowDraft,
      startVoiceImmediately,
      isRepeat;
  final String? sourceDraftId;
  const AddTaskScreen({
    super.key,
    required this.initialDate,
    required this.objectName,
    this.initialMilestoneId,
    this.initialChecklistItemId,
    this.initialChecklistTitle,
    this.initialAxes = '',
    this.initialWork = '',
    this.initialPlannedQuantity,
    this.initialWorkUnit = 'м³',
    this.initialAssigneeIds = const <String>[],
    this.initialRequireBeforePhoto = false,
    this.allowAnyDate = false,
    this.allowDraft = false,
    this.isRepeat = false,
    this.sourceDraftId,
    this.startVoiceImmediately = false,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController axesController = TextEditingController(),
      workController = TextEditingController(),
      plannedQuantityController = TextEditingController();
  late DateTime selectedDate;
  late String selectedWorkUnit;

  List<Employee> employees = <Employee>[];
  final Set<String> selectedAssigneeIds = <String>{};
  final List<TaskPhotoFile> selectedPhotos = <TaskPhotoFile>[];
  String? selectedMilestoneId, selectedChecklistItemId, selectedChecklistTitle;
  bool isGoalTask = false;

  bool isLoadingEmployees = false,
      isPickingPhotos = false,
      isLoadingPolicy = true;
  bool isListeningVoice = false,
      voiceHasWarning = false,
      voiceAutoStartConsumed = false;
  TaskPolicy policy = TaskPolicy.defaults;
  String? errorText, voiceTranscript, voiceMessage;
  TaskVoiceField? voiceActiveField;

  DateTime? voiceSessionInitialDate;
  String voiceSessionInitialAxes = '', voiceSessionInitialWork = '';
  List<String> voiceSessionInitialAssigneeIds = const <String>[];
  List<TaskVoiceDraft> voiceBatchDrafts = const <TaskVoiceDraft>[];

  bool get requiresBeforePhoto =>
      policy.requireBeforePhoto || widget.initialRequireBeforePhoto;

  int get minimumBeforePhotos {
    if (!requiresBeforePhoto) return 0;
    return policy.requireBeforePhoto ? policy.minBeforePhotos : 1;
  }

  double? get plannedQuantityValue => double.tryParse(
    plannedQuantityController.text.trim().replaceAll(',', '.'),
  );

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    selectedMilestoneId = widget.initialMilestoneId;
    selectedChecklistItemId = widget.initialChecklistItemId;
    selectedChecklistTitle = selectedMilestoneId?.trim().isNotEmpty == true
        ? widget.initialChecklistTitle
        : null;
    isGoalTask = selectedMilestoneId?.trim().isNotEmpty == true;
    axesController.text = widget.initialAxes.trim();
    workController.text = widget.initialWork.trim();
    final initialQuantity = widget.initialPlannedQuantity;
    if (initialQuantity != null) {
      plannedQuantityController.text = initialQuantity == initialQuantity.roundToDouble()
          ? initialQuantity.toInt().toString()
          : initialQuantity.toString();
    }
    selectedWorkUnit = WorkOrderRepository.supportedUnits.contains(
      widget.initialWorkUnit.trim(),
    )
        ? widget.initialWorkUnit.trim()
        : WorkOrderRepository.supportedUnits.first;
    selectedAssigneeIds.addAll(
      widget.initialAssigneeIds.where((id) => id.trim().isNotEmpty),
    );
    loadEmployees();
    loadPolicy();
  }

  @override
  void dispose() {
    axesController.dispose();
    workController.dispose();
    plannedQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildTaskCreateView();
}
