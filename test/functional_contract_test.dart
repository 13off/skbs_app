import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void _containsAll(String path, List<String> markers) {
  final source = _read(path);
  for (final marker in markers) {
    expect(source, contains(marker), reason: '$path должен содержать $marker');
  }
}

void main() {
  group('Функциональный контракт AppСтрой', () {
    test('роли сохраняют свои вкладки и навигацию без перезагрузки', () {
      _containsAll(
        'lib/features/shell/presentation/premium_main_screen.dart',
        const [
          "label: 'Главная'",
          "label: 'Люди'",
          "label: 'Табель'",
          "label: 'Задачи'",
          "label: 'Профиль'",
          'PageView.builder',
          'AutomaticKeepAliveClientMixin',
          'scrollActiveRouteToTop',
        ],
      );
    });

    test('главная сохраняет объекты, архив и финансовую сводку', () {
      _containsAll('lib/screens/home_screen.dart', const [
        "'Все объекты'",
        "'Архив объектов'",
        "'Архивировать объект'",
        "'Задачи на сегодня'",
        "'Выплаты \${financePeriod.title()}'",
      ]);
    });

    test('люди сохраняют поиск, разделы, отчёты и позицию списка', () {
      _containsAll('lib/screens/employees_screen.dart', const [
        "label: 'Выплаты'",
        "label: 'Сводка'",
        "label: 'Добавить'",
        "section('Активные'",
        "section('Уволенные'",
        'duplicateKey(Employee employee)',
        'PageStorageKey(',
        'scrollController.offset',
      ]);
    });

    test('карточка сотрудника сохраняет все критичные действия', () {
      _containsAll('lib/screens/employee_details_screen.dart', const [
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
      _containsAll('lib/screens/timesheet_screen.dart', const [
        "title: 'Табель'",
        "label: const Text('Отчет')",
        "'Сохранить изменения'",
        "'Сохранить табель'",
        'child: buildEmployeeRow(employee)',
      ]);
      _containsAll('lib/screens/period_timesheet_screen.dart', const [
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
      _containsAll('lib/screens/add_task_screen.dart', const [
        "'Фото к задаче'",
        "'Добавить фото'",
        "'Сохранить задачу'",
      ]);
      _containsAll('lib/screens/task_details_screen.dart', const [
        "'Удалить задачу?'",
        "'Фото'",
        "'Добавить фото'",
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
        "'app_notifications'",
        "'app_notification_reads'",
        "'app_notification_clears'",
        'foremanAllowedEntityTypes',
        "query.inFilter('entity_type'",
        "'actor_name'",
        "'actor_email'",
        'markAsRead(',
        'clearNotifications(',
      ]);
      _containsAll('lib/widgets/notification_bell.dart', const [
        "'Очистить уведомления?'",
        'NotificationRepository.markAsRead',
        'NotificationRepository.clearNotifications',
      ]);
    });

    test('архив сохраняет восстановление и окончательное удаление', () {
      _containsAll(
        'lib/features/archive/presentation/archive_management_screen_v3.dart',
        const [
          "'Архив и удаление'",
          "'Восстановить'",
          "'Удалить навсегда'",
          "'Архив пуст'",
          "'Архив доступен только администратору'",
        ],
      );
    });

    test('компании можно регистрировать и настраивать самостоятельно', () {
      _containsAll(
        'lib/features/auth/presentation/premium_login_screen_v2.dart',
        const ["'Создать компанию'", 'CompanySignupScreen'],
      );
      _containsAll(
        'lib/features/auth/presentation/company_signup_screen.dart',
        const [
          "'Название компании'",
          "'Ваше имя'",
          "'Первые 14 дней — пробный период.",
          'UserRepository.signUpCompany',
        ],
      );
      _containsAll(
        'lib/features/company/presentation/company_onboarding_screen.dart',
        const [
          "'Создать рабочее пространство'",
          'UserRepository.createCompanyProfile',
        ],
      );
    });

    test('администратор управляет приглашениями, ролями и объектами', () {
      _containsAll('lib/screens/profile_screen.dart', const [
        "'Компания и пользователи'",
        "'Сменить компанию'",
        'CompanyManagementScreen',
      ]);
      _containsAll(
        'lib/features/company/presentation/company_management_screen.dart',
        const [
          "'Пригласить пользователя'",
          "'Прораб'",
          "'Администратор'",
          "'Для прораба нужно выбрать объект'",
          'CompanyRepository.inviteMember',
        ],
      );
    });

    test('тарифы и заявки сохраняют бизнес-контур компании', () {
      _containsAll(
        'lib/features/billing/presentation/company_billing_screen.dart',
        const [
          "'Тарифы и оплата'",
          "'Пробный период'",
          "'Оставить заявку'",
          "'Отправить заявку'",
          'BillingRepository.createBillingRequest',
        ],
      );
    });

    test('приглашённый пользователь обязательно задаёт пароль', () {
      _containsAll(
        'lib/features/auth/presentation/invite_password_setup_screen.dart',
        const [
          "'Создать пароль'",
          "'Новый пароль'",
          "'Повторите пароль'",
          'updateUser(',
        ],
      );
    });

    test(
      'платформенные экраны сохраняют премиальный стиль и финальный логотип',
      () {
        _containsAll(
          'lib/features/auth/presentation/premium_login_screen_v2.dart',
          const ['PremiumWorkBackdrop', 'PremiumBrandMark'],
        );
        _containsAll('lib/widgets/premium_ui_v2.dart', const [
          'class PremiumBrandMark',
          'app_icon_matte_v2.svg',
        ]);
      },
    );

    test('изменения данных сразу доходят до всех открытых экранов', () {
      _containsAll('lib/data/app_data_sync.dart', const [
        'AppDataSync.changes',
        'notifyLocal(',
        'refreshAll()',
      ]);
      _containsAll(
        'lib/features/shell/presentation/premium_main_screen.dart',
        const ['AppDataSync.start(', 'AppDataSync.refreshAll()'],
      );
    });
  });
}
