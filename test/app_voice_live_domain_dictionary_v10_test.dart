import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/voice/app_voice_dictionary.dart';
import 'package:skbs_app/models/app_user_profile.dart';

AppUserProfile _profile(String role) => AppUserProfile(
  id: 'user-1',
  email: 'voice@appstroy.test',
  fullName: 'Тестовый Пользователь',
  role: role,
  activeCompanyId: 'company-1',
  isActive: true,
);

void main() {
  test('HR live candidate names participate in speech hints', () {
    final hints = buildAppVoiceHints(
      profile: _profile('hr'),
      candidateNames: const <String>[
        'Ахмедов Рустам Рашидович',
        'Сергеев Антон Олегович',
      ],
    );

    expect(hints, contains('ахмедов рустам рашидович'));
    expect(hints, contains('ахмедов'));
    expect(hints, contains('сергеев антон олегович'));
    expect(hints.indexOf('ахмедов'), lessThan(hints.indexOf('кандидат')));
  });

  test('procurement live suppliers and materials participate in speech hints', () {
    final hints = buildAppVoiceHints(
      profile: _profile('procurement'),
      supplierNames: const <String>['ООО СтройСнаб', 'Север Бетон'],
      materialNames: const <String>[
        'фанера ламинированная',
        'арматура А500С',
      ],
    );

    expect(hints, contains('ооо стройснаб'));
    expect(hints, contains('стройснаб'));
    expect(hints, contains('фанера ламинированная'));
    expect(hints, contains('фанера'));
    expect(hints, contains('арматура а500с'));
  });

  test('manager live domain buckets stay balanced and inside Web Speech budget', () {
    final hints = buildAppVoiceHints(
      profile: _profile('admin'),
      employeeNames: List<String>.generate(
        80,
        (index) => 'Работников$index Иван$index Петрович$index',
      ),
      objectNames: const <String>['Мурманск', 'Москва', 'Талнах'],
      candidateNames: const <String>[
        'Кандидатов Сергей Иванович',
        'Соискателей Артем Андреевич',
      ],
      supplierNames: const <String>['СтройСнаб', 'МонолитРесурс'],
      materialNames: const <String>['фиксаторы арматуры', 'вязальная проволока'],
    );

    expect(hints.length, lessThanOrEqualTo(160));
    expect(hints.toSet().length, hints.length);
    expect(hints, contains('кандидатов сергей иванович'));
    expect(hints, contains('стройснаб'));
    expect(hints, contains('фиксаторы арматуры'));
    expect(hints, contains('то же самое'));
    expect(hints, contains('армирование'));
    expect(hints, contains('аванс'));
    expect(hints, contains('договор гпх'));
    expect(hints, contains('заявка на снабжение'));
  });

  test('global layer loads live role-specific dictionaries in parallel', () {
    final source = File(
      'lib/features/ai/presentation/global_voice_assistant_layer_v2.dart',
    ).readAsStringSync();

    expect(source, contains('RecruitmentRepository.fetchApplications'));
    expect(source, contains('ProcurementRepository.fetchSuppliers'));
    expect(source, contains('ProcurementRepository.fetchRequests'));
    expect(source, contains('Future.wait<List<String>>'));
    expect(source, contains('candidateNames: values[2]'));
    expect(source, contains('supplierNames: values[3]'));
    expect(source, contains('materialNames: values[4]'));
    expect(source, contains('!profile.isAdmin && !profile.isHr'));
    expect(source, contains('!profile.isAdmin && !profile.isProcurement'));
  });
}
