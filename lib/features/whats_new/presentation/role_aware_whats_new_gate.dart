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
  static const String releaseId =
      'mobile-2026-07-29-full-since-1.1.0+2-v2-role-aware';
  static const String _preferencePrefix = 'whats_new_seen_release';

  bool _checkStarted = false;

  String get _preferenceKey =>
      '$_preferencePrefix:${widget.profile.id}:${widget.profile.role}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  Future<void> _showIfNeeded() async {
    if (_checkStarted || !mounted || widget.profile.isRolePreview) return;
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

    final slides = _slidesFor(widget.profile);
    if (slides.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WhatsNewDialog(
        profile: widget.profile,
        slides: slides,
      ),
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

const Set<String> _allWorkingRoles = <String>{
  'developer',
  'foreman',
  'employee',
  'lawyer',
  'accountant',
  'hr',
};

const List<_WhatsNewSlide> _allSlides = <_WhatsNewSlide>[
  _WhatsNewSlide(
    icon: Icons.dashboard_customize_outlined,
    title: 'Отдельные платформы для каждой роли',
    description:
        'AppСтрой открывает каждому специалисту только его рабочий кабинет, вкладки и действия.',
    points: <String>[
      'Руководитель видит общую систему и может просматривать другие платформы.',
      'У прораба, HR, бухгалтера, юриста, разработчика и сотрудника свои разделы.',
      'Профессия сотрудника отделена от системных прав доступа.',
    ],
    demo: _WhatsNewDemoKind.rolePlatforms,
    common: true,
  ),
  _WhatsNewSlide(
    icon: Icons.auto_awesome_rounded,
    title: 'ИИ-диспетчер по объектам',
    description:
        'Система собирает рабочую сводку, показывает отклонения и доставляет её нужным ролям.',
    points: <String>[
      'Выбор объекта, времени, дней недели и получателей.',
      'Задачи, табель, выплаты, сотрудники, HR, юридическое и этапы.',
      'Из сводки открываются конкретные проблемные записи.',
    ],
    demo: _WhatsNewDemoKind.dispatcher,
    roles: <String>{
      'developer',
      'foreman',
      'hr',
      'accountant',
      'lawyer',
    },
  ),
  _WhatsNewSlide(
    icon: Icons.analytics_outlined,
    title: 'Отчёты и контроль показателей',
    description:
        'Ключевые показатели собраны в одном центре, а длинные разделы открываются отдельно.',
    points: <String>[
      'Фильтры по объекту, дате и только проблемным разделам.',
      'Сравнение со вчерашним днём и предыдущей неделей.',
      'Ежедневный ИИ-разбор рабочего дня и расчётных отклонений.',
    ],
    demo: _WhatsNewDemoKind.reportCenter,
    roles: <String>{'accountant'},
  ),
  _WhatsNewSlide(
    icon: Icons.fact_check_outlined,
    title: 'Действия ИИ с подтверждением',
    description:
        'Помощник сначала формирует понятное предложение и только после проверки выполняет действие.',
    points: <String>[
      'Черновики задач, сотрудников, выплат, документов и напоминаний.',
      'Проверка табеля, чеков и операционных расхождений.',
      'Подтверждения и результаты сохраняются в журнале действий ИИ.',
    ],
    demo: _WhatsNewDemoKind.aiActions,
    roles: <String>{'developer', 'hr', 'accountant', 'lawyer'},
  ),
  _WhatsNewSlide(
    icon: Icons.description_outlined,
    title: 'Документы и кадровые пакеты',
    description:
        'Шаблоны, заполненные документы и подписанные сканы собраны в защищённом контуре.',
    points: <String>[
      'Заявления, согласия, договоры и другие рабочие документы.',
      'ZIP-пакет кандидата с манифестом комплектности.',
      'Версии шаблонов и контроль готовности к реальным персональным данным.',
    ],
    demo: _WhatsNewDemoKind.documents,
    roles: <String>{'hr', 'lawyer'},
  ),
  _WhatsNewSlide(
    icon: Icons.person_search_outlined,
    title: 'CRM подбора сотрудников',
    description:
        'Работа с кандидатом собрана в единую воронку от новой заявки до одобрения и архива.',
    points: <String>[
      'Поиск, фильтры, импорт и настраиваемые этапы.',
      'Карточка кандидата, документы, статусы и следующий шаг.',
      'Автоматизации и настройки рабочего процесса HR.',
    ],
    demo: _WhatsNewDemoKind.recruitment,
    roles: <String>{'hr'},
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
    roles: <String>{'hr'},
  ),
  _WhatsNewSlide(
    icon: Icons.developer_board_outlined,
    title: 'Системная платформа разработчика',
    description:
        'Настройки компании, объектов, ролей и ограничений собраны в одном конструкторе.',
    points: <String>[
      'Конструктор параметров и автоматических напоминаний.',
      'Ограничения с наследованием компания → объект → роль.',
      'Матрица прав, диагностика, аудит и безопасная корзина.',
    ],
    demo: _WhatsNewDemoKind.developerControls,
    roles: <String>{'developer'},
  ),
  _WhatsNewSlide(
    icon: Icons.task_alt_rounded,
    title: 'Задачи, фото и личный вклад',
    description:
        'Задачи получили исполнителей, этапы, черновики, фотографии и измеримый вклад команды.',
    points: <String>[
      'Фото «До» и «После», цели объекта и дневной прогресс.',
      'Черновики задач и безопасное восстановление из корзины.',
      'Распределение вклада участников с общей суммой 100%.',
    ],
    demo: _WhatsNewDemoKind.contribution,
    roles: <String>{'foreman', 'employee'},
  ),
  _WhatsNewSlide(
    icon: Icons.notifications_active_outlined,
    title: 'Уведомления по вашей роли',
    description:
        'Колокольчик, push и автоматические напоминания учитывают роль и доступные объекты.',
    points: <String>[
      'Каждый специалист получает только относящиеся к нему события.',
      'Руководитель настраивает роли, типы событий и время отправки.',
      'Напоминания охватывают задачи, фото, кандидатов, документы и выплаты.',
    ],
    demo: _WhatsNewDemoKind.notifications,
    common: true,
  ),
  _WhatsNewSlide(
    icon: Icons.dark_mode_outlined,
    title: 'Полноценная тёмная тема',
    description:
        'Тема переключается без перезапуска и применяется ко всем рабочим поверхностям.',
    points: <String>[
      'Спокойная сине-графитовая палитра и читаемый контраст.',
      'Тематические заставка, иконка, диалоги и таблицы.',
      'Сохраняются открытая вкладка и рабочий контекст.',
    ],
    demo: _WhatsNewDemoKind.themeToggle,
    common: true,
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
    roles: <String>{'employee'},
  ),
];

List<_WhatsNewSlide> _slidesFor(AppUserProfile profile) {
  if (profile.role == 'admin') {
    return List<_WhatsNewSlide>.unmodifiable(_allSlides);
  }

  final role = profile.role;
  if (!_allWorkingRoles.contains(role)) {
    return _allSlides.where((slide) => slide.common).toList(growable: false);
  }

  return _allSlides
      .where((slide) => slide.common || slide.roles.contains(role))
      .toList(growable: false);
}

class _WhatsNewDialog extends StatefulWidget {
  final AppUserProfile profile;
  final List<_WhatsNewSlide> slides;

  const _WhatsNewDialog({
    required this.profile,
    required this.slides,
  });

  @override
  State<_WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<_WhatsNewDialog> {
  late final PageController _pageController;
  int _currentIndex = 0;

  List<_WhatsNewSlide> get slides => widget.slides;
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
                          '${_currentIndex + 1} из ${slides.length} · ${widget.profile.roleTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Изменения после Android 1.1.0+2',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(slide.icon, size: 24, color: theme.colorScheme.primary),
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
            const SizedBox(height: 9),
            Text(
              slide.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            for (final point in slide.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
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
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
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
                width: selected ? 24 : 8,
                height: 8,
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
    return AspectRatio(
      aspectRatio: 1.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _LoopingDemo(
              active: active,
              duration: const Duration(milliseconds: 4200),
              reducedMotionValue: 0.55,
              builder: (context, progress) =>
                  _DemoScene(kind: kind, progress: progress),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoScene extends StatelessWidget {
  final _WhatsNewDemoKind kind;
  final double progress;

  const _DemoScene({
    required this.kind,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      _WhatsNewDemoKind.rolePlatforms => _rolePlatforms(context),
      _WhatsNewDemoKind.dispatcher => _dispatcher(context),
      _WhatsNewDemoKind.reportCenter => _reportCenter(context),
      _WhatsNewDemoKind.aiActions => _aiActions(context),
      _WhatsNewDemoKind.documents => _documents(context),
      _WhatsNewDemoKind.recruitment => _recruitment(context),
      _WhatsNewDemoKind.mobilization => _mobilization(context),
      _WhatsNewDemoKind.developerControls => _developerControls(context),
      _WhatsNewDemoKind.contribution => _contribution(context),
      _WhatsNewDemoKind.notifications => _notifications(context),
      _WhatsNewDemoKind.themeToggle => _themeToggle(context),
      _WhatsNewDemoKind.employeeCabinet => _employeeCabinet(context),
    };
  }

  Widget _rolePlatforms(BuildContext context) {
    const roles = <(IconData, String)>[
      (Icons.admin_panel_settings_outlined, 'Руководитель'),
      (Icons.engineering_outlined, 'Прораб'),
      (Icons.person_search_outlined, 'HR'),
      (Icons.calculate_outlined, 'Бухгалтер'),
      (Icons.gavel_outlined, 'Юрист'),
      (Icons.developer_board_outlined, 'Разработчик'),
      (Icons.badge_outlined, 'Сотрудник'),
    ];
    final selected = ((progress * roles.length).floor()) % roles.length;
    final scheme = Theme.of(context).colorScheme;

    return _DemoSurface(
      title: 'Рабочая платформа',
      subtitle: roles[selected].$2,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 7,
        runSpacing: 7,
        children: [
          for (var index = 0; index < roles.length; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: index == selected ? 92 : 40,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: index == selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    roles[index].$1,
                    size: 18,
                    color: index == selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  if (index == selected) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        roles[index].$2,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dispatcher(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pulse = _forwardAndBack(progress);
    return _DemoSurface(
      title: 'Сводка объекта',
      subtitle: pulse > 0.55 ? 'Найдено 3 отклонения' : 'Собираем показатели…',
      trailing: Icon(
        pulse > 0.55 ? Icons.warning_amber_rounded : Icons.sync_rounded,
        color: pulse > 0.55 ? scheme.error : scheme.primary,
      ),
      child: Row(
        children: [
          _MetricTile(
            label: 'Задачи',
            value: '${(18 + pulse * 4).round()}',
            icon: Icons.task_alt_rounded,
            accent: scheme.primary,
          ),
          const SizedBox(width: 8),
          _MetricTile(
            label: 'Смены',
            value: '${(42 + pulse * 6).round()}',
            icon: Icons.calendar_month_rounded,
            accent: scheme.tertiary,
          ),
          const SizedBox(width: 8),
          _MetricTile(
            label: 'Риски',
            value: '${(pulse * 3).round()}',
            icon: Icons.warning_amber_rounded,
            accent: scheme.error,
          ),
        ],
      ),
    );
  }

  Widget _reportCenter(BuildContext context) {
    final amount = _forwardAndBack(progress);
    final scheme = Theme.of(context).colorScheme;
    const cards = <(IconData, String)>[
      (Icons.groups_2_outlined, 'Команда'),
      (Icons.payments_outlined, 'Выплаты'),
      (Icons.fact_check_outlined, 'Контроль'),
    ];
    return _DemoSurface(
      title: 'Центр отчётов',
      subtitle: 'Объект · текущий период',
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < cards.length; index++)
            Transform.translate(
              offset: Offset((index - 1) * 100 * amount, (index - 1).abs() * 8),
              child: Transform.scale(
                scale: index == 1 ? 1 : 0.92,
                child: Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cards[index].$1, color: scheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        cards[index].$2,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _aiActions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = (progress * 3).floor() % 3;
    return _DemoSurface(
      title: 'Предложение ИИ',
      subtitle: phase == 0
          ? 'Подготовлено действие'
          : phase == 1
              ? 'Проверка пользователем'
              : 'Выполнено и записано в журнал',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusRow(
            icon: Icons.edit_note_rounded,
            label: 'Создать черновик задачи',
            active: phase >= 0,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            icon: Icons.verified_user_outlined,
            label: 'Подтвердить изменения',
            active: phase >= 1,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Действие выполнено',
            active: phase >= 2,
            accent: scheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _documents(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = _forwardAndBack(progress);
    const docs = <(IconData, String)>[
      (Icons.description_outlined, 'Заявление'),
      (Icons.assignment_ind_outlined, 'Согласие'),
      (Icons.handshake_outlined, 'Договор'),
    ];
    return _DemoSurface(
      title: 'Кадровый пакет',
      subtitle: amount > 0.75 ? 'Архив готов' : 'Собираем документы',
      trailing: Icon(Icons.folder_zip_outlined, color: scheme.primary),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < docs.length; index++)
            Transform.translate(
              offset: Offset(
                (index - 1) * 82 * (1 - amount),
                index * 5 * (1 - amount),
              ),
              child: Transform.scale(
                scale: 1 - index * 0.04 * (1 - amount),
                child: _DocumentCard(
                  icon: docs[index].$1,
                  label: docs[index].$2,
                  accent: scheme.primary,
                ),
              ),
            ),
          Positioned(
            right: 18,
            bottom: 8,
            child: Opacity(
              opacity: amount,
              child: Icon(
                Icons.archive_rounded,
                size: 44,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recruitment(BuildContext context) {
    final amount = Curves.easeInOutCubic.transform(progress);
    final scheme = Theme.of(context).colorScheme;
    const stages = <String>['Новая', 'Проверка', 'Одобрен', 'Архив'];
    final selected = math.min(stages.length - 1, (amount * stages.length).floor());

    return _DemoSurface(
      title: 'Воронка кандидата',
      subtitle: stages[selected],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = constraints.maxWidth / stages.length;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: step / 2,
                right: step / 2,
                top: 52,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var index = 0; index < stages.length; index++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: index == selected ? 34 : 24,
                            height: index == selected ? 34 : 24,
                            decoration: BoxDecoration(
                              color: index <= selected
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.surface, width: 3),
                            ),
                            child: index < selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: scheme.onPrimary,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stages[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: index == selected
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mobilization(BuildContext context) {
    final phase = math.min(4, (progress * 5).floor());
    const items = <String>[
      'Документы',
      'Билеты',
      'Проживание',
      'Меддопуск',
      'Выход в смену',
    ];
    return _DemoSurface(
      title: 'Выход на объект',
      subtitle: '${phase + 1} из ${items.length} этапов',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _StatusRow(
                icon: index <= phase
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                label: items[index],
                active: index <= phase,
              ),
            ),
        ],
      ),
    );
  }

  Widget _developerControls(BuildContext context) {
    final amount = _forwardAndBack(progress);
    return _DemoSurface(
      title: 'Ограничения объекта',
      subtitle: 'Компания → объект → роль',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DemoSwitchRow(
            label: 'Обязательное фото «До»',
            value: amount > 0.25,
          ),
          const SizedBox(height: 8),
          _DemoSwitchRow(
            label: 'Обязательное фото «После»',
            value: amount > 0.45,
          ),
          const SizedBox(height: 8),
          _DemoSwitchRow(
            label: 'Запрет удаления задачи',
            value: amount > 0.65,
          ),
        ],
      ),
    );
  }

  Widget _contribution(BuildContext context) {
    final amount = _forwardAndBack(progress);
    final scheme = Theme.of(context).colorScheme;
    final first = (34 + 16 * amount).round();
    final second = (33 - 3 * amount).round();
    final third = 100 - first - second;
    return _DemoSurface(
      title: 'Личный вклад',
      subtitle: 'Общая сумма всегда 100%',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ContributionBar(label: 'Иванов', percent: first, accent: scheme.primary),
          const SizedBox(height: 9),
          _ContributionBar(
            label: 'Петров',
            percent: second,
            accent: scheme.tertiary,
          ),
          const SizedBox(height: 9),
          _ContributionBar(
            label: 'Сидоров',
            percent: third,
            accent: scheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _notifications(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = math.min(3, (progress * 4).floor());
    const items = <(IconData, String)>[
      (Icons.task_alt_rounded, 'Задача приближается к сроку'),
      (Icons.photo_camera_outlined, 'Не добавлено фото «После»'),
      (Icons.description_outlined, 'Документы требуют проверки'),
    ];
    return _DemoSurface(
      title: 'Уведомления',
      subtitle: 'Только события вашей роли',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < items.length; index++)
            AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              offset: index < visible ? Offset.zero : const Offset(0.18, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: index < visible ? 1 : 0.18,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(items[index].$1, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          items[index].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
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
    );
  }

  Widget _themeToggle(BuildContext context) {
    final amount = _forwardAndBack(progress);
    final background = Color.lerp(
      const Color(0xFFF1F3F6),
      const Color(0xFF111820),
      amount,
    )!;
    final surface = Color.lerp(
      Colors.white,
      const Color(0xFF202A35),
      amount,
    )!;
    final text = Color.lerp(
      const Color(0xFF1A1E24),
      const Color(0xFFF3F6FA),
      amount,
    )!;
    final muted = Color.lerp(
      const Color(0xFF68717D),
      const Color(0xFF9FADBB),
      amount,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.apartment_rounded, color: text),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AppСтрой',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Icon(
                amount < 0.5
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: muted,
              ),
              const SizedBox(width: 8),
              Container(
                width: 58,
                height: 32,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFD7DDE4),
                    const Color(0xFF315F8C),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Рабочий экран',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: text,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Все поверхности меняются одновременно',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(child: _ThemeBlock(color: muted)),
                      const SizedBox(width: 8),
                      Expanded(child: _ThemeBlock(color: muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeCabinet(BuildContext context) {
    final selected = ((progress * 5).floor()) % 5;
    final scheme = Theme.of(context).colorScheme;
    const icons = <IconData>[
      Icons.home_rounded,
      Icons.task_alt_rounded,
      Icons.calendar_month_rounded,
      Icons.folder_copy_rounded,
      Icons.person_rounded,
    ];

    return _DemoSurface(
      title: 'Личный кабинет',
      subtitle: 'Собственные задачи, смены и документы',
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _MetricTile(
                  label: 'Смены',
                  value: '18',
                  icon: Icons.calendar_month_rounded,
                  accent: scheme.primary,
                ),
                const SizedBox(width: 8),
                _MetricTile(
                  label: 'Начислено',
                  value: '126 000 ₽',
                  icon: Icons.payments_outlined,
                  accent: scheme.tertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / icons.length;
              return SizedBox(
                height: 42,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left: selected * width + 4,
                      top: 3,
                      width: width - 8,
                      height: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final icon in icons)
                          Expanded(
                            child: Center(
                              child: Icon(
                                icon,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
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
  }
}

class _DemoSurface extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _DemoSurface({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
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
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? accent;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.active,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: active ? 1 : 0.28,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.10)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? color : scheme.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _DocumentCard({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 105,
      height: 126,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DemoSwitchRow extends StatelessWidget {
  final String label;
  final bool value;

  const _DemoSwitchRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 50,
          height: 28,
          decoration: BoxDecoration(
            color: value ? scheme.primary : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(100),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? scheme.onPrimary : scheme.surface,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributionBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color accent;

  const _ContributionBar({
    required this.label,
    required this.percent,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 7,
            color: accent,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _ThemeBlock extends StatelessWidget {
  final Color color;

  const _ThemeBlock({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
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
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
  final Set<String> roles;
  final bool common;

  const _WhatsNewSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.demo,
    this.roles = const <String>{},
    this.common = false,
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

double _segment(double value, double start, double end) {
  if (end <= start) return value >= end ? 1 : 0;
  return ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
}

double _forwardAndBack(
  double progress, {
  double forwardStart = 0.08,
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
