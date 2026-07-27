import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Web/PWA publication trigger after redundant controls cleanup.
// Web/PWA publication trigger after MAX candidate messaging integration.
// Web/PWA retry after updating the MAX messaging regression contract.
void main() {
  test('dedicated data control screen and entry points are removed', () {
    final developer = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(developer, contains('static const int pageCount = 2;'));
    expect(developer, isNot(contains('DataGovernanceScreen')));
    expect(developer, isNot(contains("label: 'Контроль'")));
    expect(settings, isNot(contains('DataGovernanceScreen')));
    expect(settings, isNot(contains("title: 'Контроль данных'")));
    expect(
      File(
        'lib/features/developer/presentation/data_governance_screen.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/features/developer/data/data_governance_repository.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/developer/models/data_governance.dart').existsSync(),
      isFalse,
    );
  });

  test('floating AI launcher is removed while AI remains inside chat', () {
    final homeScreen = File('lib/screens/home_screen.dart').readAsStringSync();
    final homeActions = File(
      'lib/screens/home/home_actions.dart',
    ).readAsStringSync();
    final homeView = File(
      'lib/screens/home/home_view.dart',
    ).readAsStringSync();
    final chat = File(
      'lib/features/company_chat/presentation/company_chat_shell.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/company_chat/data/company_chat_repository.dart',
    ).readAsStringSync();

    expect(homeScreen, isNot(contains('AiAssistantScreen')));
    expect(homeScreen, isNot(contains('app_page_route.dart')));
    expect(homeActions, isNot(contains('home-ai-assistant')));
    expect(homeActions, isNot(contains('buildAiAssistantButton')));
    expect(homeView, isNot(contains('buildAiAssistantButton')));

    expect(chat, contains("ValueKey<String>('company-chat-launcher')"));
    expect(chat, contains('class _ChatLauncherButton'));
    expect(chat, contains("'ИИ-помощник'"));
    expect(chat, contains('Icons.lock_rounded'));
    expect(repository, isNot(contains('!value.isAssistant')));
  });
}
