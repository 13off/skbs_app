import 'package:flutter/material.dart';

import '../models/ai_assistant_result.dart';

class AiActionConfirmationSheet extends StatelessWidget {
  final AiAssistantAction action;

  const AiActionConfirmationSheet({
    super.key,
    required this.action,
  });

  static Future<bool> show(
    BuildContext context, {
    required AiAssistantAction action,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiActionConfirmationSheet(action: action),
    );
    return result == true;
  }

  String get actionTitle {
    return switch (action.type) {
      'create_task_draft' => 'Открыть черновик задачи?',
      'prepare_document' => 'Открыть черновик документа?',
      'prepare_timesheet_correction' => 'Изменить табель?',
      'prepare_employee_update' => 'Открыть изменение сотрудника?',
      'create_reminder' => 'Открыть настройки напоминания?',
      _ => 'Подтвердить действие?',
    };
  }

  String get confirmationLabel {
    return switch (action.type) {
      'prepare_timesheet_correction' => 'Подтвердить и изменить',
      _ => 'Подтвердить и продолжить',
    };
  }

  bool get writesImmediately => action.type == 'prepare_timesheet_correction';

  List<(String, String)> get details {
    final rows = <(String, String)>[];

    void add(String title, String value) {
      final clean = value.trim();
      if (clean.isNotEmpty) rows.add((title, clean));
    }

    add('Объект', action.text('object_name'));
    add('Сотрудник', action.text('employee_name'));
    add('Дата', _date(action.text('date')));

    switch (action.type) {
      case 'create_task_draft':
        add('Работы', action.text('work'));
        add('Оси', action.text('axes'));
        add('Исполнители', action.stringList('assignee_names').join(', '));
        if (action.boolean('require_before_photo')) {
          add('Фото', 'Фото «До» обязательно');
        }
      case 'prepare_document':
        add('Документ', action.text('title'));
      case 'prepare_timesheet_correction':
        add('Новое значение', '${action.number('shifts')} смены');
      case 'prepare_employee_update':
        add('Текущая ставка', _money(action.number('current_daily_rate')));
        add('Новая ставка', _money(action.number('daily_rate')));
      case 'create_reminder':
        add('Название', action.text('title'));
        add('Время', action.text('local_time'));
        add('Получатели', action.stringList('recipient_roles').join(', '));
    }

    return rows;
  }

  String _date(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return value;
    return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
  }

  String _money(num value) {
    if (value <= 0) return '';
    return '${value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    )} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                actionTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                writesImmediately
                    ? 'После подтверждения указанная запись будет сохранена в приложении.'
                    : 'После подтверждения откроется обычная форма или предпросмотр. Действие завершится только после твоей проверки.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              for (final row in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 122,
                        child: Text(
                          row.$1,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.$2,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'В журнале сохранятся предложение ИИ, пользователь и результат действия.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirmationLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
