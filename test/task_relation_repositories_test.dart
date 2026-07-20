import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/data/task_assignee_repository.dart';

void main() {
  test('идентификаторы исполнителей очищаются и сравниваются как множества', () {
    expect(
      TaskAssigneeRepository.cleanIdSet(
        const <String>[' employee-1 ', '', 'employee-1', 'employee-2'],
      ),
      const <String>{'employee-1', 'employee-2'},
    );
    expect(
      TaskAssigneeRepository.sameIds(
        const <String>[' employee-1', 'employee-2', 'employee-1'],
        const <String>['employee-2', 'employee-1'],
      ),
      isTrue,
    );
    expect(
      TaskAssigneeRepository.sameIds(
        const <String>['employee-1'],
        const <String>['employee-2'],
      ),
      isFalse,
    );
  });

  test('данные исполнителя сохраняют прежнее преобразование Supabase', () {
    final assignee = TaskAssigneeData.fromSupabase(
      <String, dynamic>{
        'employee_id': 'employee-1',
        'employees': <String, dynamic>{
          'fio': 'Иван Иванов',
          'position': 'Бетонщик',
        },
      },
    );

    expect(assignee.employeeId, 'employee-1');
    expect(assignee.employeeName, 'Иван Иванов');
    expect(assignee.position, 'Бетонщик');
  });

  test('TaskRepository сохраняет совместимые прокси без прямых relation-запросов', () {
    final taskRepository = File(
      'lib/data/task_repository.dart',
    ).readAsStringSync();
    final assigneeRepository = File(
      'lib/data/task_assignee_repository.dart',
    ).readAsStringSync();
    final milestoneRepository = File(
      'lib/data/task_milestone_link_repository.dart',
    ).readAsStringSync();

    expect(taskRepository, contains('TaskAssigneeRepository.fetchAssignees'));
    expect(taskRepository, contains('TaskAssigneeRepository.saveIfChanged'));
    expect(taskRepository, contains('TaskMilestoneLinkRepository.fetchLink'));
    expect(taskRepository, contains('TaskMilestoneLinkRepository.saveLink'));
    expect(taskRepository, contains('fetchTaskAssigneeIds'));
    expect(taskRepository, contains('fetchTaskMilestoneLink'));
    expect(taskRepository, isNot(contains(".from('task_assignees')")));
    expect(taskRepository, isNot(contains(".from('task_milestone_links')")));

    expect(assigneeRepository, contains(".from('task_assignees')"));
    expect(assigneeRepository, contains('employees(fio, position)'));
    expect(milestoneRepository, contains(".from('task_milestone_links')"));
    expect(milestoneRepository, contains("onConflict: 'task_id'"));
    expect(
      milestoneRepository,
      contains(".delete().eq('task_id', taskId)"),
    );
  });
}
