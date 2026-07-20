import '../milestones/presentation/task_milestone_picker.dart';

class TaskMilestoneDraftState {
  final bool goalMode;
  final String? milestoneId;
  final String? checklistItemId;
  final String? checklistTitle;
  final String workText;

  const TaskMilestoneDraftState({
    required this.goalMode,
    required this.milestoneId,
    required this.checklistItemId,
    required this.checklistTitle,
    required this.workText,
  });
}

class TaskMilestoneDraftController {
  TaskMilestoneDraftController._();

  static TaskMilestoneDraftState apply({
    required TaskMilestoneSelection selection,
    required String currentWorkText,
    required String? previousChecklistTitle,
  }) {
    final nextTitle = selection.checklistTitle?.trim() ?? '';
    var nextWorkText = currentWorkText;

    if (selection.isLinked && nextTitle.isNotEmpty) {
      nextWorkText = nextTitle;
    } else if (previousChecklistTitle != null &&
        currentWorkText.trim() == previousChecklistTitle.trim()) {
      nextWorkText = '';
    }

    return TaskMilestoneDraftState(
      goalMode: selection.goalMode,
      milestoneId: selection.milestoneId,
      checklistItemId: selection.checklistItemId,
      checklistTitle: selection.checklistTitle,
      workText: nextWorkText,
    );
  }
}

class TaskDraftValidation {
  TaskDraftValidation._();

  static String? coreFields({
    required String axes,
    required String work,
    required bool linkedToGoal,
  }) {
    if (axes.isEmpty) return 'Заполни оси';
    if (!linkedToGoal && work.isEmpty) return 'Укажи вид работ';
    return null;
  }

  static String? goalLink({
    required bool linkedToGoal,
    required String? checklistItemId,
    required String goalWork,
  }) {
    if (linkedToGoal && (checklistItemId == null || goalWork.isEmpty)) {
      return 'Выбери работу по цели';
    }
    return null;
  }

  static String? requiredPhotos({
    required bool required,
    required int actualCount,
    required int minimumCount,
    required String stageTitle,
  }) {
    if (required && actualCount < minimumCount) {
      return 'Добавьте фото «$stageTitle»: минимум $minimumCount';
    }
    return null;
  }
}
