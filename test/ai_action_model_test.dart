import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/models/ai_assistant_result.dart';

void main() {
  test('разбирает типизированный черновик задачи', () {
    final result = AiAssistantResult.fromMap(<String, dynamic>{
      'title': 'Черновик задачи подготовлен',
      'summary': 'Армирование плиты',
      'scope': <String, dynamic>{
        'object_name': 'Мурманск',
        'date': '2026-07-21',
      },
      'action': <String, dynamic>{
        'id': 'action-1',
        'type': 'create_task_draft',
        'title': 'Черновик задачи',
        'button_label': 'Открыть черновик задачи',
        'confirmation_required': true,
        'payload': <String, dynamic>{
          'date': '2026-07-21',
          'axes': '1-5',
          'work': 'Армирование плиты',
          'assignee_ids': <String>['employee-1', 'employee-2'],
          'require_before_photo': true,
        },
      },
    });

    final action = result.action;
    expect(action, isNotNull);
    expect(action!.type, 'create_task_draft');
    expect(action.confirmationRequired, isTrue);
    expect(action.text('axes'), '1-5');
    expect(action.text('work'), 'Армирование плиты');
    expect(action.stringList('assignee_ids'), <String>[
      'employee-1',
      'employee-2',
    ]);
    expect(action.boolean('require_before_photo'), isTrue);
    expect(action.date('date'), DateTime(2026, 7, 21));
  });

  test('разбирает числовые поля из number и string', () {
    const action = AiAssistantAction(
      id: 'action-2',
      type: 'prepare_timesheet_correction',
      title: 'Корректировка',
      buttonLabel: 'Проверить',
      confirmationRequired: true,
      payload: <String, dynamic>{
        'shifts': 1.5,
        'current_shifts': '0,5',
        'daily_rate': '7000',
        'invalid': 'не число',
      },
    );

    expect(action.number('shifts'), 1.5);
    expect(action.number('current_shifts'), 0.5);
    expect(action.number('daily_rate'), 7000);
    expect(action.number('invalid'), 0);
    expect(action.number('missing'), 0);
  });

  test('старый текстовый ответ остаётся совместимым', () {
    final result = AiAssistantResult.fromMap(<String, dynamic>{
      'title': 'Сводка',
      'summary': 'Данные проверены',
      'highlights': <String>['Главное'],
      'warnings': <String>['Проверить'],
      'next_steps': <String>['Продолжить'],
      'scope': <String, dynamic>{'object_name': 'Талнах'},
    });

    expect(result.action, isNull);
    expect(result.title, 'Сводка');
    expect(result.scopeLabel, 'Талнах');
    expect(result.preliminary, isTrue);
  });
}
