import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> readGate() {
    final file = File('config/personal-data-production-gate.json');
    expect(file.existsSync(), isTrue);
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  test('реальные персональные документы по умолчанию заблокированы', () {
    final gate = readGate();

    expect(gate['schema_version'], 1);
    expect(gate['real_personal_documents_enabled'], isFalse);
    expect(gate['status'], 'blocked');
    expect((gate['approved_by'] as String).trim(), isEmpty);
    expect((gate['approved_at'] as String).trim(), isEmpty);
  });

  test('gate содержит полный набор обязательных доказательств', () {
    final gate = readGate();
    final evidence = Map<String, dynamic>.from(gate['evidence'] as Map);
    const required = <String>{
      'russian_storage_location_confirmed',
      'data_controller_details_approved',
      'personal_data_consent_approved',
      'retention_and_deletion_policy_approved',
      'download_audit_log_verified',
      'backup_and_restore_tested',
      'access_offboarding_tested',
      'incident_response_owner_assigned',
    };

    expect(evidence.keys.toSet(), required);
    expect(evidence.values.every((value) => value is bool), isTrue);
  });

  test('включение production требует всех доказательств и утверждения', () {
    final gate = readGate();
    final enabled = gate['real_personal_documents_enabled'] == true;
    final evidence = Map<String, dynamic>.from(gate['evidence'] as Map);

    if (enabled) {
      expect(gate['status'], 'approved');
      expect(evidence.values.every((value) => value == true), isTrue);
      expect((gate['approved_by'] as String).trim(), isNotEmpty);
      expect((gate['approved_at'] as String).trim(), isNotEmpty);
      expect(DateTime.tryParse(gate['approved_at'] as String), isNotNull);
    } else {
      expect(gate['status'], 'blocked');
    }
  });

  test('документация запрещает преждевременную работу с реальными файлами', () {
    final gateDoc = File(
      'docs/personal-data-production-gate.md',
    ).readAsStringSync();
    final personalData = File('docs/personal-data.md').readAsStringSync();
    final checklist = File('docs/release-checklist.md').readAsStringSync();

    expect(gateDoc, contains('Статус на момент создания документа: **BLOCKED**'));
    expect(gateDoc, contains('тестовые, обезличенные'));
    expect(gateDoc, contains('Российское хранение'));
    expect(gateDoc, contains('Журнал доступа'));
    expect(gateDoc, contains('Резервное копирование'));
    expect(gateDoc, contains('Отключение доступа'));
    expect(gateDoc, contains('Инциденты'));
    expect(personalData, contains('real_personal_documents_enabled'));
    expect(personalData, contains('CI должен отклонять конфигурацию'));
    expect(checklist, contains('Gate реальных персональных документов'));
    expect(checklist, contains('backup/restore test'));
  });
}
