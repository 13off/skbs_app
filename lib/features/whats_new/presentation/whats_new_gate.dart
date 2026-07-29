import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/liquid_glass.dart';
import '../../onboarding/presentation/first_run_guide.dart';

class WhatsNewGate extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const WhatsNewGate({super.key, required this.profile, required this.child});

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  static const String releaseId = 'mobile-2026-07-29-animated-whats-new';
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
      // Окно всё равно можно показать; ошибка локального хранилища не блокирует вход.
    }

    if (!mounted) return;
    final guideShown = await FirstRunGuide.showIfNeeded(
      context: context,
      profile: widget.profile,
      preferences: preferences,
    );
    if (guideShown || !mounted) return;
    if (seenRelease == releaseId) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WhatsNewDialog(),
    );

    try {
      await preferences?.setString(_preferenceKey, releaseId);
    } catch (_) {
      // Пользователь уже посмотрел презентацию в текущем запуске.
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
      icon: Icons.badge_outlined,
      title: 'Единый кабинет сотрудника',
      description:
          'Личный кабинет теперь выглядит как полноценная часть AppСтрой, а не отдельный экран.',
      points: <String>[
        'Общая стеклянная нижняя навигация.',
        'Единые шапки, карточки, отступы и темы.',
        'Задачи, табель, документы и расчёты остались на своих местах.',
      ],
      demo: _WhatsNewDemoKind.employeeCabinet,
    ),
    _WhatsNewSlide(
      icon: Icons.view_carousel_outlined,
      title: 'Отчёты разделены по страницам',
      description:
          'Длинные сводки больше не растягивают один экран: нужный раздел открывается отдельно.',
      points: <String>[
        'История диспетчера вынесена на собственную страницу.',
        'Вклад сотрудников и проблемные разделы открываются отдельно.',
        'Главные действия остаются видимыми сверху.',
      ],
      demo: _WhatsNewDemoKind.reportPages,
    ),
    _WhatsNewSlide(
      icon: Icons.dark_mode_outlined,
      title: 'Тема меняется плавно',
      description:
          'Переключение светлого и тёмного режима обновляет весь интерфейс без перезапуска.',
      points: <String>[
        'Сохраняются выбранная вкладка и открытые страницы.',
        'Карточки, текст и фон меняются одновременно.',
        'Анимация ниже показывает реальное поведение переключателя.',
      ],
      demo: _WhatsNewDemoKind.themeToggle,
    ),
    _WhatsNewSlide(
      icon: Icons.speed_rounded,
      title: 'Рабочие показатели стали нагляднее',
      description:
          'КПД сотрудника можно показать не сухой цифрой, а понятной интерактивной шкалой.',
      points: <String>[
        'Ползунок демонстрирует изменение показателя.',
        'Процент и статус обновляются синхронно.',
        'Такие мини-демонстрации можно добавлять для каждой новой функции.',
      ],
      demo: _WhatsNewDemoKind.kpiSlider,
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
    final dialogWidth = math.min(620.0, math.max(0.0, size.width - 24));
    final dialogHeight = math.min(720.0, math.max(0.0, size.height * 0.92));

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
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
                          '${_currentIndex + 1} из ${slides.length} · листай или используй стрелки',
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PageDots(
                      count: slides.length,
                      selectedIndex: _currentIndex,
                      onSelected: _goTo,
                    ),
                  ),
                  const SizedBox(width: 12),
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

  const _WhatsNewSlideView({required this.slide, required this.active});

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
    return Row(
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
    );
  }
}

class _DemoFrame extends StatelessWidget {
  final _WhatsNewDemoKind kind;
  final bool active;

  const _DemoFrame({required this.kind, required this.active});

  @override
  Widget build(BuildContext context) {
    final child = switch (kind) {
      _WhatsNewDemoKind.employeeCabinet =>
        _EmployeeCabinetDemo(active: active),
      _WhatsNewDemoKind.reportPages => _ReportPagesDemo(active: active),
      _WhatsNewDemoKind.themeToggle => _ThemeToggleDemo(active: active),
      _WhatsNewDemoKind.kpiSlider => _KpiSliderDemo(active: active),
    };

    return AspectRatio(
      aspectRatio: 1.75,
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

class _EmployeeCabinetDemo extends StatelessWidget {
  final bool active;

  const _EmployeeCabinetDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 3600),
      reducedMotionValue: 0.58,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final cardOne = Curves.easeOutBack.transform(_segment(progress, 0.04, 0.23));
        final cardTwo = Curves.easeOutBack.transform(_segment(progress, 0.14, 0.34));
        final cardThree =
            Curves.easeOutBack.transform(_segment(progress, 0.24, 0.44));
        final selectedIndex = ((progress * 5).floor()) % 5;

        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.engineering_rounded,
                        size: 17,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Личный кабинет',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            'Объект: Центральный',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _AnimatedDemoCard(
                          amount: cardOne,
                          icon: Icons.task_alt_rounded,
                          title: 'Задача',
                          value: 'Армирование',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            Expanded(
                              child: _AnimatedDemoCard(
                                amount: cardTwo,
                                icon: Icons.calendar_month_rounded,
                                title: 'Смены',
                                value: '18',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _AnimatedDemoCard(
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
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 5;
                  return SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          left: selectedIndex * itemWidth + 5,
                          top: 4,
                          width: itemWidth - 10,
                          height: 36,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                        Row(
                          children: const [
                            _DemoNavIcon(icon: Icons.home_rounded),
                            _DemoNavIcon(icon: Icons.task_alt_rounded),
                            _DemoNavIcon(icon: Icons.calendar_month_rounded),
                            _DemoNavIcon(icon: Icons.folder_copy_rounded),
                            _DemoNavIcon(icon: Icons.person_rounded),
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

class _AnimatedDemoCard extends StatelessWidget {
  final double amount;
  final IconData icon;
  final String title;
  final String value;

  const _AnimatedDemoCard({
    required this.amount,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: Offset(0, 18 * (1 - amount)),
      child: Transform.scale(
        scale: 0.92 + 0.08 * amount,
        child: Opacity(
          opacity: amount.clamp(0.0, 1.0).toDouble(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(height: 7),
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

class _DemoNavIcon extends StatelessWidget {
  final IconData icon;

  const _DemoNavIcon({required this.icon});

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

class _ReportPagesDemo extends StatelessWidget {
  final bool active;

  const _ReportPagesDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 3600),
      reducedMotionValue: 0.52,
      builder: (context, progress) {
        final scheme = Theme.of(context).colorScheme;
        final spread = _forwardAndBack(progress);

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalStep = math.min(118.0, constraints.maxWidth * 0.28);
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 4,
                  child: Text(
                    spread < 0.45 ? 'Одна длинная сводка' : 'Отдельные страницы',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                for (var index = 0; index < 3; index++)
                  Transform.translate(
                    offset: Offset(
                      (index - 1) * horizontalStep * spread,
                      16 + (index == 1 ? -8 : 7) * spread,
                    ),
                    child: Transform.rotate(
                      angle: (index - 1) * 0.055 * (1 - spread),
                      child: _MiniReportPage(
                        icon: const [
                          Icons.history_rounded,
                          Icons.groups_2_outlined,
                          Icons.warning_amber_rounded,
                        ][index],
                        title: const [
                          'История',
                          'Команда',
                          'Проблемы',
                        ][index],
                        accent: Color.lerp(
                          scheme.onSurfaceVariant,
                          scheme.primary,
                          spread,
                        )!,
                        scale: 1 - index * 0.035 * (1 - spread),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 2,
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 17,
                        color: scheme.primary.withValues(alpha: spread),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Каждый раздел открывается отдельно',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MiniReportPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final double scale;

  const _MiniReportPage({
    required this.icon,
    required this.title,
    required this.accent,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 112,
        height: 145,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: accent),
            const SizedBox(height: 7),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            for (final width in const <double>[0.9, 0.72, 0.82, 0.56])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FractionallySizedBox(
                  widthFactor: width,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Container(
              width: double.infinity,
              height: 24,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: accent,
              ),
            ),
          ],
        ),
      ),
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
          const Color(0xFF111820),
          amount,
        )!;
        final surface = Color.lerp(
          Colors.white,
          const Color(0xFF202A35),
          amount,
        )!;
        final primaryText = Color.lerp(
          const Color(0xFF1A1E24),
          const Color(0xFFF3F6FA),
          amount,
        )!;
        final mutedText = Color.lerp(
          const Color(0xFF68717D),
          const Color(0xFF9FADBB),
          amount,
        )!;
        final accent = Color.lerp(
          const Color(0xFF20252B),
          const Color(0xFF4AA8FF),
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
                  _AnimatedThemeSwitch(amount: amount, accent: accent),
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
                        'Все экраны меняются одновременно',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _ThemeMetric(
                            label: 'Сотрудники',
                            value: '48',
                            color: primaryText,
                            mutedColor: mutedText,
                            accent: accent,
                          ),
                          const SizedBox(width: 8),
                          _ThemeMetric(
                            label: 'Смены',
                            value: '312',
                            color: primaryText,
                            mutedColor: mutedText,
                            accent: accent,
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

class _AnimatedThemeSwitch extends StatelessWidget {
  final double amount;
  final Color accent;

  const _AnimatedThemeSwitch({required this.amount, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 32,
      decoration: BoxDecoration(
        color: Color.lerp(
          Theme.of(context).colorScheme.outlineVariant,
          accent.withValues(alpha: 0.44),
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
                color: Color.lerp(Colors.white, accent, amount),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                amount < 0.5
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 14,
                color: amount < 0.5
                    ? const Color(0xFF8A6715)
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color mutedColor;
  final Color accent;

  const _ThemeMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.mutedColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiSliderDemo extends StatelessWidget {
  final bool active;

  const _KpiSliderDemo({required this.active});

  @override
  Widget build(BuildContext context) {
    return _LoopingDemo(
      active: active,
      duration: const Duration(milliseconds: 3800),
      reducedMotionValue: 0.5,
      builder: (context, progress) {
        final amount = _forwardAndBack(
          progress,
          forwardStart: 0.08,
          forwardEnd: 0.48,
          reverseStart: 0.68,
          reverseEnd: 0.96,
        );
        final percent = (42 + 46 * amount).round();
        final scheme = Theme.of(context).colorScheme;
        final accent = Color.lerp(
          const Color(0xFFE49A27),
          const Color(0xFF2FAA6F),
          amount,
        )!;
        final status = percent >= 80
            ? 'Высокий'
            : percent >= 60
                ? 'Стабильный'
                : 'Нужно внимание';

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'КПД сотрудника',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          status,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) {
                  const thumbSize = 28.0;
                  final travel = math.max(0.0, constraints.maxWidth - thumbSize);
                  final left = travel * amount;
                  final fingerOpacity =
                      Curves.easeIn.transform(_segment(progress, 0.04, 0.16)) *
                          (1 -
                              Curves.easeIn.transform(
                                _segment(progress, 0.54, 0.65),
                              ));

                  return SizedBox(
                    height: 68,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: thumbSize / 2,
                          right: thumbSize / 2,
                          top: 28,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Positioned(
                          left: thumbSize / 2,
                          top: 28,
                          width: travel * amount,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: 18,
                          child: Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.surface, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: left + 4,
                          top: -2,
                          child: Opacity(
                            opacity: fingerOpacity.clamp(0.0, 1.0).toDouble(),
                            child: Icon(
                              Icons.touch_app_rounded,
                              size: 24,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              Text(
                                'Цель 80%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                '100%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_graph_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        percent >= 80
                            ? 'Показатель достиг целевого уровня'
                            : 'Потяни ползунок к целевому уровню',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
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
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
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
  employeeCabinet,
  reportPages,
  themeToggle,
  kpiSlider,
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
