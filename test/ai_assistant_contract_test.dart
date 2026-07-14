import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('home opens a built-in AI assistant without adding a crowded tab', () {
    final home = source('lib/screens/home_screen.dart');
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(home, contains('AiAssistantScreen('));
    expect(home, contains("'ИИ-помощник'"));
    expect(home, contains('AppPageRoute<void>('));
    expect(shell, isNot(contains("label: 'ИИ'")));
  });

  test('assistant follows preview review execution safety flow', () {
    final screen = source(
      'lib/features/ai/presentation/ai_assistant_screen.dart',
    );

    expect(screen, contains("'Предварительный результат'"));
    expect(screen, contains("'Отметить как проверенное'"));
    expect(screen, contains("'Проверено человеком'"));
    expect(screen, contains("'Проверить табель'"));
    expect(screen, contains("'Сводка по объекту'"));
    expect(screen, contains("'Подготовить документ'"));
  });

  test('client calls only the authenticated server function', () {
    final repository = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );

    expect(repository, contains("functions.invoke(\n      'ai-assistant'"));
    expect(repository, contains("'company_id'"));
    expect(repository, contains("'object_name'"));
    expect(repository, isNot(contains('OPENAI_API_KEY')));
  });

  test('edge function is company scoped read only and keeps secrets server side', () {
    final edge = source('supabase/functions/ai-assistant/index.ts');

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("user_profiles")'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('.eq("company_id", activeCompanyId)'));
    expect(edge, contains('role === "foreman"'));
    expect(edge, contains('assignedObjectName'));
    expect(edge, contains('Deno.env.get("OPENAI_API_KEY")'));
    expect(edge, contains('Deno.env.get("OPENAI_MODEL")'));
    expect(edge, contains('store: false'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
    expect(edge, isNot(contains('sk-')));
  });
}
