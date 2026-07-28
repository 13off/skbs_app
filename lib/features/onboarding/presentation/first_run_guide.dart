import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../role_preview/role_preview_controller.dart';

class FirstRunGuide {
  FirstRunGuide._();

  static const String version = '2026-07-28-v2-animated';

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

    final steps = _stepsFor(profile);
    final shown = await _GuideOverlay.show(
      context: context,
      profile: profile,
      steps: steps,
    );
    if (!shown) return false;

    try {
      await preferences?.setBool(key, true);
    } catch (_) {
      // Ошибка локального хранилища не блокирует работу приложения.
    }
    return true;
  }

  static List<_GuideStep> _stepsFor(AppUserProfile profile) {
    if (profile.role == 'employee') {
      return const <_GuideStep>[
        _GuideStep(
          targets: ['Главная'],
          icon: Icons.home_outlined,
          title: 'Главная',
          text:
              'Здесь видны текущий объект, задача на сегодня, смены и личная сводка.',
        ),
        _GuideStep(
          targets: ['Задачи'],
          icon: Icons.task_alt_outlined,
          title: 'Твои задачи',
          text:
              'Открывай назначенные работы, проверяй описание и текущий статус.',
        ),
        _GuideStep(
          targets: ['Табель'],
          icon: Icons.calendar_month_outlined,
          title: 'Личный табель',
          text:
              'Календарь показывает смены, часы, объект и предварительное начисление.',
        ),
        _GuideStep(
          targets: ['Документы'],
          icon: Icons.folder_copy_outlined,
          title: 'Документы',
          text:
              'Здесь находятся выданные тебе документы и их текущее состояние.',
        ),
        _GuideStep(
          targets: ['Профиль'],
          icon: Icons.person_outline_rounded,
          title: 'Профиль',
          text: 'Проверяй личные данные и настройки своего кабинета.',
        ),
      ];
    }

    if (profile.isForeman) {
      return const <_GuideStep>[
        _GuideStep(
          targets: ['Смена', 'Главная'],
          icon: Icons.home_outlined,
          title: 'Рабочая смена',
          text:
              'На стартовом экране собраны состояние объекта и быстрые рабочие действия.',
        ),
        _GuideStep(
          targets: ['Задачи'],
          icon: Icons.assignment_outlined,
          title: 'Задачи объекта',
          text:
              'Создавай задачи, назначай исполнителей, добавляй фото и сохраняй черновики.',
        ),
        _GuideStep(
          targets: ['Табель'],
          icon: Icons.fact_check_outlined,
          title: 'Табель',
          text:
              'Отмечай смены сотрудников своего объекта и проверяй выбранную дату.',
        ),
        _GuideStep(
          targets: ['Профиль'],
          icon: Icons.person_outline_rounded,
          title: 'Профиль и уведомления',
          text:
              'Здесь находятся настройки, данные пользователя и служебные разделы.',
        ),
      ];
    }

    if (profile.isHr) {
      return const <_GuideStep>[
        _GuideStep(
          targets: ['Сегодня'],
          icon: Icons.home_outlined,
          title: 'Сводка HR',
          text:
              'Стартовая страница показывает текущую загрузку и ближайшие действия.',
        ),
        _GuideStep(
          targets: ['Кандидаты'],
          icon: Icons.view_kanban_outlined,
          title: 'Кандидаты',
          text:
              'Веди кандидатов по этапам, сохраняй историю общения и ответственных.',
        ),
        _GuideStep(
          targets: ['Оформление'],
          icon: Icons.assignment_ind_outlined,
          title: 'Оформление',
          text:
              'Проверяй данные, согласия и комплект кадровых документов кандидата.',
        ),
        _GuideStep(
          targets: ['Выход'],
          icon: Icons.flight_takeoff_outlined,
          title: 'Выход на объект',
          text:
              'Контролируй мобилизацию, поездку, прибытие и фактический выход сотрудника.',
        ),
        _GuideStep(
          targets: ['Профиль'],
          icon: Icons.person_outline_rounded,
          title: 'Профиль',
          text: 'Здесь находятся настройки и личные данные специалиста.',
        ),
      ];
    }

    if (profile.isAccountant) {
      return const <_GuideStep>[
        _GuideStep(
          targets: ['Сегодня'],
          icon: Icons.home_outlined,
          title: 'Сводка бухгалтера',
          text:
              'На главной видны денежные показатели и операции, требующие проверки.',
        ),
        _GuideStep(
          targets: ['Выплаты'],
          icon: Icons.payments_outlined,
          title: 'Выплаты',
          text:
              'Добавляй выплаты, выбирай расчётный период и прикладывай чеки.',
        ),
        _GuideStep(
          targets: ['Отчёты'],
          icon: Icons.summarize_outlined,
          title: 'Отчёты',
          text:
              'Формируй отчёты по периоду, фактическим датам выплат и сотрудникам.',
        ),
        _GuideStep(
          targets: ['Контроль'],
          icon: Icons.fact_check_outlined,
          title: 'Контроль',
          text:
              'Проверяй расхождения табеля, выплат, остатков и подтверждающих файлов.',
        ),
        _GuideStep(
          targets: ['Профиль'],
          icon: Icons.person_outline_rounded,
          title: 'Профиль',
          text: 'Личные настройки и данные текущего пользователя.',
        ),
      ];
    }

    if (profile.isLawyer) {
      return const <_GuideStep>[
        _GuideStep(
          targets: ['Сегодня'],
          icon: Icons.home_outlined,
          title: 'Юридическая сводка',
          text:
              'Здесь собраны ближайшие сроки, риски и документы, требующие внимания.',
        ),
        _GuideStep(
          targets: ['Документы'],
          icon: Icons.description_outlined,
          title: 'Документы',
          text:
              'Работай с юридическими документами, версиями, контрагентами и сроками.',
        ),
        _GuideStep(
          targets: ['Вопросы'],
          icon: Icons.gavel_outlined,
          title: 'Юридические вопросы',
          text:
              'Веди дела, решения, ответственных и историю изменения статусов.',
        ),
        _GuideStep(
          targets: ['Профиль'],
          icon: Icons.person_outline_rounded,
          title: 'Профиль',
          text: 'Настройки и личные данные юридического специалиста.',
        ),
      ];
    }

    if (profile.isDeveloper) {
      return const <_GuideStep>[
        _GuideStep(
          targets: ['Конструктор'],
          icon: Icons.dashboard_customize_outlined,
          title: 'Конструктор компании',
          text:
              'Здесь находятся ограничения объектов, матрица прав, ИИ-диспетчер и системные настройки.',
        ),
        _GuideStep(
          targets: ['Профиль'],
          icon: Icons.person_outline_rounded,
          title: 'Профиль и просмотр ролей',
          text:
              'Используй профиль для личных настроек и безопасного просмотра других платформ.',
        ),
      ];
    }

    return const <_GuideStep>[
      _GuideStep(
        targets: ['Главная'],
        icon: Icons.home_outlined,
        title: 'Главная',
        text:
            'Выбирай объект и открывай основные рабочие показатели компании.',
      ),
      _GuideStep(
        targets: ['Люди'],
        icon: Icons.groups_outlined,
        title: 'Сотрудники',
        text:
            'Карточки сотрудников связывают назначения, табель, задачи, выплаты и документы.',
      ),
      _GuideStep(
        targets: ['Отчёты', 'Табель'],
        icon: Icons.analytics_outlined,
        title: 'Отчёты и табель',
        text:
            'Контролируй смены, начисления, проблемы и общую аналитику объектов.',
      ),
      _GuideStep(
        targets: ['Задачи'],
        icon: Icons.assignment_outlined,
        title: 'Задачи',
        text:
            'Планируй работы, назначай исполнителей и следи за выполнением.',
      ),
      _GuideStep(
        targets: ['Профиль'],
        icon: Icons.person_outline_rounded,
        title: 'Профиль и настройки',
        text:
            'Здесь находятся личные настройки, компания и просмотр платформ ролей.',
      ),
    ];
  }
}

class _GuideOverlay extends StatefulWidget {
  final BuildContext rootContext;
  final AppUserProfile profile;
  final List<_GuideStep> steps;
  final VoidCallback onFinish;

  const _GuideOverlay({
    required this.rootContext,
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
        rootContext: context,
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
    if (retryScheduled || retries >= 15) return;
    retryScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(() {
        retryScheduled = false;
        retries++;
      });
    });
  }

  Rect? findTarget(Size screenSize) {
    if (!widget.rootContext.mounted) return null;
    final candidates = <Rect>[];
    final root = widget.rootContext as Element;

    void visit(Element element, bool hidden) {
      final current = element.widget;
      var nextHidden = hidden;
      if (current is Offstage && current.offstage) nextHidden = true;
      if (current is Visibility && !current.visible) nextHidden = true;

      if (!nextHidden && current is Text) {
        final label = current.data?.trim() ?? '';
        if (step.targets.contains(label)) {
          final renderObject = element.findRenderObject();
          if (renderObject is RenderBox &&
              renderObject.attached &&
              renderObject.hasSize) {
            final textRect =
                renderObject.localToGlobal(Offset.zero) & renderObject.size;
            if (_visible(textRect, screenSize)) {
              candidates.add(
                _interactiveRect(element, textRect, screenSize),
              );
            }
          }
        }
      }
      element.visitChildren((child) => visit(child, nextHidden));
    }

    visit(root, false);
    if (candidates.isEmpty) {
      scheduleRetry();
      return null;
    }

    candidates.sort((a, b) {
      final vertical = b.center.dy.compareTo(a.center.dy);
      if (vertical != 0) return vertical;
      return b.longestSide.compareTo(a.longestSide);
    });
    final rect = candidates.first.inflate(5);
    return Rect.fromLTRB(
      math.max(8, rect.left),
      math.max(8, rect.top),
      math.min(screenSize.width - 8, rect.right),
      math.min(screenSize.height - 8, rect.bottom),
    );
  }

  Rect _interactiveRect(Element element, Rect textRect, Size screenSize) {
    var best = textRect;
    element.visitAncestorElements((ancestor) {
      final renderObject = ancestor.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        return true;
      }
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      final maxWidth = math.min(420.0, screenSize.width * 0.55);
      final candidate = rect.height >= 40 &&
          rect.height <= 100 &&
          rect.width >= textRect.width &&
          rect.width <= maxWidth &&
          rect.bottom >= screenSize.height * 0.62 &&
          _visible(rect, screenSize);
      final rectArea = rect.width * rect.height;
      final bestArea = best.width * best.height;
      if (candidate && rectArea > bestArea) best = rect;
      return true;
    });

    if (best == textRect) {
      return Rect.fromLTRB(
        textRect.left - 22,
        textRect.top - 38,
        textRect.right + 22,
        textRect.bottom + 12,
      );
    }
    return best;
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
    final targetReady = target != null || retries >= 15;
    final bubbleWidth = math.min(430.0, screen.width - 32);
    final bubbleLeft = target == null
        ? (screen.width - bubbleWidth) / 2
        : (target.center.dx - bubbleWidth / 2)
            .clamp(16.0, screen.width - bubbleWidth - 16)
            .toDouble();
    final bubbleBottom = target == null
        ? math.max(120.0, screen.height * 0.18)
        : math.max(110.0, screen.height - target.top + 32);

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
                    onPrevious: stepIndex == 0
                        ? null
                        : () => changeStep(-1),
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
        key: ValueKey<String>('guide-bubble-$stepIndex'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black38,
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onSkip, child: const Text('Пропустить')),
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
                    ? 'Элемент недоступен в текущей компоновке — можно продолжить.'
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
    if (target == null) {
      canvas.drawRect(full, Paint()..color = barrierColor);
      return;
    }

    final hole = RRect.fromRectAndRadius(
      target!.inflate(3 + 3 * pulse),
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
  final List<String> targets;
  final IconData icon;
  final String title;
  final String text;

  const _GuideStep({
    required this.targets,
    required this.icon,
    required this.title,
    required this.text,
  });
}
