import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edge owns object milestone supplier and UI setting intents', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final actions = File(
      'supabase/functions/ai-global-command/management_actions.ts',
    ).readAsStringSync();

    expect(index, contains('objectManagementIntent'));
    expect(index, contains('milestoneManagementIntent'));
    expect(index, contains('supplierManagementIntent'));
    expect(index, contains('uiSettingIntent'));
    expect(actions, contains('manage_object'));
    expect(actions, contains('manage_milestone'));
    expect(actions, contains('manage_supplier'));
    expect(actions, contains('toggle_app_setting'));
  });

  test('management writes are confirmed audited and role checked', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_management_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('AiActionAuditRepository.createProposed'));
    expect(coordinator, contains('markConfirmed'));
    expect(coordinator, contains('ObjectRepository.renameObject'));
    expect(coordinator, contains('ObjectRepository.archiveObject'));
    expect(coordinator, contains('MilestoneRepository.createMilestone'));
    expect(coordinator, contains('MilestoneRepository.updateMilestoneStatus'));
    expect(coordinator, contains('ProcurementRepository.saveSupplier'));
    expect(coordinator, contains('ProcurementRepository.archiveSupplier'));
  });

  test('interface settings reuse the existing theme controller', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_management_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('AppThemeController.instance'));
    expect(coordinator, contains('controller.setDark'));
    expect(coordinator, contains('controller.setUiScale'));
    expect(coordinator, contains('80, 90, 100, 110, 120'));
  });

  test('object management keeps selected voice object context coherent', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_management_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('GlobalVoiceContextController.objectNameFor'));
    expect(coordinator, contains('GlobalVoiceContextController.setObjectName'));
  });

  test('management action matching avoids silent ambiguous selection', () {
    final actions = File(
      'supabase/functions/ai-global-command/management_actions.ts',
    ).readAsStringSync();

    expect(actions, contains('Не смог однозначно определить объект'));
    expect(actions, contains('Не смог однозначно определить цель'));
    expect(actions, contains('Не смог однозначно определить поставщика'));
  });
}
