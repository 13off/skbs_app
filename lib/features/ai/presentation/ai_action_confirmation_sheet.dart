import 'package:flutter/material.dart';

import '../../../screens/period_timesheet/period_timesheet_launch_intent.dart';
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
      'create_employee_draft' => 'Открыть карточку нового сотрудника?',
      'prepare_payment' => 'Открыть черновик выплаты?',
      'find_missing_receipts' => 'Открыть список выплат без чеков?',
      'open_period_timesheet' => 'Открыть месячный табель?',
      'prepare_work_act' => 'Открыть черновик акта?',
      'prepare_candidate_documents' => 'Открыть пакет кандидата?',
      'create_reminder' => 'Открыть настройки напоминания?',
      _ => 'Подтвердить действие?',
    };
  }

  String get confirmationLabel {
    return switch (action.type) {
      'prepare_timesheet_correction' => 'Подтвердить и изменить',
      'find_missing_receipts' ||
      'open_period_timesheet' ||
      'prepare_work_act' ||
      'prepare_candidate_documents' => 'Подтвердить и открыть',
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
    add('Кандидат', action.text('full_name'));
    add('Дата', _date(action.text('date')));

    switch (action.type) {
      case 'create_task_draft':
        add('Работы', action.text('work'));
        add('Оси', action.text('axes'));
        add('Исполнители', action.stringList('assignee_names').join(', '));
        if (action.boolean('require_before_photo')) {
          add('Фото', 'Фото «До» обязательно');
        }
        break;
      case 'prepare_document':
        add('Документ', action.text('title'));
        break;
      case 'prepare_timesheet_correction':
        add('Текущее значение', '${action.number('current_shifts')} смены');
        add('Новое значение', '${action.number('shifts')} смены');
        break;
      case 'prepare_employee_update':
        add('Текущая ставка', _money(action.number('current_daily_rate')));
        add('Новая ставка', _money(action.number('daily_rate')));
        break;
      case 'create_employee_draft':
        add('ФИО', action.text('fio'));
        add('Должность', action.text('position'));
        add('Телефон', action.text('phone'));
        add('Ставка', _money(action.number('daily_rate')));
        break;
      case 'prepare_payment':
        add('Сумма', _money(action.number('amount')));
        add('Тип', _paymentType(action.text('payment_type')));
        add('Чек', 'Нужно проверить перед сохранением');
        break;
      case 'find_missing_receipts':
        add('Период', action.text('month'));
        add('Найдено', '${_listLength('rows')}');
        break;
      case 'open_period_timesheet':
        add('Период', action.text('month'));
        break;
      case 'prepare_work_act':
        add('Состав', 'Только выполненные задачи');
        break;
      case 'prepare_candidate_documents':
        add('Должность', action.text('position_title'));
        add('Получено файлов', '${_listLength('existing_documents')}');
        add('Не хватает', action.stringList('missing_documents').join(', '));
        break;
      case 'create_reminder':
        add('Название', action.text('title'));
        add('Время', action.text('local_time'));
        add('Получатели', action.stringList('recipient_roles').join(', '));
        break;
    }

    return rows;
  }

  int _listLength(String key) {
    final value = action.payload[key];
    return value is List ? value.length : 0;
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

  String _paymentType(String value) {
    return switch (value) {
      'salary' => 'Заработная плата',
      'fine' => 'Штраф',
      _ => 'Аванс',
    };
  }

  void _confirm(BuildContext context) {
    if (action.type == 'open_period_timesheet') {
      PeriodTimesheetLaunchIntent.setFromYearMonth(action.text('month'));
    }
    Navigator.pop(context, true);
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
                    : 'После подтверждения откроется обычная форма, отчёт или предпросмотр. Запись создастся только после твоей проверки.',
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
                      onPressed: () => _confirm(context),
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
