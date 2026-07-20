import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/models/employee.dart';

void main() {
  test('карточка сотрудника читает стабильные идентификаторы', () {
    final employee = Employee.fromSupabase(<String, dynamic>{
      'id': 'employee-id',
      'person_id': 'person-id',
      'object_id': 'object-id',
      'fio': 'Иванов Иван Иванович',
      'position': 'Бетонщик',
      'phone': '+7 900 000-00-00',
      'object_name': 'Мурманск',
      'daily_rate': 6000,
      'is_active': true,
      'comment': '',
    });

    expect(employee.id, 'employee-id');
    expect(employee.personId, 'person-id');
    expect(employee.objectId, 'object-id');
  });

  test('миграция сохраняет старые названия и добавляет связи по ID', () {
    final migration = File(
      'supabase/migrations/20260720143000_normalize_person_object_identity.sql',
    ).readAsStringSync();

    expect(migration, contains('create table if not exists private.people'));
    expect(migration, contains('add column if not exists person_id'));
    expect(migration, contains('add column if not exists object_id'));
    expect(migration, contains('sync_named_object_reference'));
    expect(migration, contains('sync_payment_object_reference'));
    expect(migration, contains('sync_object_legacy_names'));
    expect(migration, contains('alter column person_id set not null'));
    expect(migration, contains('alter column object_id set not null'));
  });

  test('отчёты используют object_id и person_id', () {
    final migration = File(
      'supabase/migrations/20260720143100_manager_reports_stable_ids.sql',
    ).readAsStringSync();

    expect(migration, contains('manager_report_tasks_v2'));
    expect(migration, contains('manager_report_people_v2'));
    expect(migration, contains('manager_report_finance_v2'));
    expect(migration, contains('manager_report_milestones_v2'));
    expect(migration, contains('distinct on (e.person_id)'));
    expect(migration, contains('p.object_id = p_object_id'));
    expect(migration, contains('a.object_id = p_object_id'));
    expect(migration, contains('t.object_id = p_object_id'));
    expect(migration, contains('m.object_id = p_object_id'));
  });
}
