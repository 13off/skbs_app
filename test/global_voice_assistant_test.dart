import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/voice/app_voice_dictionary.dart';
import 'package:skbs_app/models/app_user_profile.dart';

AppUserProfile profileFor(String role, {String actualRole = ''}) {
  return AppUserProfile(
    id: 'user-1',
    email: 'test@appstroy.local',
    fullName: 'Тестовый Пользователь',
    role: role,
    actualRole: actualRole.isEmpty ? role : actualRole,
    objectName: role == 'foreman' ? 'Мурманск' : '',
    activeCompanyId: 'company-1',
    isActive: true,
  );
}

void main() {
  test('руководитель получает словарь всех основных модулей AppСтрой', () {
    final hints = buildAppVoiceHints(profile: profileFor('admin'));

    expect(hints, contains('армирование'));
    expect(hints, contains('реестр выплат'));
    expect(hints, contains('собеседование'));
    expect(hints, contains('претензия'));
    expect(hints, contains('поставщик'));
    expect(hints, contains('веха'));
  });

  test('каждая специальность получает свой приоритетный словарь', () {
    expect(
      buildAppVoiceHints(profile: profileFor('accountant')),
      contains('дубликат выплаты'),
    );
    expect(
      buildAppVoiceHints(profile: profileFor('hr')),
      contains('согласие на персональные данные'),
    );
    expect(
      buildAppVoiceHints(profile: profileFor('lawyer')),
      contains('решение руководителя'),
    );
    expect(
      buildAppVoiceHints(profile: profileFor('procurement')),
      contains('заявка на снабжение'),
    );
    expect(
      buildAppVoiceHints(profile: profileFor('employee')),
      contains('начать рабочий день'),
    );
  });

  test('живые ФИО и объекты подмешиваются в распознавание', () {
    final hints = buildAppVoiceHints(
      profile: profileFor('admin'),
      employeeNames: const <String>['Иванов Иван Иванович', 'Азиз Каримов'],
      objectNames: const <String>['Мурманск', 'Талнах'],
    );

    expect(hints, contains('иванов иван иванович'));
    expect(hints, contains('иванов'));
    expect(hints, contains('иван'));
    expect(hints, contains('азиз'));
    expect(hints, contains('мурманск'));
    expect(hints, contains('талнах'));
  });

  test('глобальный микрофон монтируется выше Navigator и не пропадает на route', () {
    final app = File('lib/main.dart').readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final root = File(
      'lib/features/voice/presentation/global_voice_root_layer.dart',
    ).readAsStringSync();

    expect(app, contains('GlobalVoiceRootLayer('));
    expect(app, contains('builder: (context, child) => AppScaleViewport('));
    expect(root, contains('GlobalVoiceAssistantLayer('));
    expect(root, contains('AppVoiceProfileController.state'));
    expect(main, contains('AppVoiceProfileController.configure(profile)'));
    expect(main, contains('profile.isEmployee'));
    expect(main, contains('CompanyChatShell('));
  });

  test('глобальный голос использует общий ИИ и штатное подтверждение действий', () {
    final layer = File(
      'lib/features/voice/presentation/global_voice_assistant_layer.dart',
    ).readAsStringSync();
    final recognition = File(
      'lib/features/voice/app_voice_recognition.dart',
    ).readAsStringSync();

    expect(layer, contains('AiAssistantRepository.request('));
    expect(layer, contains('AiActionExecutionCoordinator.execute('));
    expect(layer, contains("mode: 'chat'"));
    expect(layer, contains('loadHints()'));
    expect(layer, contains('EmployeeRepository.fetchEmployees('));
    expect(layer, contains('ObjectRepository.fetchObjectNames()'));
    expect(recognition, contains('prioritizeAxes: false'));
  });

  test('просмотр роли и обычный сотрудник не получают административную запись', () {
    final layer = File(
      'lib/features/voice/presentation/global_voice_assistant_layer.dart',
    ).readAsStringSync();

    expect(
      layer,
      contains('!widget.profile.isRolePreview && !widget.profile.isEmployee'),
    );
    expect(layer, contains('В режиме просмотра роли голосовые изменения отключены'));
    expect(layer, contains('этот тип изменения пока недоступен голосом'));
  });
}
