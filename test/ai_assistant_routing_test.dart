import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/data/ai_assistant_repository.dart';

void main() {
  test('команда создания задачи направляется в сервер действий', () {
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Поставь Иванову на завтра задачу армирование плиты',
      ),
      'ai-action-draft',
    );
  });

  test('команда подготовки документа направляется в сервер документов', () {
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Подготовь заявление на работу для Иванова',
      ),
      'ai-document-draft',
    );
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Составь служебную записку по отсутствующим чекам',
      ),
      'ai-document-draft',
    );
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Сформируй трудовой договор для Сидорова',
      ),
      'ai-document-draft',
    );
  });

  test('проверка табеля остаётся в структурированном помощнике', () {
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Проверь табель за сегодня',
      ),
      'ai-assistant',
    );
  });

  test('свободный вопрос остаётся в универсальном поиске', () {
    expect(
      AiAssistantRepository.functionNameFor(
        mode: 'chat',
        prompt: 'Какой телефон у Иванова?',
      ),
      'ai-search',
    );
  });
}
