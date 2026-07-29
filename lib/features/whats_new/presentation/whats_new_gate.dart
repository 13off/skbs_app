import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/liquid_glass.dart';

class WhatsNewGate extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const WhatsNewGate({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  static const String releaseId = 'mobile-2026-07-29-full-since-1.1.0+2-v1';
  static const String _preferenceKey = 'whats_new_seen_release';

  bool _checkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  Future<void> _showIfNeeded() async {
    if (_checkStarted || !mounted) return;
    _checkStarted = true;

    SharedPreferences? preferences;
    String? seenRelease;
    try {
      preferences = await SharedPreferences.getInstance();
      seenRelease = preferences.getString(_preferenceKey);
    } catch (_) {
      // Ошибка локального хранилища не блокирует показ обновления.
    }

    if (!mounted || seenRelease == releaseId) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WhatsNewDialog(),
    );

    try {
      await preferences?.setString(_preferenceKey, releaseId);
    } catch (_) {
      // В текущем запуске презентация уже просмотрена.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WhatsNewDialog extends StatefulWidget {
  const _WhatsNewDialog();

  @override
  State<_WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<_WhatsNewDialog> {
  static const slides = <_WhatsNewSlide>[
    _WhatsNewSlide(
      icon: Icons.dashboard_customize_outlined,
      title: 'Отдельные платформы для каждой роли',
      description:
          'AppСтрой теперь открывает разный рабочий кабинет руководителю, прорабу, HR, бухгалтеру, юристу, разработчику и сотруднику.',
      points: <String>[
        'У каждой роли собственные вкладки и рабочие действия.',
        'Руководитель может безопасно просматривать другие платформы.',
        'Профессия сотрудника отделена от системных прав доступа.',
      ],
      demo: _WhatsNewDemoKind.rolePlatforms,
    ),
    _WhatsNewSlide(
      icon: Icons.auto_awesome_rounded,
      title: 'ИИ-диспетчер по объектам',
      description:
          'Система сама собирает рабочую сводку, показывает отклонения и доставляет её нужным ролям даже при закрытом приложении.',
      points: <String>[
        'Выбор объекта, времени, дней недели и получателей.',
        'Задачи, табель, выплаты, сотрудники, HR, юридическое и этапы.',
        'Из сводки можно открыть конкретные проблемные записи.',
      ],
      demo: _WhatsNewDemoKind.dispatcher,
    ),
    _WhatsNewSlide(
      icon: Icons.analytics_outlined,
      title: 'Единый центр отчётов',
      description:
          'Руководитель получает общую картину компании и открывает каждый длинный раздел на отдельной странице.',
      points: <String>[
        'Фильтры по объекту, дате и только проблемным разделам.',
        'Сравнение со вчерашним днём и предыдущей неделей.',
        'Добавлен ежедневный ИИ-разбор рабочего дня.',
      ],
      demo: _WhatsNewDemoKind.reportCenter,
    ),
    _WhatsNewSlide(
      icon: Icons.fact_check_outlined,
      title: 'Действия ИИ с подтверждением',
      description:
          'Помощник не записывает данные сам: сначала создаёт понятное предложение, затем показывает форму проверки.',
      points: <String>[
        'Черновики задач, сотрудников, выплат, документов и напоминаний.',
        'Проверка табеля, чеков и операционных расхождений.',
        'Все подтверждения и результаты сохраняются в журнале действий ИИ.',
      ],
      demo: _WhatsNewDemoKind.aiActions,
    ),
    _WhatsNewSlide(
      icon: Icons.description_outlined,
      title: 'Документы и кадровые пакеты',
      description:
          'Появился каталог версий шаблонов и локальное заполнение настоящих DOCX без изменения исходной формы.',
      points: <String>[
        'Заявления, согласия, договоры и другие рабочие документы.',
        'ZIP-пакет кандидата с манифестом комплектности.',
        'Закрытое хранение подписанных сканов и контроль production-gate.',
      ],
      demo: _WhatsNewDemoKind.documents,
    ),
    _WhatsNewSlide(
      icon: Icons.person_search_outlined,
      title: 'CRM подбора сотрудников',
      description:
          'Работа с кандидатом собрана в единую воронку от новой заявки до одобрения и архива.',
      points: <String>[
        'Поиск, фильтры, импорт и настраиваемые этапы.',
        'Карточка кандидата, документы, статусы и следующий шаг.',
        'Автоматизации и отдельные настройки рабочего процесса HR.',
      ],
      demo: _WhatsNewDemoKind.recruitment,
    ),
    _WhatsNewSlide(
      icon: Icons.flight_takeoff_rounded,
      title: 'Оформление и выход на объект',
      description:
          'После одобрения кандидат проходит контролируемый путь до полноценного выхода в смену.',
      points: <String>[
        'Создание сотрудника из кандидата без повторного ввода данных.',
        'Билеты, прибытие, проживание, меддопуск и спецодежда.',
        'Инструктаж, назначение на объект и включение в табель.',
      ],
      demo: _WhatsNewDemoKind.mobilization,
    ),
    _WhatsNewSlide(
      icon: Icons.developer_board_outlined,
      title: 'Системная платформа разработчика',
      description:
          'Настройки компании, объектов и ролей больше не разбросаны по отдельным служебным экранам.',
      points: <String>[
        'Конструктор параметров и автоматических напоминаний.',
        'Ограничения задач с наследованием компания → объект → роль.',
        'Матрица прав, диагностика, аудит и безопасная корзина.',
      ],
      demo: _WhatsNewDemoKind.developerControls,
    ),
    _WhatsNewSlide(
      icon: Icons.task_alt_rounded,
      title: 'Задачи, фото и личный вклад',
      description:
          'Задачи стали полноценным рабочим процессом с исполнителями, этапами, черновиками и измеримым вкладом команды.',
      points: <String>[
        'Фото «До» и «После», цели объекта и дневной прогресс.',
        'Черновики задач и безопасное восстановление из корзины.',
        'Распределение личного вклада участников с общей суммой 100%.',
      ],
      demo: _WhatsNewDemoKind.contribution,
    ),
    _WhatsNewSlide(
      icon: Icons.notifications_active_outlined,
      title: 'Уведомления под контролем',
      description:
          'Руководитель сам определяет, какие события, каким ролям и в какое время отправляет система.',
      points: <String>[
        'Отдельные настройки колокольчика и системного push.',
        'Ролевые уведомления и ограничения прораба по объектам.',
        'Напоминания о задачах, фото, кандидатах, документах и выплатах.',
      ],
      demo: _WhatsNewDemoKind.notifications,
    ),
    _WhatsNewSlide(
      icon: Icons.dark_mode_outlined,
      title: 'Полноценная тёмная тема',
      description:
          'Тема переключается без перезапуска и применяется к рабочим экранам, диалогам, таблицам, заставке и иконке.',
      points: <String>[
        'Спокойная сине-графитовая палитра и читаемый контраст.',
        'Адаптивные мобильные и компьютерные поверхности.',
        'Плавная прокрутка и сохранение открытой вкладки.',
      ],
      demo: _WhatsNewDemoKind.themeToggle,
    ),
    _WhatsNewSlide(
      icon: Icons.badge_outlined,
      title: 'Полноценный кабинет сотрудника',
      description:
          'Сотрудник входит в отдельный личный кабинет и видит только собственные рабочие данные.',
      points: <String>[
        'Главная, задачи, табель, документы и профиль.',
        'Смены, начисления, выплаты и доступные документы.',
        'Единый дизайн и навигация наравне с остальными ролями.',
      ],
      demo: _WhatsNewDemoKind.employeeCabinet,
    ),
  ];

  late final PageController _pageController;
  int _currentIndex = 0;

  bool get _isLast => _currentIndex == slides.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= slides.length) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(640.0, math.max(0.0, size.width - 20));
    final dialogHeight = math.min(760.0, math.max(0.0, size.height * 0.94));

    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: LiquidGlassSurface(
          blur: true,
          blurSigma: 18,
          radius: 30,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.new_releases_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Что нового в AppСтрой',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentIndex + 1} из ${slides.length} · после Android 1.1.0+2',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: _finish,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _WhatsNewSlideView(
                      slide: slides[index],
                      active: index == _currentIndex,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Назад',
                    onPressed:
                        _currentIndex == 0 ? null : () => _goTo(_currentIndex - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PageDots(
                      count: slides.length,
                      selectedIndex: _currentIndex,
                      onSelected: _goTo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _isLast ? _finish : () => _goTo(_currentIndex + 1),
                    icon: Icon(
                      _isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(_isLast ? 'Готово' : 'Далее'),
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

class _WhatsNewSlideView extends StatelessWidget {
  final _WhatsNewSlide slide;
  final bool active;

  const _WhatsNewSlideView({
    required this.slide,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DemoFrame(kind: slide.demo, active: active),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  slide.icon,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slide.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              slide.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 12),
            for (final point in slide.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.38),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PageDots({
    required this.count,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(count, (index) {
          final selected = index == selectedIndex;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Нововведение ${index + 1}',
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DemoFrame extends StatelessWidget {
  final _WhatsNewDemoKind kind;
  final bool active;

  const _DemoFrame({
    required this.kind,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (kind) {
      _WhatsNewDemoKind.rolePlatforms =>
        _RolePlatformsDemo(active: active),
      _WhatsNewDemoKind.dispatcher => _DispatcherDemo(active: active),
      _WhatsNewDemoKind.reportCenter => _ReportCenterDemo(active: active),
      _WhatsNewDemoKind.aiActions => _AiActionsDemo(active: active),
      _WhatsNewDemoKind.documents => _DocumentsDemo(active: active),
      _WhatsNewDemoKind.recruitment => _PipelineDemo(
          active: active,
          icon: Icons.person_search_outlined,
          labels: const ['Заявка', 'Проверка', 'Одобрен'],
        ),
      _WhatsNewDemoKind.mobilization => _ChecklistDemo(active: active),
      _WhatsNewDemoKind.developerControls =>
        _DeveloperControlsDemo(active: active),
      _WhatsNewDemoKind.contribution => _ContributionDemo(active: active),
      _WhatsNewDemoKind.notifications => _NotificationsDemo(active: active),
      _WhatsNewDemoKind.themeToggle => _ThemeToggleDemo(active: active),
      _WhatsNewDemoKind.employeeCabinet =>
        _EmployeeCabinetDemo(active: active),
    };

    return AspectRatio(
      aspectRatio: 1.78,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RolePlatformsDemo extends StatelessWidget {
  final bool active;

  const _RolePlatformsDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    const roles = <(IconData, String)>[
      (Icons.business_center_outlined, 'Руководитель'),
      (Icons.engineering_outlined, 'Прораб'),
      (Icons.person_search_outlined, 'HR'),
      (Icons.calculate_outlined, 'Бухгалтер'),
      (Icons.gavel_outlined, 'Юрист'),
      (Icons.developer_board_outlined, 'Разработчик'),
    ];

    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4800),
      reducedMotionValue: 0.45,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final selected = ((progress * roles.length).floor()) % roles.length;

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.dashboard_customize_outlined,
                title: 'Рабочие платформы',
                subtitle: 'Интерфейс зависит от роли',
              ),
              const SizedBox(height: 11),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == selected;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            roles[index].$1,
                            size: 19,
                            color: isSelected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            roles[index].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DispatcherDemo extends StatelessWidget {
  final bool active;

  const _DispatcherDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4200),
      reducedMotionValue: 0.56,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final pulse = 0.92 + 0.08 * math.sin(progress * math.pi * 8).abs();
        final reveal = Curves.easeOutCubic.transform(_segment(progress, 0.12, 0.42));

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.auto_awesome_rounded,
                title: 'Сводка объекта',
                subtitle: 'Сегодня · 08:00',
                trailing: Transform.scale(
                  scale: pulse,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    _MetricTile(
                      label: 'Критично',
                      value: '${(5 * reveal).round()}',
                      icon: Icons.error_outline_rounded,
                      accent: scheme.error,
                    ),
                    const SizedBox(width: 8),
                    _MetricTile(
                      label: 'Внимание',
                      value: '${(11 * reveal).round()}',
                      icon: Icons.warning_amber_rounded,
                      accent: scheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    _MetricTile(
                      label: 'Готово',
                      value: '${(37 * reveal).round()}',
                      icon: Icons.check_circle_outline_rounded,
                      accent: scheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: reveal,
                minHeight: 7,
                borderRadius: BorderRadius.circular(100),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCenterDemo extends StatelessWidget {
  final bool active;

  const _ReportCenterDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    const sections = <(IconData, String)>[
      (Icons.calendar_month_outlined, 'Табель'),
      (Icons.payments_outlined, 'Выплаты'),
      (Icons.task_alt_outlined, 'Задачи'),
      (Icons.groups_outlined, 'Люди'),
      (Icons.person_search_outlined, 'HR'),
      (Icons.gavel_outlined, 'Юридическое'),
    ];

    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4700),
      reducedMotionValue: 0.48,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final selected = ((progress * sections.length).floor()) % sections.length;

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.analytics_outlined,
                title: 'Центр отчётов',
                subtitle: 'Мурманск · сегодня',
              ),
              const SizedBox(height: 11),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.65,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final open = index == selected;
                    return AnimatedScale(
                      scale: open ? 1.05 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: open
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: open
                                ? scheme.primary.withValues(alpha: 0.4)
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sections[index].$1,
                              size: 18,
                              color: open
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sections[index].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: open
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiActionsDemo extends StatelessWidget {
  final bool active;

  const _AiActionsDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4300),
      reducedMotionValue: 0.58,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final confirm = Curves.easeInOutCubic.transform(
          _segment(progress, 0.22, 0.48),
        );
        final complete = Curves.easeInOutCubic.transform(
          _segment(progress, 0.52, 0.76),
        );
        final stage = complete > 0.7
            ? 'Выполнено'
            : confirm > 0.65
                ? 'Подтверждено'
                : 'Предложение';

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.smart_toy_outlined,
                title: 'Черновик действия',
                subtitle: stage,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DemoLine(
                        icon: Icons.task_alt_outlined,
                        label: 'Создать задачу',
                        value: 'Армирование · сегодня',
                      ),
                      const SizedBox(height: 10),
                      _DemoLine(
                        icon: Icons.apartment_outlined,
                        label: 'Объект',
                        value: 'Мурманск',
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: _StagePill(
                              label: 'Предложено',
                              active: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _StagePill(
                              label: 'Проверено',
                              active: confirm > 0.35,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _StagePill(
                              label: 'Готово',
                              active: complete > 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentsDemo extends StatelessWidget {
  final bool active;

  const _DocumentsDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4400),
      reducedMotionValue: 0.55,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final pack = _forwardAndBack(progress);

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _DemoHeader(
                    icon: Icons.description_outlined,
                    title: 'Кадровый пакет',
                    subtitle: 'DOCX + файлы кандидата',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < 3; index++)
                      Transform.translate(
                        offset: Offset(
                          pack * (54 - index * 17),
                          (index - 1) * 14 * (1 - pack),
                        ),
                        child: Transform.rotate(
                          angle: (index - 1) * 0.09 * (1 - pack),
                          child: Container(
                            width: 82,
                            height: 108,
                            margin: EdgeInsets.only(
                              left: index == 0 ? 0 : -48,
                            ),
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: scheme.outlineVariant,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  const [
                                    Icons.article_outlined,
                                    Icons.account_balance_outlined,
                                    Icons.verified_user_outlined,
                                  ][index],
                                  color: scheme.primary,
                                  size: 21,
                                ),
                                const SizedBox(height: 9),
                                for (final width in const <double>[
                                  0.9,
                                  0.68,
                                  0.82,
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: FractionallySizedBox(
                                      widthFactor: width,
                                      child: Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 20),
                    AnimatedScale(
                      scale: 0.86 + pack * 0.14,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          Icons.folder_zip_outlined,
                          size: 34,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 1,
                child: Text(
                  pack > 0.65
                      ? 'Пакет готов к проверке'
                      : 'Документы заполняются локально',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PipelineDemo extends StatelessWidget {
  final bool active;
  final IconData icon;
  final List<String> labels;

  const _PipelineDemo({
    required this.active,
    required this.icon,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4300),
      reducedMotionValue: 0.52,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final position = _forwardAndBack(progress);

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: icon,
                title: 'Воронка кандидата',
                subtitle: labels[(position * (labels.length - 1)).round()],
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) {
                  const cardWidth = 74.0;
                  final travel = math.max(
                    0.0,
                    constraints.maxWidth - cardWidth,
                  );

                  return SizedBox(
                    height: 94,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: cardWidth / 2,
                          right: cardWidth / 2,
                          top: 46,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var index = 0; index < labels.length; index++)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const SizedBox(height: 36),
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor:
                                        position >= index / (labels.length - 1)
                                            ? scheme.primary
                                            : scheme.outlineVariant,
                                  ),
                                  const SizedBox(height: 7),
                                  SizedBox(
                                    width: cardWidth,
                                    child: Text(
                                      labels[index],
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color:
                                                scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Positioned(
                          left: travel * position,
                          top: 0,
                          child: Container(
                            width: cardWidth,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: scheme.primary
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }
}

class _ChecklistDemo extends StatelessWidget {
  final bool active;

  const _ChecklistDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    const items = <String>[
      'Билеты',
      'Проживание',
      'Меддопуск',
      'Инструктаж',
      'Табель',
    ];

    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4800),
      reducedMotionValue: 0.62,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final completed = (progress * (items.length + 1)).floor();

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.flight_takeoff_rounded,
                title: 'Выход на объект',
                subtitle: '${completed.clamp(0, items.length)}/${items.length}',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                color: index < completed
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                index < completed
                                    ? Icons.check_rounded
                                    : Icons.more_horiz_rounded,
                                size: 16,
                                color: index < completed
                                    ? scheme.onPrimary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                items[index],
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (index < completed)
                              Icon(
                                Icons.verified_rounded,
                                size: 17,
                                color: scheme.primary,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeveloperControlsDemo extends StatelessWidget {
  final bool active;

  const _DeveloperControlsDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4500),
      reducedMotionValue: 0.47,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final amount = _forwardAndBack(progress);

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              const _DemoHeader(
                icon: Icons.developer_board_outlined,
                title: 'Конструктор',
                subtitle: 'Компания → объект → роль',
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _ToggleRow(
                            label: 'Фото «До»',
                            value: amount > 0.2,
                          ),
                          const SizedBox(height: 7),
                          _ToggleRow(
                            label: 'Фото «После»',
                            value: amount > 0.4,
                          ),
                          const SizedBox(height: 7),
                          _ToggleRow(
                            label: 'Удаление задач',
                            value: amount > 0.75,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 5,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          final enabled = index / 9 < amount;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              enabled
                                  ? Icons.check_rounded
                                  : Icons.remove_rounded,
                              size: 15,
                              color: enabled
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContributionDemo extends StatelessWidget {
  final bool active;

  const _ContributionDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4100),
      reducedMotionValue: 0.5,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final amount = _forwardAndBack(progress);
        final first = (34 + amount * 26).round();
        final second = 100 - first;

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.task_alt_rounded,
                title: 'Личный вклад',
                subtitle: '$first% + $second% = 100%',
              ),
              const SizedBox(height: 14),
              _ContributionRow(
                name: 'Алексей',
                value: first,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              _ContributionRow(
                name: 'Иван',
                value: second,
                color: scheme.tertiary,
              ),
              const Spacer(),
              Row(
                children: [
                  _MiniFeatureChip(
                    icon: Icons.photo_camera_outlined,
                    label: 'Фото',
                  ),
                  const SizedBox(width: 7),
                  _MiniFeatureChip(
                    icon: Icons.flag_outlined,
                    label: 'Цель',
                  ),
                  const SizedBox(width: 7),
                  _MiniFeatureChip(
                    icon: Icons.edit_note_outlined,
                    label: 'Черновик',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsDemo extends StatelessWidget {
  final bool active;

  const _NotificationsDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    const messages = <String>[
      'Нет фото «До»',
      'Кандидату нужны документы',
      'Выплата без чека',
    ];

    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4400),
      reducedMotionValue: 0.58,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final visible = (progress * (messages.length + 1)).floor();

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              _DemoHeader(
                icon: Icons.notifications_active_outlined,
                title: 'Центр уведомлений',
                subtitle: 'Колокольчик + push',
                trailing: Badge(
                  label: Text('${visible.clamp(0, messages.length)}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(height: 9),
              Expanded(
                child: Column(
                  children: [
                    for (var index = 0; index < messages.length; index++)
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: index < visible ? 1 : 0.18,
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: index < visible
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  const [
                                    Icons.photo_camera_outlined,
                                    Icons.person_search_outlined,
                                    Icons.receipt_long_outlined,
                                  ][index],
                                  size: 17,
                                  color: index < visible
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    messages[index],
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: index < visible
                                              ? scheme.onPrimaryContainer
                                              : scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeToggleDemo extends StatelessWidget {
  final bool active;

  const _ThemeToggleDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 4200),
      reducedMotionValue: 0.5,
      builder: (context, progress) {
        final amount = _forwardAndBack(
          progress,
          forwardStart: 0.08,
          forwardEnd: 0.38,
          reverseStart: 0.62,
          reverseEnd: 0.92,
        );
        final background = Color.lerp(
          const Color(0xFFF1F3F6),
          const Color(0xFF0E1621),
          amount,
        )!;
        final surface = Color.lerp(
          Colors.white,
          const Color(0xFF17212B),
          amount,
        )!;
        final primaryText = Color.lerp(
          const Color(0xFF1A1E24),
          const Color(0xFFF3F6FA),
          amount,
        )!;
        final mutedText = Color.lerp(
          const Color(0xFF68717D),
          const Color(0xFFA7B4C1),
          amount,
        )!;
        final accent = Color.lerp(
          const Color(0xFF20252B),
          const Color(0xFF3390EC),
          amount,
        )!;

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.apartment_rounded, color: primaryText, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'AppСтрой',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: primaryText,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Icon(
                    amount < 0.5
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 18,
                    color: mutedText,
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 58,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFFD4D8DE),
                        accent.withValues(alpha: 0.45),
                        amount,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 4 + 26 * amount,
                          top: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.white,
                                accent,
                                amount,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFFE3E7EB),
                        Colors.white.withValues(alpha: 0.10),
                        amount,
                      )!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сводка объекта',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: primaryText,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Фон, карточки и текст меняются вместе',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      LinearProgressIndicator(
                        value: 0.72,
                        color: accent,
                        backgroundColor:
                            mutedText.withValues(alpha: 0.14),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeCabinetDemo extends StatelessWidget {
  final bool active;

  const _EmployeeCabinetDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 3900),
      reducedMotionValue: 0.58,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final cardOne =
            Curves.easeOutBack.transform(_segment(progress, 0.04, 0.25));
        final cardTwo =
            Curves.easeOutBack.transform(_segment(progress, 0.14, 0.35));
        final cardThree =
            Curves.easeOutBack.transform(_segment(progress, 0.24, 0.45));
        final selectedIndex = ((progress * 5).floor()) % 5;

        return Container(
          decoration: _panelDecoration(scheme),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(13, 11, 13, 8),
                child: _DemoHeader(
                  icon: Icons.badge_outlined,
                  title: 'Личный кабинет',
                  subtitle: 'Сотрудник · Мурманск',
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _AnimatedInfoCard(
                          amount: cardOne,
                          icon: Icons.task_alt_rounded,
                          title: 'Задачи',
                          value: '3 активных',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            Expanded(
                              child: _AnimatedInfoCard(
                                amount: cardTwo,
                                icon: Icons.calendar_month_rounded,
                                title: 'Смены',
                                value: '18',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _AnimatedInfoCard(
                                amount: cardThree,
                                icon: Icons.payments_outlined,
                                title: 'Начислено',
                                value: '126 000 ₽',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 5;
                  return SizedBox(
                    height: 42,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          left: selectedIndex * itemWidth + 5,
                          top: 3,
                          width: itemWidth - 10,
                          height: 35,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                        const Row(
                          children: [
                            _NavIcon(icon: Icons.home_rounded),
                            _NavIcon(icon: Icons.task_alt_rounded),
                            _NavIcon(icon: Icons.calendar_month_rounded),
                            _NavIcon(icon: Icons.folder_copy_rounded),
                            _NavIcon(icon: Icons.person_rounded),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DemoHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _DemoHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DemoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 19, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StagePill extends StatelessWidget {
  final String label;
  final bool active;

  const _StagePill({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;

  const _ToggleRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 31,
              height: 18,
              decoration: BoxDecoration(
                color: value
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(100),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: value
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final String name;
  final int value;
  final Color color;

  const _ContributionRow({
    required this.name,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 260),
            builder: (context, amount, _) {
              return LinearProgressIndicator(
                value: amount,
                minHeight: 10,
                borderRadius: BorderRadius.circular(100),
                color: color,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _MiniFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniFeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: scheme.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedInfoCard extends StatelessWidget {
  final double amount;
  final IconData icon;
  final String title;
  final String value;

  const _AnimatedInfoCard({
    required this.amount,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: Offset(0, 16 * (1 - amount)),
      child: Transform.scale(
        scale: 0.92 + 0.08 * amount,
        child: Opacity(
          opacity: amount.clamp(0.0, 1.0).toDouble(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;

  const _NavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LoopingDemo extends StatefulWidget {
  final bool active;
  final Duration duration;
  final double reducedMotionValue;
  final Widget Function(BuildContext context, double progress) builder;

  const _LoopingDemo({
    required this.active,
    required this.duration,
    required this.reducedMotionValue,
    required this.builder,
  });

  @override
  State<_LoopingDemo> createState() => _LoopingDemoState();
}

class _LoopingDemoState extends State<_LoopingDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_animationsDisabled == disabled && _controller.isAnimating) return;
    _animationsDisabled = disabled;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _LoopingDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.active != widget.active) {
      _syncAnimation(restart: widget.active);
    }
  }

  void _syncAnimation({bool restart = false}) {
    if (_animationsDisabled || !widget.active) {
      _controller.stop();
      _controller.value = widget.reducedMotionValue;
      return;
    }
    if (restart) _controller.value = 0;
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}

class _WhatsNewSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> points;
  final _WhatsNewDemoKind demo;

  const _WhatsNewSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.demo,
  });
}

enum _WhatsNewDemoKind {
  rolePlatforms,
  dispatcher,
  reportCenter,
  aiActions,
  documents,
  recruitment,
  mobilization,
  developerControls,
  contribution,
  notifications,
  themeToggle,
  employeeCabinet,
}

BoxDecoration _panelDecoration(ColorScheme scheme) {
  return BoxDecoration(
    color: scheme.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: scheme.outlineVariant),
  );
}

double _segment(double value, double start, double end) {
  if (end <= start) return value >= end ? 1 : 0;
  return ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
}

double _forwardAndBack(
  double progress, {
  double forwardStart = 0.10,
  double forwardEnd = 0.42,
  double reverseStart = 0.62,
  double reverseEnd = 0.94,
}) {
  if (progress < reverseStart) {
    return Curves.easeInOutCubic.transform(
      _segment(progress, forwardStart, forwardEnd),
    );
  }
  return 1 -
      Curves.easeInOutCubic.transform(
        _segment(progress, reverseStart, reverseEnd),
      );
}
