import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/voice/app_voice_dictionary.dart';
import 'package:skbs_app/models/app_user_profile.dart';

AppUserProfile _profile(String role, {String objectName = ''}) {
  return AppUserProfile(
    id: 'user-1',
    email: 'voice@appstroy.local',
    fullName: 'Тестовый Пользователь',
    role: role,
    objectName: objectName,
    activeCompanyId: 'company-1',
    isActive: true,
  );
}

void main() {
  test('боевой V2 использует единый ролевой словарь AppСтрой', () {
    final source = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(source, contains("../../voice/app_voice_dictionary.dart"));
    expect(source, contains('buildAppVoiceHints('));
    expect(source, contains('EmployeeRepository.fetchEmployees('));
    expect(source, contains('ObjectRepository.fetchObjectNames()'));
    expect(source, contains('profile.isForeman ? _objectName : null'));
    expect(source, isNot(contains('_globalVoiceHintsV2')));
  });

  test('боевой V2 передает динамические hints без осевого приоритета', () {
    final source = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(source, contains('final hints = await _loadVoiceHints();'));
    expect(source, contains('hints: hints'));
    expect(source, contains('prioritizeAxes: false'));
  });

  test('словарь бухгалтера не смешивается с HR приоритетами', () {
    final hints = buildAppVoiceHints(profile: _profile('accountant'));
    expect(hints, contains('дубликат выплаты'));
    expect(hints, isNot(contains('собеседование')));
  });

  test('словарь HR не смешивается с бухгалтерскими приоритетами', () {
    final hints = buildAppVoiceHints(profile: _profile('hr'));
    expect(hints, contains('собеседование'));
    expect(hints, isNot(contains('дубликат выплаты')));
  });

  test('юрист снабженец сотрудник и руководитель получают свои словари', () {
    final legal = buildAppVoiceHints(profile: _profile('lawyer'));
    final procurement = buildAppVoiceHints(profile: _profile('procurement'));
    final employee = buildAppVoiceHints(
      profile: _profile('employee', objectName: 'Мурманск'),
    );
    final admin = buildAppVoiceHints(profile: _profile('admin'));

    expect(legal, contains('решение руководителя'));
    expect(procurement, contains('заявка на снабжение'));
    expect(employee, contains('начать рабочий день'));
    expect(employee, isNot(contains('решение руководителя')));
    expect(employee, isNot(contains('заявка на снабжение')));
    expect(employee, contains('мурманск'));
    expect(admin, contains('реестр выплат'));
    expect(admin, contains('собеседование'));
    expect(admin, contains('решение руководителя'));
    expect(admin, contains('заявка на снабжение'));
    expect(admin, contains('армирование'));
  });

  test('живые ФИО и объекты попадают в словарь отдельными вариантами', () {
    final hints = buildAppVoiceHints(
      profile: _profile('admin'),
      employeeNames: const [
        'Иванов Иван Иванович',
        'Азиз Каримов',
      ],
      objectNames: const ['Мурманск', 'Талнах'],
    );

    expect(hints, contains('иванов иван иванович'));
    expect(hints, contains('иванов'));
    expect(hints, contains('иван'));
    expect(hints, contains('азиз каримов'));
    expect(hints, contains('азиз'));
    expect(hints, contains('мурманск'));
    expect(hints, contains('талнах'));
  });

  test('обычный сотрудник не загружает списки компании для голосового словаря', () {
    final source = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(source, contains('if (profile.isEmployee) return const <String>[];'));
    expect(source, contains('buildAppVoiceHints('));
  });
}
