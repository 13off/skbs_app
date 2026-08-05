import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/liquid_glass.dart';

class WhatsNewGate extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const WhatsNewGate({super.key, required this.profile, required this.child});

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  static const String releaseId =
      'mobile-2026-08-05-employee-workspace-and-procurement-v1';
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
      builder: (context) =>
          _WhatsNewDialog(profile: widget.profile, slides: slides),
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

enum _UpdatePreviewKind {
  employee,
  route,
  maxLogin,
  tasks,
  timesheet,
  team,
  procurement,
  tools,
  pwa,
  performance,
}

class _UpdateSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> points;
  final _UpdatePreviewKind preview;
  final Set<String> roles;
  final bool common;

  const _UpdateSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.preview,
    this.roles = const <String>{},
    this.common = false,
  });
}

const Set<String> _allWorkingRoles = <String>{
  'developer',
  'foreman',
  'employee',
  'lawyer',
  'accountant',
  'hr',
  'procurement',
};

const List<_UpdateSlide> _allSlides = <_UpdateSlide>[
  _UpdateSlide(
    icon: Icons.phone_android_rounded,
    title: 'Новый кабинет сотрудника',
    description:
        'Рабочий кабинет стал проще: сотруднику оставлены только действия, которые нужны каждый день.',
    points: <String>[
      'Три вкладки: «Главная», «Задачи» и «Профиль».',
      'Большая анимированная кнопка начала и завершения рабочего дня.',
      'Корпоративный чат убран из кабинета сотрудника.',
    ],
    preview: _UpdatePreviewKind.employee,
    roles: <String>{'employee', 'foreman'},
  ),
  _UpdateSlide(
    icon: Icons.route_rounded,
    title: 'Маршруты, геозоны и работа без связи',
    description:
        'Рабочий день теперь записывается устойчивее даже на объектах с плохим интернетом.',
    points: <String>[
      'Координаты временно сохраняются на телефоне и отправляются после восстановления связи.',
      'Руководитель видит маршрут и журнал разрывов геолокации.',
      'Добавлены геозоны и отмена ошибочно начатого рабочего дня.',
    ],
    preview: _UpdatePreviewKind.route,
    roles: <String>{'employee', 'foreman'},
  ),
  _UpdateSlide(
    icon: Icons.verified_user_outlined,
    title: 'Вход сотрудника через MAX',
    description:
        'Сотрудник подтверждает вход одной кнопкой в MAX — без ручного переписывания кода.',
    points: <String>[
      'AppСтрой автоматически продолжает вход после подтверждения.',
      'Номер сверяется с карточкой сотрудника компании.',
      'Резервный вход по коду сохранён на случай недоступности MAX.',
    ],
    preview: _UpdatePreviewKind.maxLogin,
    roles: <String>{'employee', 'foreman', 'hr'},
  ),
  _UpdateSlide(
    icon: Icons.task_alt_rounded,
    title: 'Реальные задачи и фотографии',
    description:
        'Сотрудник работает с настоящими назначенными задачами и фиксирует результат прямо в приложении.',
    points: <String>[
      'Начало смены и выполнение конкретной задачи разделены.',
      'К задачам прикрепляются рабочие фотографии.',
      'В профиле сохраняется история выполненных задач.',
    ],
    preview: _UpdatePreviewKind.tasks,
    roles: <String>{'employee', 'foreman'},
  ),
  _UpdateSlide(
    icon: Icons.table_view_outlined,
    title: 'Табели и выплаты без лишних переходов',
    description:
        'Работа с данными конкретного сотрудника стала быстрее и понятнее.',
    points: <String>[
      'Excel-табель выгружается за несколько месяцев или точный диапазон дат.',
      'В файле есть смены, ставка, начисления и итоговые суммы.',
      'Новую выплату можно добавить прямо из истории сотрудника.',
    ],
    preview: _UpdatePreviewKind.timesheet,
    roles: <String>{'foreman', 'accountant'},
  ),
  _UpdateSlide(
    icon: Icons.groups_rounded,
    title: 'Команда объекта',
    description:
        'Сотрудник и прораб видят актуальный состав своего объекта без раскрытия закрытых кадровых данных.',
    points: <String>[
      'В списке отображаются реальные коллеги текущего объекта.',
      'Телефоны, ставки, выплаты, комментарии и документы не раскрываются.',
      'Видимость рабочих сведений контролируется настройками доступа.',
    ],
    preview: _UpdatePreviewKind.team,
    roles: <String>{'employee', 'foreman'},
  ),
  _UpdateSlide(
    icon: Icons.inventory_2_outlined,
    title: 'Новая платформа снабжения',
    description:
        'В AppСтрой появилась отдельная роль снабженца и полный рабочий контур закупок.',
    points: <String>[
      'Заявки на материалы и оборудование, поставщики и доставки.',
      'Прораб создаёт заявки только по назначенному объекту.',
      'Бухгалтер видит суммы и сводку без права менять закупки.',
    ],
    preview: _UpdatePreviewKind.procurement,
    roles: <String>{'procurement', 'foreman', 'accountant'},
  ),
  _UpdateSlide(
    icon: Icons.extension_outlined,
    title: 'Инструменты с анимированным гидом',
    description:
        'Подключаемые возможности теперь собраны в одном понятном разделе.',
    points: <String>[
      'Вместо разрозненного каталога используется единый список инструментов.',
      'У каждого инструмента есть подробное описание назначения.',
      'Добавлен восьмишаговый анимированный сценарий работы.',
    ],
    preview: _UpdatePreviewKind.tools,
    roles: <String>{'developer'},
  ),
  _UpdateSlide(
    icon: Icons.desktop_windows_outlined,
    title: 'Новый интерфейс PWA и нижняя панель',
    description:
        'Компьютерная версия стала аккуратнее, просторнее и удобнее для ежедневной работы.',
    points: <String>[
      'Единые боковые отступы применяются ко всем страницам PWA.',
      'Нижняя стеклянная панель центрирована и расширена примерно до 20 см.',
      'Кнопки сохранения и основные действия больше не перекрываются навигацией.',
    ],
    preview: _UpdatePreviewKind.pwa,
    common: true,
  ),
  _UpdateSlide(
    icon: Icons.speed_rounded,
    title: 'Быстрее и надёжнее',
    description:
        'Большая внутренняя оптимизация сократила повторные загрузки и укрепила выпуск приложения.',
    points: <String>[
      'Ускорены Realtime, кабинет сотрудника, выплаты и загрузка личных данных.',
      'Добавлены безопасные кеши без изменения ролей и изоляции компаний.',
      'Пройдены 741 тест, Web-сборка, Android, Edge Functions и SQL.',
    ],
    preview: _UpdatePreviewKind.performance,
    common: true,
  ),
];

List<_UpdateSlide> _slidesFor(AppUserProfile profile) {
  if (profile.role == 'admin' || profile.role == 'developer') {
    return List<_UpdateSlide>.unmodifiable(_allSlides);
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
  final List<_UpdateSlide> slides;

  const _WhatsNewDialog({required this.profile, required this.slides});

  @override
  State<_WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<_WhatsNewDialog> {
  late final PageController _pageController;
  int _currentIndex = 0;

  bool get _isLast => _currentIndex == widget.slides.length - 1;

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
    if (index < 0 || index >= widget.slides.length) return;
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
    final dialogWidth = math.min(660.0, math.max(0.0, size.width - 20));
    final dialogHeight = math.min(780.0, math.max(0.0, size.height * 0.94));

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
                          '${_currentIndex + 1} из ${widget.slides.length} · ${widget.profile.roleTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Обновление августа 2026',
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
                  itemCount: widget.slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _UpdateSlideView(
                      slide: widget.slides[index],
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
                    onPressed: _currentIndex == 0
                        ? null
                        : () => _goTo(_currentIndex - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PageDots(
                      count: widget.slides.length,
                      selectedIndex: _currentIndex,
                      onSelected: _goTo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isLast
                        ? _finish
                        : () => _goTo(_currentIndex + 1),
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

class _UpdateSlideView extends StatelessWidget {
  final _UpdateSlide slide;
  final bool active;

  const _UpdateSlideView({required this.slide, required this.active});

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
            _AnimatedUpdatePreview(
              kind: slide.preview,
              icon: slide.icon,
              active: active,
            ),
            const SizedBox(height: 18),
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
            for (final point in slide.points) _PointRow(text: point),
          ],
        ),
      ),
    );
  }
}

class _AnimatedUpdatePreview extends StatefulWidget {
  final _UpdatePreviewKind kind;
  final IconData icon;
  final bool active;

  const _AnimatedUpdatePreview({
    required this.kind,
    required this.icon,
    required this.active,
  });

  @override
  State<_AnimatedUpdatePreview> createState() => _AnimatedUpdatePreviewState();
}

class _AnimatedUpdatePreviewState extends State<_AnimatedUpdatePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedUpdatePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.kind != widget.kind) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (disableAnimations) {
      _controller.stop();
      _controller.value = 0.58;
      return;
    }
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.78,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return _PreviewSurface(
            kind: widget.kind,
            icon: widget.icon,
            progress: progress,
          );
        },
      ),
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  final _UpdatePreviewKind kind;
  final IconData icon;
  final double progress;

  const _PreviewSurface({
    required this.kind,
    required this.icon,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wave = (math.sin(progress * math.pi * 2) + 1) / 2;
    final selected = (progress * 3).floor().clamp(0, 2);
    final labels = _previewLabels(kind);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: Transform.scale(
                scale: 0.94 + wave * 0.08,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: 0.12 + wave * 0.10,
                        ),
                        blurRadius: 28,
                        spreadRadius: wave * 4,
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 54, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < labels.length; index++) ...[
                  _AnimatedPreviewRow(
                    label: labels[index],
                    active: index == selected,
                    progress: index <= selected ? 0.70 + wave * 0.25 : 0.28,
                  ),
                  if (index != labels.length - 1) const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPreviewRow extends StatelessWidget {
  final String label;
  final bool active;
  final double progress;

  const _AnimatedPreviewRow({
    required this.label,
    required this.active,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: active ? scheme.primary : scheme.outlineVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.check_rounded : Icons.more_horiz_rounded,
              size: 15,
              color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: scheme.surface.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final String text;

  const _PointRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 15,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int selectedIndex;
  final Future<void> Function(int index) onSelected;

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
            label: 'Слайд ${index + 1}',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

List<String> _previewLabels(_UpdatePreviewKind kind) {
  return switch (kind) {
    _UpdatePreviewKind.employee => <String>[
      'Начать рабочий день',
      'Открыть задачи',
      'Посмотреть профиль',
    ],
    _UpdatePreviewKind.route => <String>[
      'Запись маршрута',
      'Локальная очередь',
      'Проверка геозоны',
    ],
    _UpdatePreviewKind.maxLogin => <String>[
      'Ввести номер',
      'Подтвердить в MAX',
      'Вход выполнен',
    ],
    _UpdatePreviewKind.tasks => <String>[
      'Открыть задачу',
      'Добавить фотографии',
      'Отметить выполнение',
    ],
    _UpdatePreviewKind.timesheet => <String>[
      'Выбрать период',
      'Сформировать Excel',
      'Добавить выплату',
    ],
    _UpdatePreviewKind.team => <String>[
      'Текущий объект',
      'Список коллег',
      'Защищённые данные',
    ],
    _UpdatePreviewKind.procurement => <String>[
      'Создать заявку',
      'Выбрать поставщика',
      'Принять доставку',
    ],
    _UpdatePreviewKind.tools => <String>[
      'Выбрать инструмент',
      'Посмотреть описание',
      'Пройти анимированный гид',
    ],
    _UpdatePreviewKind.pwa => <String>[
      'Единые края',
      'Панель 20 см',
      'Свободные рабочие кнопки',
    ],
    _UpdatePreviewKind.performance => <String>[
      'Быстрый Realtime',
      'Безопасные кеши',
      '741 проверка',
    ],
  };
}
