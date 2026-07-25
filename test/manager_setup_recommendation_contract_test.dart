import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Контракт также служит безопасным триггером публикации Web/PWA.
void main() {
  test('setup recommendation appears only on the real manager home', () {
    final manager = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/company/presentation/company_setup_recommendation_card.dart',
    ).readAsStringSync();
    final developer = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(manager, contains('CompanySetupRecommendationCard'));
    expect(manager, contains('managerHome('));
    expect(card, contains("widget.profile.role == 'admin'"));
    expect(card, contains("widget.profile.actualRole == 'admin'"));
    expect(card, contains('!widget.profile.isRolePreview'));
    expect(developer, isNot(contains('CompanySetupScreen')));
    expect(developer, isNot(contains("title: 'Запуск компании'")));
    expect(settings, isNot(contains('CompanySetupScreen')));
    expect(settings, isNot(contains("title: 'Запуск компании'")));
  });

  test('recommendation is optional, detailed and permanently dismissible locally', () {
    final card = File(
      'lib/features/company/presentation/company_setup_recommendation_card.dart',
    ).readAsStringSync();
    final details = File(
      'lib/features/company/presentation/company_setup_screen.dart',
    ).readAsStringSync();

    expect(card, contains('company_setup_recommendation_hidden:'));
    expect(card, contains('SharedPreferences.getInstance'));
    expect(card, contains("preferences.setBool(dismissalKey, true)"));
    expect(card, contains('Больше не показывать'));
    expect(card, contains('progress.coreCompleted'));
    expect(card, contains('progress.completedRequired'));
    expect(card, contains('progress.requiredSteps.length'));
    expect(card, contains('progress.nextRequiredStep'));
    expect(card, contains('CompanySetupScreen'));

    expect(details, contains("title: 'Настройка компании'"));
    expect(details, contains('Рекомендованный чек-лист'));
    expect(details, contains('Это рекомендации, а не обязательные правила'));
    expect(details, isNot(contains('DeveloperDemoCenterScreen')));
    expect(details, isNot(contains('безопасное демо')));
  });
}
