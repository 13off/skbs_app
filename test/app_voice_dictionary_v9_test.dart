import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/voice/app_voice_dictionary.dart';
import 'package:skbs_app/models/app_user_profile.dart';

AppUserProfile _profile({
  required String role,
  String objectName = '',
  String profession = '',
}) => AppUserProfile(
  id: 'user-1',
  email: 'voice@appstroy.test',
  fullName: 'Тестовый Пользователь',
  role: role,
  profession: profession,
  objectName: objectName,
  activeCompanyId: 'company-1',
  isActive: true,
);

void main() {
  test('global dictionary stays inside the actual browser grammar budget', () {
    final employees = List<String>.generate(
      100,
      (index) => 'Фамилия$index Имя$index Отчество$index',
    );
    final hints = buildAppVoiceHints(
      profile: _profile(role: 'admin', objectName: 'Мурманск'),
      employeeNames: employees,
      objectNames: const <String>['Мурманск', 'Москва', 'Талнах'],
    );

    expect(hints.length, lessThanOrEqualTo(160));
    expect(hints.toSet().length, hints.length);
  });

  test('live objects and employee names are ahead of generic manager jargon', () {
    final hints = buildAppVoiceHints(
      profile: _profile(role: 'admin', objectName: 'Мурманск'),
      employeeNames: const <String>[
        'Иванов Сергей Петрович',
        'Петров Алексей Игоревич',
      ],
      objectNames: const <String>['Мурманск', 'Москва'],
    );

    expect(hints, contains('мурманск'));
    expect(hints, contains('мурманска'));
    expect(hints, contains('москва'));
    expect(hints, contains('москвы'));
    expect(hints, contains('иванов сергей петрович'));
    expect(hints, contains('иванов'));
    expect(hints.indexOf('мурманск'), lessThan(hints.indexOf('руководитель')));
    expect(
      hints.indexOf('иванов сергей петрович'),
      lessThan(hints.indexOf('руководитель')),
    );
  });

  test('manager dictionary is balanced across AppStroy professional modules', () {
    final hints = buildAppVoiceHints(profile: _profile(role: 'admin'));

    expect(hints, contains('армирование'));
    expect(hints, contains('аванс'));
    expect(hints, contains('кандидат'));
    expect(hints, contains('договор гпх'));
    expect(hints, contains('заявка на снабжение'));
    expect(hints, contains('захватка'));
    expect(hints, contains('снилс'));
    expect(hints, contains('претензия'));
    expect(hints, contains('арматура'));
  });

  test('procurement role gets construction materials and measurement vocabulary', () {
    final hints = buildAppVoiceHints(
      profile: _profile(role: 'procurement', profession: 'снабженец'),
    );

    expect(hints, contains('вязальная проволока'));
    expect(hints, contains('фиксаторы'));
    expect(hints, contains('килограмм'));
    expect(hints, contains('тонна'));
    expect(hints, contains('кубический метр'));
    expect(hints, contains('погонный метр'));
  });

  test('long-conversation reference words remain available', () {
    final hints = buildAppVoiceHints(profile: _profile(role: 'foreman'));

    expect(hints, contains('то же самое'));
    expect(hints, contains('другой объект'));
    expect(hints, contains('этот сотрудник'));
    expect(hints, contains('эта заявка'));
    expect(hints, contains('ему'));
    expect(hints, contains('их'));
  });
}
