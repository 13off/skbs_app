import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/employee_details_source.dart';
import 'support/employees_source.dart';
import 'support/home_source.dart';
import 'support/period_timesheet_source.dart';
import 'support/task_create_source.dart';
import 'support/task_details_source.dart';
import 'support/timesheet_source.dart';

String _source(String path) => File(path).readAsStringSync();

void _containsAllText(
  String label,
  String contents,
  Iterable<String> requiredFragments,
) {
  for (final fragment in requiredFragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный элемент "$fragment" исчез из $label',
    );
  }
}

void _containsAll(String path, Iterable<String> requiredFragments) {
  _containsAllText(path, _source(path), requiredFragments);
}

void _containsNone(String path, Iterable<String> forbiddenFragments) {
  final contents = _source(path);
  for (final fragment in forbiddenFragments) {
    expect(
      contents,
      isNot(contains(fragment)),
      reason: 'Запрещённый элемент "$fragment" вернулся в $path',
    );
  }
}

void main() {
  group('Функциональный контракт AppСтрой', () {
    test('роли сохраняют свои вкладки и навигацию без перезагрузки', () {
      _containsAll(
        'lib/features/shell/presentation/premium_main_screen.dart',
        const [
          'widget.profile.isAdmin ? 5 : 4',
          "label: 'Главная'",
          "label: 'Люди'",
          "label: 'Табель'",
          "label: 'Задачи'",
          "label: 'Профиль'",
          'navigator.popUntil((route) => route.isFirst)',
          'scrollActiveRouteToTop()',
          'NeverScrollableScrollPhysics',
        ],
      );
    });

    test('главная сохраняет объекты, архив и финансовую сводку', () {
      _containsAllText('главная', homeSource(), const [
        "'Все объекты'",
        "'Архив объектов'",
        "'Архивировать объект'",
        "'Выполненные задачи'",
        "'Выплаты \${financePeriod.title()}'",
      ]);
    });

    test('люди сохраняют поиск, разделы, отчёты и позицию списка', () {
      _containsAllText('сотрудники', employeesSource(), const [
        "label: 'Выплаты'",
        "label: 'Сводка'",
        "label: 'Добавить'",
        'sectionHeader(',
        "'Активные'",
        "'Уволенные'",
        'duplicateKey(Employee employee)',
        'PageStorageKey(',
        'scrollController.offset',
      ]);
    });

    test('карточка сотрудника сохраняет все критичные действия', () {
      _containsAllText('карточка сотрудника', employeeDetailsSource(), const [
        "'Редактировать'",
        "'Скопировать в другой объект'",
        "'Добавить выплату'",
        "'Вернуть в активные'",
        "'Уволить'",
        "'Уволить и архивировать'",
        "'Архивировать'",
        "title: 'Личные данные'",
        "title: 'Документы'",
        "title: 'Выплаты'",
        "title: 'Комментарии'",
      ]);
      _containsAll('lib/screens/employee_timesheet_screen.dart', const [
        "'Скачать Excel'",
      ]);
    });

    test('табель сохраняет быстрый ввод, ручной ввод и отчёты', () {
      _containsAllText('табель', timesheetSource(), const [
        "title: 'Табель'",
        "label: const Text('Отчет')",
        "'Сохранить изменения'",
        "'Сохранить табель'",
        'child: buildEmployeeRow(employee)',
      ]);
      _containsAllText('месячный табель', periodTimesheetSource(), const [
        "'Скачать Excel'",
        "'Скачать общий табель'",
        "'Скачать табель сотрудника'",
        "'Скачать индивидуальный табель'",
      ]);
    });

    test('выплаты сохраняют добавление, фильтры, чеки и единый XLSX', () {
      _containsAll(
        'lib/features/payments/presentation/screens/payments_screen.dart',
        const [
          "label: const Text('Отчёт')",
          "label: const Text('Добавить')",
          "title: const Text('Выплаты')",
        ],
      );
      _containsAll(
        'lib/features/payments/presentation/widgets/payment_report_sheet.dart',
        const ["'Отчёт по выплатам'", "'Все сотрудники'", "'Скачать таблицу'"],
      );
      _containsAll('lib/screens/add_payment_screen.dart', const [
        "'Добавить чек'",
        "'Добавить ещё чек'",
        "'Сохранить выплату'",
      ]);
    });

    test('задачи сохраняют фото, статусы, редактирование и акт', () {
      _containsAll('lib/screens/tasks_screen.dart', const [
        "'Все объекты'",
        "'Добавить задачу'",
        "'Сформировать акт'",
      ]);
      _containsAllText('создание задачи', taskCreateSource(), const [
        "'Фото «До» — обязательно'",
        "'Добавить фото «До»'",
        "'Сохранить задачу'",
      ]);
      _containsAllText('редактор задачи', taskDetailsEditorSource(), const [
        "title: 'Фото «До»'",
        "title: 'Фото «После»'",
        "tooltip: 'Удалить'",
        "label: const Text('Сохранить')",
      ]);
      _containsAll('lib/screens/act_preview_screen.dart', const [
        "'Акт выполненных работ'",
        "'Скачать акт'",
      ]);
    });

    test('уведомления остаются персональными и ограниченными для прораба', () {
      _containsAll('lib/data/notification_repository.dart', const [
        "'get_notification_feed_fast'",
        "'app_notification_reads'",
        "'p_object_name'",
        "'p_limit'",
        "row['is_read'] == true",
        'markAsRead(',
        'clearNotifications(',
      ]);
      _containsAll(
        'supabase/migrations/20260723160000_optimize_notification_visibility_policy.sql',
        const [
          'notification.target_user_id = ctx.user_id',
          "ctx.user_role <> 'foreman'",
          'accessible_object_names',
          'notification.object_name',
        ],
      );
      _containsAll(
        'supabase/migrations/20260723170000_get_notification_feed_fast.sql',
        const [
          'app_notification_clears',
          'app_notification_reads',
          "ctx.user_role = 'foreman'",
          "'operational_overdue_tasks'",
          "'operational_missing_photos'",
          "'operational_timesheet_missing'",
          "'ai_draft'",
        ],
      );
      _containsAll('lib/widgets/notification_bell.dart', const [
        "'Очистить уведомления?'",
        'NotificationRepository.markAsRead',
        'NotificationRepository.clearNotifications',
      ]);
    });

    test('архив сохраняет восстановление и окончательное удаление', () {
      _containsAll(
        'lib/features/archive/presentation/archive_management_screen_v3.dart',
        const ["'Архив и удаление'", "'Восстановить'", "'Удалить навсегда'"],
      );
    });

    test('настройки сохраняют рабочий выход из аккаунта', () {
      _containsAll('lib/screens/profile_screen.dart', const [
        'signOutButton(context)',
        'UserRepository.signOut()',
        "'Выйти'",
      ]);
    });

    test('в приложении не возвращаются дубли вкладок и старые подписи', () {
      _containsNone(
        'lib/features/shell/presentation/premium_main_screen.dart',
        const ["label: 'Отчёт'", "label: 'Выплаты'"],
      );
    });
  });
}
