import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void _containsAll(String path, Iterable<String> requiredFragments) {
  final contents = _source(path);

  for (final fragment in requiredFragments) {
    expect(
      contents,
      contains(fragment),
      reason: 'Обязательный элемент "$fragment" исчез из $path',
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
        "title: const Text('Табель')",
        "label: const Text('Отчет')",
        "'Сохранить изменения'",
        "'Сохранить табель'",
        'RepaintBoundary(child: buildEmployeeRow(employee))',
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
        const [
          "'Отчёт по выплатам'",
          "'Все сотрудники'",
          "'Скачать таблицу'",
        ],
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
        const [
          "'Создать компанию'",
          'CompanySignupScreen',
        ],
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
      _containsAll(
        'lib/screens/profile_screen.dart',
        const [
          "'Компания и пользователи'",
          "'Сменить компанию'",
          'CompanyManagementScreen',
        ],
      );
      _containsAll(
        'lib/features/company/presentation/company_management_screen.dart',
        const [
          "'Пригласить пользователя'",
          "'Прораб'",
          "'Администратор'",
          "'Для прораба нужно выбрать объект'",
          'CompanyRepository.inviteMember',
          'CompanyRepository.updateMemberAccess',
        ],
      );
      _containsAll(
        'lib/features/company/data/company_repository.dart',
        const [
          "'invite-company-member'",
          "'company_memberships'",
          "'object_memberships'",
          "'active_company_id'",
        ],
      );
      _containsAll(
        'supabase/functions/invite-company-member/index.ts',
        const [
          'inviteUserByEmail',
          'resetPasswordForEmail',
          '"password_setup_resent"',
        ],
      );
    });

    test('приглашённый пользователь обязательно задаёт пароль', () {
      _containsAll(
        'lib/features/auth/presentation/premium_auth_gate_v2.dart',
        const [
          'UserRepository.mustSetPassword',
          'SetInvitationPasswordScreen',
          'CompanyOnboardingScreen',
        ],
      );
      _containsAll(
        'lib/features/auth/presentation/set_invitation_password_screen.dart',
        const [
          "'Придумайте пароль'",
          "'Сохранить пароль'",
          'UserRepository.setInvitationPassword',
        ],
      );
      _containsAll(
        'lib/features/auth/data/user_repository.dart',
        const [
          "'must_set_password': false",
          "'accept_current_company_invitation'",
        ],
      );
    });
    test('платформенные экраны сохраняют премиальный стиль и финальный логотип', () {
      _containsAll('lib/widgets/premium_ui_v2.dart', const [
        'class _AppStroyMarkPainter',
        'final leftTower = Path()',
        'final centerTower = Path()',
        'final rightTower = Path()',
        'Color(0xFF77797C)',
        'controller.forward()',
        'class PremiumBackdrop',
      ]);
      _containsAll('web/index.html', const [
        'tower-shape tower-left',
        'tower-shape tower-center',
        'tower-shape tower-right',
        'mark-sheen',
      ]);
      _containsAll(
        'android/app/src/main/res/drawable/app_icon_foreground.xml',
        const [
          'android:fillColor="#B6B7B9"',
          'android:fillColor="#8D8E90"',
          'android:fillColor="#A2A3A5"',
        ],
      );
      _containsAll(
        'lib/features/auth/presentation/company_signup_screen.dart',
        const [
          "'14 дней'",
          "'Без карты'",
          "'Команда и объекты'",
          "'Создать компанию'",
        ],
      );
      _containsAll(
        'lib/features/company/presentation/company_switcher_screen.dart',
        const [
          'PremiumBackdrop',
          "'Выбрать компанию'",
          "'Данные, объекты и сотрудники каждой компании полностью изолированы.'",
        ],
      );
      _containsAll(
        'lib/features/company/presentation/company_management_screen.dart',
        const [
          'PremiumBackdrop',
          'PremiumActionButton',
          "'Пригласить пользователя'",
          "'Команда'",
        ],
      );
    });

  });
}
