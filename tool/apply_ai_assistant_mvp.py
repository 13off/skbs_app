from pathlib import Path

home = Path('lib/screens/home_screen.dart')
text = home.read_text(encoding='utf-8')

import_marker = "import '../data/task_repository.dart';\n"
imports = (
    "import '../data/task_repository.dart';\n"
    "import '../features/ai/presentation/ai_assistant_screen.dart';\n"
)
if "features/ai/presentation/ai_assistant_screen.dart" not in text:
    if import_marker not in text:
        raise RuntimeError('Не найден импорт task_repository')
    text = text.replace(import_marker, imports, 1)

model_marker = "import '../models/task_item_data.dart';\n"
model_imports = (
    "import '../models/task_item_data.dart';\n"
    "import '../navigation/app_page_route.dart';\n"
)
if "navigation/app_page_route.dart" not in text:
    if model_marker not in text:
        raise RuntimeError('Не найден импорт task_item_data')
    text = text.replace(model_marker, model_imports, 1)

selector_marker = "  Widget buildObjectSelector(BuildContext context) {\n"
assistant_methods = """  void openAiAssistant(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => AiAssistantScreen(
          profile: widget.profile,
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  Widget buildAiAssistantCard(BuildContext context) {
    return PremiumPressable(
      onTap: () => openAiAssistant(context),
      borderRadius: BorderRadius.circular(26),
      child: PremiumWorkCard(
        radius: 26,
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F0EC),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _line),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _text,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ИИ-помощник',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Проверить табель, собрать сводку или подготовить черновик',
                    style: TextStyle(
                      color: _muted,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

"""
if 'Widget buildAiAssistantCard(BuildContext context)' not in text:
    if selector_marker not in text:
        raise RuntimeError('Не найден buildObjectSelector')
    text = text.replace(selector_marker, assistant_methods + selector_marker, 1)

card_marker = (
    "                    const SizedBox(height: 24),\n"
    "                    _DashboardMetricCard(\n"
)
card_replacement = (
    "                    const SizedBox(height: 14),\n"
    "                    buildAiAssistantCard(context),\n"
    "                    const SizedBox(height: 24),\n"
    "                    _DashboardMetricCard(\n"
)
if 'buildAiAssistantCard(context),' not in text:
    if text.count(card_marker) != 1:
        raise RuntimeError('Не найдено уникальное место для карточки ИИ')
    text = text.replace(card_marker, card_replacement, 1)

home.write_text(text, encoding='utf-8')
