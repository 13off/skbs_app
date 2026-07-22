from pathlib import Path

path = Path('lib/features/ai/presentation/ai_assistant_confirmed_screen.dart')
text = path.read_text(encoding='utf-8')
old_import = "import '../models/ai_assistant_result.dart';\n"
new_import = (
    "import '../models/ai_assistant_result.dart';\n"
    "import 'widgets/ai_operational_prompt_chips.dart';\n"
)
if old_import not in text:
    raise SystemExit('assistant result import not found')
text = text.replace(old_import, new_import, 1)
old_block = """            const SizedBox(height: 12),
            Text(
              'Помощник ничего не изменяет без твоего участия.',
"""
new_block = """            const SizedBox(height: 16),
            AiOperationalPromptChips(
              enabled: !isSending,
              onSelected: (prompt) {
                promptController.text = prompt;
                sendPrompt();
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Помощник ничего не изменяет без твоего участия.',
"""
if old_block not in text:
    raise SystemExit('empty state insertion point not found')
text = text.replace(old_block, new_block, 1)
path.write_text(text, encoding='utf-8')
