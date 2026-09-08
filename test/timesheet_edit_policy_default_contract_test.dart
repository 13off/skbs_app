import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/developer/models/task_policy.dart';

void main() {
  test('default policy keeps previous-day editing unlimited', () {
    expect(TaskPolicy.defaults.foremanTimesheetEditWindowDays, isNull);
    expect(
      TaskPolicy.defaults.canForemanEditTimesheetDate(
        DateTime(2025, 1, 1),
        today: DateTime(2026, 9, 6),
      ),
      isTrue,
    );
  });
}
