import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../role_preview/role_preview_controller.dart';

class FirstRunGuide {
  FirstRunGuide._();

  static const String version = '2026-07-28-v4-root-target';

  static String preferenceKey(AppUserProfile profile) {
    return 'first_run_guide:$version:${profile.id}:${profile.role}';
  }

  static Future<bool> showIfNeeded({
    required BuildContext context,
    required AppUserProfile profile,
    required SharedPreferences? preferences,
  }) async {
    if (profile.isRolePreview) return false;
    if (profile.canPreviewRoles &&
        !RolePreviewController.state.value.isAdminMode) {
      return false;
    }

    final key = preferenceKey(profile);
    if (preferences?.getBool(key) == true) return false;
    if (!context.mounted) return false;

    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return false;

    final shown = await _GuideOverlay.show(
      context: context,
      profile: profile,
      steps: _stepsFor(profile),
    );
    if (!shown) return false;

    try {
      await preferences?.setBool(key, true);
    } catch (_) {
      // Ошибка локального хранилища не блокирует работу приложения.
    }
    return true;
  }

  static _GuideStep _step(
    int tabIndex,
    int tabCount,
    IconData icon,
    String title,
    String text,
  ) {
    return _GuideStep(
      tabIndex: tabIndex,
      tabCount: tabCount,
      icon: icon,
      title: title,
      text: text,
    );
  }

  static List<_GuideStep> _stepsFor(AppUserProfile profile) {
    if (profile.role == 'employee') {
      return <_GuideStep>[
        _step(
          0,
          5,
          Icons.home_outlined,
          'Главная',
          'Здесь видны текущий объект, задача на сегодня, смены и личная сводка.',
        ),
        _step(
          1,
          5,
          Icons.task_alt_outlined,
          'Твои задачи',
          'Открывай назначенные работы, проверяй описание и текущий статус.',
        ),
        _step(
          2,
          5,
          Icons.calendar_month_outlined,
          'Личный табель',
          'Календарь показывает смены, часы, объект и предварительное начисление.',
        ),
        _step(
          3,
          5,
          Icons.folder_copy_outlined,
          'Документы',
          'Здесь находятся выданные тебе документы и их текущее состояние.',
        ),
        _step(
          4,
          5,
          Icons.person_outline_rounded,
          'Профиль',
          'Проверяй личные данные и настройки своего кабинета.',
        ),
      ];
    }

    if (profile.isForeman) {
      return <_GuideStep>[
        _step(
          0,
          4,
          Icons.home_outlined,
          'Рабочая смена',
          'На стартовом экране собраны состояние объекта и быстрые рабочие действия.',
        ),
        _step(
          1,
          4,
          Icons.assignment_outlined,
          'Задачи объекта',
          'Создавай задачи, назначай исполнителей, добавляй фото и сохраняй черновики.',
        ),
        _step(
          2,
          4,
          Icons.fact_check_outlined,
          'Табель',
          'Отмечай смены сотрудников своего объекта и проверяй выбранную дату.',
        ),
        _step(
          3,
          4,
          Icons.person_outline_rounded,
          'Профиль и уведомления',
          'Здесь находятся настройки, данные пользователя и служебные разделы.',
        ),
      ];
    }

    if (profile.isHr) {
      return <_GuideStep>[
        _step(
          0,
          5,
          Icons.home_outlined,
          'Сводка HR',
          'Стартовая страница показывает текущую загрузку и ближайшие действия.',
        ),
        _step(
          1,
          5,
          Icons.view_kanban_outlined,
          'Кандидаты',
          'Веди кандидатов по этапам, сохраняй историю общения и ответственных.',
        ),
        _step(
          2,
          5,
          Icons.assignment_ind_outlined,
          'Оформление',
          'Проверяй данные, согласия и комплект кадровых документов кандидата.',
        ),
        _step(
          3,
          5,
          Icons.flight_takeoff_outlined,
          'Выход на объект',
          'Контролируй мобилизацию, поездку, прибытие и фактический выход сотрудника.',
        ),
        _step(
          4,
          5,
          Icons.person_outline_rounded,
          'Профиль',
          'Здесь находятся настройки и личные данные специалиста.',
        ),
      ];
    }

    if (profile.isAccountant) {
      return <_GuideStep>[
        _step(
          0,
          5,
          Icons.home_outlined,
          'Сводка бухгалтера',
          'На главной видны денежные показатели и операции, требующие проверки.',
        ),
        _step(
          1,
          5,
          Icons.payments_outlined,
          'Выплаты',
          'Добавляй выплаты, выбирай расчётный период и прикладывай чеки.',
        ),
        _step(
          2,
          5,
          Icons.summarize_outlined,
          'Отчёты',
          'Формируй отчёты по периоду, фактическим датам выплат и сотрудникам.',
        ),
        _step(
          3,
          5,
          Icons.fact_check_outlined,
          'Контроль',
          'Проверяй расхождения табеля, выплат, остатков и подтверждающих файлов.',
        ),
        _step(
          4,
          5,
          Icons.person_outline_rounded,
          'Профиль',
          'Личные настройки и данные текущего пользователя.',
        ),
      ];
    }

    if (profile.isLawyer) {
      return <_GuideStep>[
        _step(
          0,
          4,
          Icons.home_outlined,
          'Юридическая сводка',
          'Здесь собраны ближайшие сроки, риски и документы, требующие внимания.',
        ),
        _step(
          1,
          4,
          Icons.description_outlined,
          'Документы',
          'Работай с юридическими документами, версиями, контрагентами и сроками.',
        ),
        _step(
          2,
          4,
          Icons.gavel_outlined,
          'Юридические вопросы',
          'Веди дела, решения, ответственных и историю изменения статусов.',
        ),
        _step(
          3,
          4,
          Icons.person_outline_rounded,
          'Профиль',
          'Настройки и личные данные юридического специалиста.',
        ),
      ];
    }

    if (profile.isDeveloper) {
      return <_GuideStep>[
        _step(
          0,
          2,
          Icons.dashboard_customize_outlined,
          'Конструктор компании',
          'Здесь находятся ограничения объектов, матрица прав, ИИ-диспетчер и системные настройки.',
        ),
        _step(
          1,
          2,
          Icons.person_outline_rounded,
          'Профиль и просмотр ролей',
          'Используй профиль для личных настроек и безопасного просмотра других платформ.',
        ),
      ];
    }

    return <_GuideStep>[
      _step(
        0,
        5,
        Icons.home_outlined,
        'Главная',
        'Выбирай объект и открывай основные показатели компании.',
      ),
      _step(
        1,
        5,
        Icons.groups_outlined,
        'Сотрудники',
        'Карточки сотрудников связывают назначения, табель, задачи, выплаты и документы.',
      ),
      _step(
        2,
        5,
        Icons.analytics_outlined,
        'Отчёты и табель',
        'Контролируй смены, начисления, проблемы и общую аналитику объектов.',
      ),
      _step(
        3,
        5,
        Icons.assignment_outlined,
        'Задачи',
        'Планируй работы, назначай исполнителей и следи за выполнением.',
      ),
      _step(
        4,
        5,
        Icons.person_outline_rounded,
        'Профиль и настройки',
        'Здесь находятся личные настройки, компания и просмотр платформ ролей.',
      ),
    ];
  }
}

class _GuideOverlay extends StatefulWidget {
  final AppUserProfile profile;
  final List<_GuideStep> steps;
  final VoidCallback onFinish;

  const _GuideOverlay({
    required this.profile,
    required this.steps,
    required this.onFinish,
  });

  static Future<bool> show({
    required BuildContext context,
    required AppUserProfile profile,
    required List<_GuideStep> steps,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || steps.isEmpty) return false;

    final completer = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GuideOverlay(
        profile: profile,
        steps: steps,
        onFinish: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    overlay.insert(entry);
    await completer.future;
    return true;
  }

  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay>
    with SingleTickerProviderStateMixin {
  static const ValueKey<String> professionalPanelKey =
      ValueKey<String>('professional-bottom-navigation-panel');

  late final AnimationController pulseController;
  int stepIndex = 0;
  int retries = 0;
  bool retryScheduled = false;
  bool animationConfigured = false;

  _GuideStep get step => widget.steps[stepIndex];

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (animationConfigured) return;
    animationConfigured = true;
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled) {
      pulseController.value = 0;
    } else {
      pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  void changeStep(int delta) {
    final next = stepIndex + delta;
    if (next >= widget.steps.length) {
      widget.onFinish();
      return;
    }
    if (next < 0) return;
    setState(() {
      stepIndex = next;
      retries = 0;
      retryScheduled = false;
    });
  }

  void scheduleRetry() {
    if (retryScheduled || retries >= 20) return;
    retryScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() {
        retryScheduled = false;
        retries++;
      });
    });
  }

  Rect? findTarget(Size screenSize) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      scheduleRetry();
      return null;
    }

    final navigationRect = widget.profile.role == 'employee'
        ? _findEmployeeNavigationRect(root, screenSize)
        : _findProfessionalNavigationRect(root, screenSize);
    if (navigationRect == null) {
      scheduleRetry();
      return null;
    }

    final itemWidth = navigationRect.width / step.tabCount;
    final itemRect = Rect.fromLTWH(
      navigationRect.left + itemWidth * step.tabIndex,
      navigationRect.top,
      itemWidth,
      navigationRect.height,
    ).deflate(3);
    final inflated = itemRect.inflate(4);

    return Rect.fromLTRB(
      math.max(8, inflated.left),
      math.max(8, inflated.top),
      math.min(screenSize.width - 8, inflated.right),
      math.min(screenSize.height - 8, inflated.bottom),
    );
  }

  Rect? _findProfessionalNavigationRect(Element root, Size screenSize) {
    return _findBottommostVisibleRect(
      root,
      screenSize,
      matches: (widget) => widget.key == professionalPanelKey,
    );
  }

  Rect? _findEmployeeNavigationRect(Element root, Size screenSize) {
    return _findBottommostVisibleRect(
      root,
      screenSize,
      matches: (widget) => widget is NavigationBar,
    );
  }

  Rect? _findBottommostVisibleRect(
    Element root,
    Size screenSize, {
    required bool Function(Widget widget) matches,
  }) {
    final candidates = <Rect>[];

    void visit(Element element, bool hidden) {
      final current = element.widget;
      var nextHidden = hidden;
      if (current is Offstage && current.offstage) nextHidden = true;
      if (current is Visibility && !current.visible) nextHidden = true;

      if (!nextHidden && matches(current)) {
        final renderObject = element.findRenderObject();
        if (renderObject is RenderBox &&
            renderObject.attached &&
            renderObject.hasSize) {
          final rect =
              renderObject.localToGlobal(Offset.zero) & renderObject.size;
          final nearBottom = rect.bottom >= screenSize.height * 0.65;
          if (nearBottom && _visible(rect, screenSize)) {
            candidates.add(rect);
          }
        }
      }

      element.visitChildren((child) => visit(child, nextHidden));
    }

    visit(root, false);
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.bottom.compareTo(a.bottom));
    return candidates.first;
  }

  bool _visible(Rect rect, Size screenSize) {
    return rect.width > 0 &&
        rect.height > 0 &&
        rect.right > 0 &&
        rect.bottom > 0 &&
        rect.left < screenSize.width &&
        rect.top < screenSize.height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final target = findTarget(screen);
    final targetReady = target != null || retries >= 20;
    final bubbleWidth = math.min(430.0, screen.width - 32);
    final bubbleLeft = target == null
        ? (screen.width - bubbleWidth) / 2
        : (target.center.dx - bubbleWidth / 2)
            .clamp(16.0, screen.width - bubbleWidth - 16)
            .toDouble();
    final bubbleBottom = target == null
        ? math.max(120.0, screen.height * 0.18)
        : math.max(110.0, screen.height - target.top + 24);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, _) {
          final pulse = pulseController.value;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      target: target,
                      pulse: pulse,
                      barrierColor: Colors.black.withValues(alpha: 0.76),
                      accentColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (target != null)
                Positioned(
                  left: target.center.dx - 24,
                  top: math.max(8, target.top - 58 + 7 * pulse),
                  child: IgnorePointer(
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                      shadows: const <Shadow>[
                        Shadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: bubbleLeft,
                bottom: bubbleBottom,
                width: bubbleWidth,
                child: SafeArea(
                  minimum: const EdgeInsets.only(top: 12),
                  child: _GuideBubble(
                    key: ValueKey<int>(stepIndex),
                    profile: widget.profile,
                    step: step,
                    stepIndex: stepIndex,
                    stepCount: widget.steps.length,
                    targetFound: target != null,
                    targetReady: targetReady,
                    onSkip: widget.onFinish,
                    onPrevious:
                        stepIndex == 0 ? null : () => changeStep(-1),
                    onNext: () => changeStep(1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideBubble extends StatelessWidget {
  final AppUserProfile profile;
  final _GuideStep step;
  final int stepIndex;
  final int stepCount;
  final bool targetFound;
  final bool targetReady;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  const _GuideBubble({
    super.key,
    required this.profile,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.targetFound,
    required this.targetReady,
    required this.onSkip,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = stepIndex == stepCount - 1;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey<int>(stepIndex),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black38,
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(step.icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Обучение · ${profile.roleTitle}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Пропустить'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!targetFound) ...[
              const SizedBox(height: 9),
              Text(
                targetReady
                    ? 'Элемент не найден. Можно перейти дальше.'
                    : 'Подготавливаем нужный элемент…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: List<Widget>.generate(stepCount, (index) {
                      final active = index == stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                ),
                if (onPrevious != null) ...[
                  OutlinedButton(
                    onPressed: onPrevious,
                    child: const Text('Назад'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: targetReady ? onNext : null,
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  ),
                  label: Text(isLast ? 'Готово' : 'Далее'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final double pulse;
  final Color barrierColor;
  final Color accentColor;

  const _SpotlightPainter({
    required this.target,
    required this.pulse,
    required this.barrierColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final targetRect = target;
    if (targetRect == null) {
      canvas.drawRect(full, Paint()..color = barrierColor);
      return;
    }

    final hole = RRect.fromRectAndRadius(
      targetRect.inflate(3 + 3 * pulse),
      const Radius.circular(24),
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRRect(hole);
    canvas.drawPath(mask, Paint()..color = barrierColor);

    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + 2 * pulse
        ..color = accentColor.withValues(alpha: 0.78 - 0.18 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accentColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.target != target ||
        oldDelegate.pulse != pulse ||
        oldDelegate.barrierColor != barrierColor ||
        oldDelegate.accentColor != accentColor;
  }
}

class _GuideStep {
  final int tabIndex;
  final int tabCount;
  final IconData icon;
  final String title;
  final String text;

  const _GuideStep({
    required this.tabIndex,
    required this.tabCount,
    required this.icon,
    required this.title,
    required this.text,
  });
}
