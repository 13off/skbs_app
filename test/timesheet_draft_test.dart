import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/timesheet/models/timesheet_draft.dart';

void main() {
  test('загруженный черновик не содержит изменений', () {
    final draft = TimesheetDraft.fromValues(const <String, double>{
      'one': 1,
      'two': 0.5,
    });

    expect(draft.hasChanges, isFalse);
    expect(draft.changedValues, isEmpty);
    expect(draft.workedCountFor(const <String>['one', 'two', 'three']), 2);
    expect(draft.totalFor(const <String>['one', 'two', 'three']), 1.5);
  });

  test('одиночное изменение хранит текущее и исходное значение', () {
    final loaded = TimesheetDraft.fromValues(const <String, double>{'one': 1});
    final changed = loaded.withValue('one', 1.5);

    expect(changed.hasChanges, isTrue);
    expect(changed.valueFor('one'), 1.5);
    expect(changed.originalValueFor('one'), 1);
    expect(changed.changedValues, const <String, double>{'one': 1.5});
    expect(loaded.valueFor('one'), 1);
  });

  test('массовое изменение пропускает пустые идентификаторы', () {
    final draft = TimesheetDraft.empty().withValues(
      const <String?>['one', null, '', 'two'],
      1,
    );

    expect(draft.values, const <String, double>{'one': 1, 'two': 1});
    expect(draft.workedCountFor(const <String>['one', 'two']), 2);
  });

  test('возврат к исходному значению снимает признак изменений', () {
    final loaded = TimesheetDraft.fromValues(const <String, double>{'one': 1});
    final reverted = loaded.withValue('one', 2).withValue('one', 1);

    expect(reverted.hasChanges, isFalse);
    expect(reverted.changedValues, isEmpty);
  });

  test('markSaved делает текущие значения новым исходником', () {
    final saved = TimesheetDraft.empty().withValue('one', 1.5).markSaved();

    expect(saved.hasChanges, isFalse);
    expect(saved.valueFor('one'), 1.5);
    expect(saved.originalValueFor('one'), 1.5);
  });
}
