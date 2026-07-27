import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/milestones/presentation/task_milestone_picker.dart';
import 'package:skbs_app/features/tasks/task_draft_support.dart';

void main() {
  test('общая валидация сохраняет тексты полей и фотографий', () {
    expect(
      TaskDraftValidation.coreFields(
        axes: '',
        work: '',
        linkedToGoal: false,
      ),
      'Заполни оси',
    );
    expect(
      TaskDraftValidation.coreFields(
        axes: '1-2',
        work: '',
        linkedToGoal: false,
      ),
      'Укажи вид работ',
    );
    expect(
      TaskDraftValidation.goalLink(
        linkedToGoal: true,
        checklistItemId: null,
        goalWork: '',
      ),
      'Выбери работу по цели',
    );
    expect(
      TaskDraftValidation.requiredPhotos(
        required: true,
        actualCount: 0,
        minimumCount: 2,
        stageTitle: 'До',
      ),
      'Добавьте фото «До»: минимум 2',
    );
  });

  test('общая обработка цели синхронизирует вид работ', () {
    const linked = TaskMilestoneSelection(
      milestoneId: 'milestone',
      checklistItemId: 'item',
      checklistTitle: 'Армирование плиты',
      goalMode: true,
    );
    final linkedState = TaskMilestoneDraftController.apply(
      selection: linked,
      currentWorkText: 'Старый текст',
      previousChecklistTitle: null,
    );

    expect(linkedState.goalMode, isTrue);
    expect(linkedState.workText, 'Армирование плиты');

    const unlinked = TaskMilestoneSelection(
      milestoneId: null,
      checklistItemId: null,
      checklistTitle: null,
      goalMode: false,
    );
    final unlinkedState = TaskMilestoneDraftController.apply(
      selection: unlinked,
      currentWorkText: 'Армирование плиты',
      previousChecklistTitle: 'Армирование плиты',
    );

    expect(unlinkedState.goalMode, isFalse);
    expect(unlinkedState.workText, isEmpty);
  });

  test('создание и редактор используют единые элементы', () {
    final createActions = File(
      'lib/screens/task_create/task_create_actions.dart',
    ).readAsStringSync();
    final createSections = File(
      'lib/screens/task_create/task_create_sections.dart',
    ).readAsStringSync();
    final detailsActions = File(
      'lib/screens/task_details/task_details_actions.dart',
    ).readAsStringSync();
    final detailsSections = File(
      'lib/screens/task_details/task_details_sections.dart',
    ).readAsStringSync();

    for (final actions in <String>[createActions, detailsActions]) {
      expect(actions, contains('showTaskAssigneePicker('));
      expect(actions, contains('TaskMilestoneDraftController.apply('));
      expect(actions, contains('TaskDraftValidation.coreFields('));
      expect(actions, isNot(contains('showModalBottomSheet<Set<String>>')));
    }
    for (final sections in <String>[createSections, detailsSections]) {
      expect(sections, contains('TaskAssigneeSummaryCard('));
      expect(sections, contains('TaskPhotoGrid<'));
      expect(sections, isNot(contains('GridView.builder(')));
    }
  });
}
