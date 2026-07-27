import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';

class FirstRunGuide {
  FirstRunGuide._();

  static const String version = '2026-07-27-v1';

  static String preferenceKey(AppUserProfile profile) {
    return 'first_run_guide:$version:${profile.id}:${profile.role}';
  }

  static Future<bool> showIfNeeded({
    required BuildContext context,
    required AppUserProfile profile,
    required SharedPreferences? preferences,
  }) async {
    if (profile.isRolePreview) return false;
    final key = preferenceKey(profile);
    if (preferences?.getBool(key) == true) return false;
    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FirstRunGuideDialog(profile: profile),
    );
    try {
      await preferences?.setBool(key, true);
    } catch (_) {
      // Ошибка локального хранилища не блокирует работу приложения.
    }
    return true;
  }
}

class _FirstRunGuideDialog extends StatelessWidget {
  final AppUserProfile profile;

  const _FirstRunGuideDialog({required this.profile});

  List<_GuideSection> get sections {
    if (profile.role == 'employee') {
      return const [
        _GuideSection(
          Icons.assignment_outlined,
          'Задачи',
          'Здесь находятся назначенные вам работы и их текущий статус.',
        ),
        _GuideSection(
          Icons.calendar_month_outlined,
          'Табель',
          'В календаре видны смены, часы, объект и предварительное начисление.',
        ),
        _GuideSection(
          Icons.payments_outlined,
          'Деньги',
          'Раздел показывает личные выплаты и остаток за выбранный месяц.',
        ),
        _GuideSection(
          Icons.description_outlined,
          'Документы',
          'Открывайте выданные документы и следите за их состоянием.',
        ),
      ];
    }
    if (profile.isForeman) {
      return const [
        _GuideSection(
          Icons.assignment_outlined,
          'Задачи объекта',
          'Создавайте задачи, назначайте исполнителей и прикладывайте фотографии.',
        ),
        _GuideSection(
          Icons.drafts_outlined,
          'Черновики',
          'Незаконченную задачу можно сохранить и продолжить позднее. Черновик виден только вам.',
        ),
        _GuideSection(
          Icons.fact_check_outlined,
          'Табель',
          'Отмечайте смены сотрудников своего объекта и проверяйте выбранную дату.',
        ),
        _GuideSection(
          Icons.notifications_none_rounded,
          'Уведомления',
          'Красная точка показывает события, которые требуют вашего внимания.',
        ),
      ];
    }
    if (profile.isHr) {
      return const [
        _GuideSection(
          Icons.view_kanban_outlined,
          'Кандидаты',
          'Перемещайте кандидатов по этапам и фиксируйте всю историю работы.',
        ),
        _GuideSection(
          Icons.task_alt_outlined,
          'Дела',
          'Назначайте ответственных и сроки, чтобы не терять следующие действия.',
        ),
        _GuideSection(
          Icons.folder_outlined,
          'Документы',
          'Файлы кандидатов из MAX сохраняются в защищённой карточке.',
        ),
        _GuideSection(
          Icons.tune_rounded,
          'Настройка CRM',
          'Колонки и дополнительные поля можно адаптировать под процесс компании.',
        ),
      ];
    }
    if (profile.isAccountant) {
      return const [
        _GuideSection(
          Icons.payments_outlined,
          'Выплаты',
          'Добавляйте выплаты, выбирайте промежуток и отдельно смотрите уволенных сотрудников.',
        ),
        _GuideSection(
          Icons.receipt_long_outlined,
          'Чеки',
          'К выплатам можно прикладывать подтверждающие файлы.',
        ),
        _GuideSection(
          Icons.download_outlined,
          'Отчёты',
          'Формируйте таблицы по объекту, периоду и сотруднику.',
        ),
      ];
    }
    if (profile.isLawyer) {
      return const [
        _GuideSection(
          Icons.description_outlined,
          'Документы',
          'Работайте с шаблонами, версиями и выданными документами.',
        ),
        _GuideSection(
          Icons.event_outlined,
          'Сроки',
          'Контролируйте юридические даты и напоминания.',
        ),
        _GuideSection(
          Icons.history_rounded,
          'История',
          'Изменения фиксируются в журнале и остаются проверяемыми.',
        ),
      ];
    }
    if (profile.isDeveloper) {
      return const [
        _GuideSection(
          Icons.dashboard_customize_outlined,
          'Конструктор',
          'Здесь собраны реальные настройки выбранной компании.',
        ),
        _GuideSection(
          Icons.admin_panel_settings_outlined,
          'Права',
          'Проверяйте роли, объектные ограничения и доступ к операциям.',
        ),
        _GuideSection(
          Icons.monitor_heart_outlined,
          'Контроль',
          'Используйте диагностику и журналы, не меняя рабочие данные без необходимости.',
        ),
      ];
    }
    return const [
      _GuideSection(
        Icons.apartment_outlined,
        'Объекты',
        'Выберите объект на главной, чтобы остальные разделы использовали тот же фильтр.',
      ),
      _GuideSection(
        Icons.groups_outlined,
        'Сотрудники',
        'Карточки сотрудников связывают табель, задачи, выплаты и документы.',
      ),
      _GuideSection(
        Icons.assignment_outlined,
        'Задачи и табель',
        'Планируйте работы и контролируйте фактически отработанные смены.',
      ),
      _GuideSection(
        Icons.payments_outlined,
        'Выплаты',
        'Смотрите начисления, выплаты, остатки и формируйте отчёты.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.school_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              'Как работать в AppСтрой',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Краткая памятка для роли «${profile.roleTitle}». Она показывается один раз при первом входе.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(section.icon, size: 21),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              section.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Начать работу'),
        ),
      ],
    );
  }
}

class _GuideSection {
  final IconData icon;
  final String title;
  final String text;

  const _GuideSection(this.icon, this.title, this.text);
}
