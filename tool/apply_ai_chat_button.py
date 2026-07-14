from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError(f'{label}: найдено вхождений {text.count(old)}, ожидалось 1')
    return text.replace(old, new, 1)


home_path = Path('lib/screens/home_screen.dart')
home = home_path.read_text(encoding='utf-8')

card_start = home.index('  Widget buildAiAssistantCard(BuildContext context) {')
card_end = home.index('  Widget buildObjectSelector(BuildContext context) {', card_start)
home = home[:card_start] + """  Widget buildAiAssistantButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'home-ai-assistant',
      onPressed: () => openAiAssistant(context),
      tooltip: 'ИИ-помощник',
      backgroundColor: _text,
      foregroundColor: Colors.white,
      elevation: 8,
      child: const Icon(Icons.auto_awesome_rounded),
    );
  }

""" + home[card_end:]

home = replace_once(
    home,
    """                    const SizedBox(height: 14),
                    buildAiAssistantCard(context),
                    const SizedBox(height: 24),
""",
    """                    const SizedBox(height: 24),
""",
    'удаление большой карточки ИИ',
)

old_dashboard_return = """        return buildDashboard(
          context: context,
          today: today,
          employees: data.employees,
          workedEmployeeIds: data.workedEmployeeIds,
          tasks: data.tasks,
          finance: data.finance,
          isLoading: isLoading,
          hasError: snapshot.hasError,
        );
"""
new_dashboard_return = """        return Stack(
          children: [
            buildDashboard(
              context: context,
              today: today,
              employees: data.employees,
              workedEmployeeIds: data.workedEmployeeIds,
              tasks: data.tasks,
              finance: data.finance,
              isLoading: isLoading,
              hasError: snapshot.hasError,
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                top: false,
                left: false,
                child: buildAiAssistantButton(context),
              ),
            ),
          ],
        );
"""
home = replace_once(
    home,
    old_dashboard_return,
    new_dashboard_return,
    'фиксированная кнопка ИИ на Главной',
)
home_path.write_text(home, encoding='utf-8')

screen_path = Path('lib/features/ai/presentation/ai_assistant_screen.dart')
screen = screen_path.read_text(encoding='utf-8')
screen = screen.replace("import '../../../widgets/app_page.dart';\n", '')

preset_start = screen.index('  Future<void> runPreset({')
preset_end = screen.index('  Future<void> sendPrompt()', preset_start)
screen = screen[:preset_start] + screen[preset_end:]

intro_start = screen.index('  Widget buildIntro() {')
user_message_start = screen.index('  Widget buildUserMessage(String text) {', intro_start)
empty_state = """  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.textPrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Чем помочь?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Напиши вопрос по объекту, табелю, сотрудникам, задачам или документам. Область доступа: $scopeTitle.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Помощник ничего не изменяет без твоего участия.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

"""
screen = screen[:intro_start] + empty_state + screen[user_message_start:]

conversation_start = screen.index('  Widget buildConversation() {')
composer_start = screen.index('  Widget buildComposer() {', conversation_start)
conversation = """  Widget buildConversation() {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (entries[index].userText != null)
            buildUserMessage(entries[index].userText!)
          else if (entries[index].result != null)
            buildResult(index, entries[index])
          else
            buildErrorMessage(entries[index].errorText!),
          const SizedBox(height: 12),
        ],
        if (isSending)
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Помощник анализирует данные…',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

"""
screen = screen[:conversation_start] + conversation + screen[composer_start:]

build_start = screen.index('  @override\n  Widget build(BuildContext context) {')
quick_class_start = screen.index('class _AiQuickAction {', build_start)
conversation_class_start = screen.index('class _AiConversationEntry {', quick_class_start)
new_build = """  @override
  Widget build(BuildContext context) {
    final hasConversation = entries.isNotEmpty || isSending;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('ИИ-помощник')),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  Expanded(
                    child: hasConversation
                        ? buildConversation()
                        : buildEmptyState(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: buildComposer(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

"""
screen = screen[:build_start] + new_build + screen[conversation_class_start:]
screen_path.write_text(screen, encoding='utf-8')

test_path = Path('test/ai_assistant_contract_test.dart')
test_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('home opens AI chat from a fixed bottom-right button', () {
    final home = source('lib/screens/home_screen.dart');
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(home, contains('AiAssistantScreen('));
    expect(home, contains('FloatingActionButton('));
    expect(home, contains("heroTag: 'home-ai-assistant'"));
    expect(home, contains('Positioned('));
    expect(home, contains('right: 18'));
    expect(home, contains('bottom: 18'));
    expect(home, isNot(contains('buildAiAssistantCard')));
    expect(shell, isNot(contains("label: 'ИИ'")));
  });

  test('assistant screen contains only chat without quick requests', () {
    final screen = source(
      'lib/features/ai/presentation/ai_assistant_screen.dart',
    );

    expect(screen, contains("'Чем помочь?'"));
    expect(screen, contains('TextField('));
    expect(screen, contains('Expanded('));
    expect(screen, contains("mode: 'chat'"));
    expect(screen, isNot(contains("'Быстрые действия'")));
    expect(screen, isNot(contains("'Проверить табель'")));
    expect(screen, isNot(contains("'Сводка по объекту'")));
    expect(screen, isNot(contains("'Подготовить документ'")));
    expect(screen, isNot(contains('class _AiQuickAction')));
  });

  test('assistant keeps preliminary result and human review', () {
    final screen = source(
      'lib/features/ai/presentation/ai_assistant_screen.dart',
    );

    expect(screen, contains("'Предварительный результат'"));
    expect(screen, contains("'Отметить как проверенное'"));
    expect(screen, contains("'Проверено человеком'"));
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

  test('edge function is company scoped read only and has no external key', () {
    final edge = source('supabase/functions/ai-assistant/index.ts');

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("user_profiles")'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('.eq("company_id", activeCompanyId)'));
    expect(edge, contains('role === "foreman"'));
    expect(edge, contains('assignedObjectName'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('OPENAI_API_KEY')));
    expect(edge, isNot(contains('api.openai.com')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });
}
""", encoding='utf-8')
