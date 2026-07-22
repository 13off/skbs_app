import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/developer/models/data_governance.dart';

void main() {
  test('governance center parses trash and semantic audit actions', () {
    final center = DataGovernanceCenter.fromJson(<String, dynamic>{
      'objects': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'object-1',
          'name': 'Объект',
          'is_active': true,
        },
      ],
      'trash': <Map<String, dynamic>>[
        <String, dynamic>{
          'entity_type': 'attendance',
          'entity_id': 'row-1',
          'title': 'Сотрудник',
          'subtitle': '22.07.2026 • worked',
          'object_id': 'object-1',
          'object_name': 'Объект',
          'deleted_at': '2026-07-22T20:00:00Z',
          'delete_reason': 'Ошибка',
          'metadata': <String, dynamic>{'status': 'worked'},
        },
      ],
      'audit': <Map<String, dynamic>>[
        <String, dynamic>{
          'audit_id': '1',
          'entity_type': 'attendance',
          'entity_id': 'row-1',
          'action': 'UPDATE',
          'actor_name': 'Администратор',
          'created_at': '2026-07-22T20:01:00Z',
          'metadata': <String, dynamic>{
            '_semantic_action': 'restored',
            'deleted_at': true,
          },
        },
      ],
    });

    expect(center.objects.single.name, 'Объект');
    expect(center.trash.single.typeTitle, 'Табель');
    expect(center.audit.single.semanticAction, 'restored');
  });

  test('soft deletion is enabled only for supported core entities', () {
    final policies = File(
      'supabase/migrations/20260722222100_unified_data_governance_policies.sql',
    ).readAsStringSync();

    expect(policies, contains('attendance_soft_delete'));
    expect(policies, contains('payments_soft_delete'));
    expect(policies, contains('milestones_soft_delete'));
    expect(policies, contains('deleted_at is null'));
    expect(policies, contains('system.audit.view'));
    expect(policies, contains('permission_catalog_deny_direct'));
  });

  test('audit uses valid database action codes and stores semantic action', () {
    final core = File(
      'supabase/migrations/20260722222000_unified_data_governance_core.sql',
    ).readAsStringSync();

    expect(core, contains('tg_op,'));
    expect(core, contains("'_semantic_action'"));
    expect(core, contains('v_semantic_action'));
    expect(core, isNot(contains("v_action := 'created'")));
  });

  test('center combines all supported trash entities and task audit', () {
    final center = File(
      'supabase/migrations/20260722222200_unified_data_governance_center.sql',
    ).readAsStringSync();
    final restore = File(
      'supabase/migrations/20260722222300_unified_data_governance_restore.sql',
    ).readAsStringSync();

    for (final entity in <String>[
      "'task'",
      "'attendance'",
      "'payment'",
      "'milestone'",
      "'employee'",
      "'object'",
      "'legal_document'",
    ]) {
      expect(center, contains(entity));
    }
    expect(center, contains('task_action_audit'));
    expect(center, contains('audit_log'));
    expect(restore, contains('restore_task'));
    expect(restore, contains('system.recycle_bin.manage'));
    expect(restore, contains("v_type = 'attendance'"));
    expect(restore, contains("v_type = 'payment'"));
    expect(restore, contains("v_type = 'milestone'"));
    expect(restore, contains("v_type = 'employee'"));
    expect(restore, contains("v_type = 'object'"));
    expect(restore, contains("v_type = 'legal_document'"));
  });
}
