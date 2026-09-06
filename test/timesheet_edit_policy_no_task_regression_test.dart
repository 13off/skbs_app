import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/developer/models/task_policy.dart';

void main() {
  test('timesheet window does not alter existing task restriction fields', () {
    const policy = TaskPolicy(
      foremanCanEditPastTasks: true,
      editWindowDays: 3,
      foremanTimesheetEditWindowDays: 1,
    );

    final changed = policy.copyWith(foremanTimesheetEditWindowDays: 7);
    expect(changed.foremanCanEditPastTasks, isTrue);
    expect(changed.editWindowDays, 3);
    expect(changed.foremanTimesheetEditWindowDays, 7);
  });
}
