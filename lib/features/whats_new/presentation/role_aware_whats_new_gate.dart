import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';

class WhatsNewGate extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const WhatsNewGate({super.key, required this.profile, required this.child});

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  static const String releaseId =
      'mobile-2026-08-07-role-aware-major-update-v1';
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
      barrierColor: const Color(0xD905070B),
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
  procurement,
  employment,
  documents,
  flights,
  brand,
  performance,
  bugs,
}

class _UpdateSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> points;
  final _UpdatePreviewKind preview;
  final Set<String> roles;
  final bool employeeCommon;

  const _UpdateSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.preview,
    this.roles = const <String>{},
    this.employeeCommon = false,
  });
}

const List<_UpdateSlide> _allSlides = <_UpdateSlide>[
  _UpdateSlide(
    icon: Icons.phone_iphone_rounded,
    title: 'Новый кабинет сотрудника',
    description:
        'Рабочий день, задачи, история работы и профиль — теперь в одном спокойном и понятном кабинете.',
    points: <String>[
      'Главные ежедневные действия собраны на одном экране.',
      'Задачи и история работы всегда под рукой.',
      'Интерфейс стал проще и одинаково удобен на телефоне и компьютере.',
    ],
    preview: _UpdatePreviewKind.employee,
    employeeCommon: true,
  ),
  _UpdateSlide(
    icon: Icons.route_rounded,
    title: 'Геолокация и маршрут работы',
    description:
        'AppСтрой показывает маршрут сотрудника, время перемещений и положение относительно рабочего объекта.',
    points: <String>[
      'На карте видны реальные точки рабочего маршрута.',
      'Разрывы GPS больше не соединяются ложной прямой линией.',
      'Запись маршрута стала экономнее и меньше расходует заряд телефона.',
    ],
    preview: _UpdatePreviewKind.route,
    employeeCommon: true,
  ),
  _UpdateSlide(
    icon: Icons.inventory_2_outlined,
    title: 'Новая платформа снабжения',
    description:
        'В AppСтрой появился отдельный рабочий контур снабжения: от заявки до приёмки на объекте.',
    points: <String>[
      'Заявки на материалы и оборудование.',
      'Поставщики, закупки и контроль сроков.',
      'Доставки и приёмка собраны в едином процессе.',
    ],
    preview: _UpdatePreviewKind.procurement,
    roles: <String>{'procurement'},
  ),
  _UpdateSlide(
    icon: Icons.extension_rounded,
    title: 'AppСтрой Трудоустройство',
    description:
        'Оформление кандидатов стало отдельным подключаемым инструментом внутри AppСтрой.',
    points: <String>[
      'Путь кандидата от исходных документов до готового оформления.',
      'Инструмент можно включать и отключать без удаления данных.',
      'HR и юрист получают только свои рабочие действия.',
    ],
    preview: _UpdatePreviewKind.employment,
    roles: <String>{'hr', 'lawyer'},
  ),
  _UpdateSlide(
    icon: Icons.description_outlined,
    title: 'Документы нового уровня',
    description:
        'Шаблоны DOCX теперь можно редактировать прямо в AppСтрой, сохраняя структуру документа и историю версий.',
    points: <String>[
      'Обычный текст меняется без скачивания Word.',
      'Системные поля и маркеры автозаполнения защищены.',
      'Готовые документы формируются из утверждённых шаблонов.',
    ],
    preview: _UpdatePreviewKind.documents,
    roles: <String>{'hr', 'lawyer'},
  ),
  _UpdateSlide(
    icon: Icons.flight_takeoff_rounded,
    title: 'Календарь вылетов HR',
    description:
        'Билеты, даты, маршруты и напоминания по вылетам сотрудников теперь собраны в одном календаре.',
    points: <String>[
      'Билет прикрепляется прямо к карточке вылета.',
      'Видны точные дата, время, маршрут и номер рейса.',
      'Перед вылетом сотруднику можно отправить напоминание.',
    ],
    preview: _UpdatePreviewKind.flights,
    roles: <String>{'hr'},
  ),
  _UpdateSlide(
    icon: Icons.auto_awesome_rounded,
    title: 'Новый стиль AppСтрой',
    description:
        'Обновили фирменный образ приложения: логотип, заставку и движение интерфейса.',
    points: <String>[
      'Новый знак AppСтрой для светлой и тёмной темы.',
      'Здания на заставке вырастают по очереди.',
      'Название и слоган появляются фирменной анимацией.',
    ],
    preview: _UpdatePreviewKind.brand,
  ),
  _UpdateSlide(
    icon: Icons.speed_rounded,
    title: 'AppСтрой стал быстрее',
    description:
        'Мы ускорили загрузку данных, снизили фоновую нагрузку и сделали геолокацию экономнее.',
    points: <String>[
      'Меньше повторных загрузок и лишних обновлений.',
      'Маршрутная точка сохраняется не чаще одного раза в 10 минут.',
      'Фоновая работа бережнее относится к аккумулятору.',
    ],
    preview: _UpdatePreviewKind.performance,
    employeeCommon: true,
  ),
  _UpdateSlide(
    icon: Icons.verified_rounded,
    title: 'Исправлены ошибки',
    description:
        'Мы дочистили десятки мелких и крупных проблем, чтобы ежедневная работа в AppСтрой была спокойнее.',
    points: <String>[
      'Исправлены перекрытия, отступы и нижняя навигация.',
      'Улучшена работа карточек, экранов и форм на телефонах.',
      'Повышены стабильность и надёжность приложения.',
    ],
    preview: _UpdatePreviewKind.bugs,
    employeeCommon: true,
  ),
];

List<_UpdateSlide> _slidesFor(AppUserProfile profile) {
  if (profile.role == 'admin' || profile.role == 'developer') {
    return List<_UpdateSlide>.unmodifiable(_allSlides);
  }

  return _allSlides
      .where(
        (slide) =>
            slide.employeeCommon || slide.roles.contains(profile.role),
      )
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
      duration: const Duration(milliseconds: 430),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(690.0, math.max(0.0, size.width - 18));
    final height = math.min(790.0, math.max(0.0, size.height * 0.96));

    return Dialog(
      insetPadding: const EdgeInsets.all(9),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xF51A202B),
                    Color(0xF20D1119),
                    Color(0xF70A0D12),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0x334A8CFF)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 52,
                    offset: Offset(0, 24),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned(
                    top: -80,
                    right: -90,
                    child: _AmbientGlow(size: 260, color: Color(0x334A8CFF)),
                  ),
                  const Positioned(
                    bottom: -100,
                    left: -80,
                    child: _AmbientGlow(size: 240, color: Color(0x222FC9FF)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _DialogHeader(
                          roleTitle: widget.profile.roleTitle,
                          current: _currentIndex + 1,
                          count: widget.slides.length,
                          onClose: _finish,
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 10),
                        _DialogNavigation(
                          currentIndex: _currentIndex,
                          count: widget.slides.length,
                          isLast: _isLast,
                          onBack: _currentIndex == 0
                              ? null
                              : () => _goTo(_currentIndex - 1),
                          onNext: _isLast
                              ? _finish
                              : () => _goTo(_currentIndex + 1),
                          onSelected: _goTo,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final String roleTitle;
  final int current;
  final int count;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.roleTitle,
    required this.current,
    required this.count,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF4A8CFF), Color(0xFF2468D8)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x554A8CFF), blurRadius: 22),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Что нового в AppСтрой',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$roleTitle · $current из $count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFAAB4C5),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Закрыть',
          onPressed: onClose,
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0x171FFFFFF),
          ),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _UpdateSlideView extends StatelessWidget {
  final _UpdateSlide slide;
  final bool active;

  const _UpdateSlideView({required this.slide, required this.active});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _AnimatedUpdatePreview(kind: slide.preview, active: active),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x184A8CFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x334A8CFF)),
                  ),
                  child: Icon(slide.icon, color: const Color(0xFF75A9FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              slide.description,
              style: const TextStyle(
                color: Color(0xFFC7CFDB),
                fontSize: 15.5,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            for (final point in slide.points) _PointRow(text: point),
          ],
        ),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final String text;

  const _PointRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF4A8CFF),
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0x884A8CFF), blurRadius: 9),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFE2E7EF),
                fontSize: 14,
                height: 1.38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedUpdatePreview extends StatefulWidget {
  final _UpdatePreviewKind kind;
  final bool active;

  const _AnimatedUpdatePreview({required this.kind, required this.active});

  @override
  State<_AnimatedUpdatePreview> createState() =>
      _AnimatedUpdatePreviewState();
}

class _AnimatedUpdatePreviewState extends State<_AnimatedUpdatePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.of(context).disableAnimations;
    if (_motionDisabled == disabled &&
        (disabled || _controller.isAnimating || !widget.active)) {
      return;
    }
    _motionDisabled = disabled;
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _AnimatedUpdatePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    if (_motionDisabled) {
      _controller.stop();
      _controller.value = 0.72;
      return;
    }
    if (widget.active) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
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
      builder: (context, _) {
        final phase = _motionDisabled ? 0.72 : _controller.value;
        final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
        return Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF182234), Color(0xFF0D141F)],
            ),
            border: Border.all(color: const Color(0x334A8CFF)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF2468D8).withValues(
                  alpha: 0.10 + pulse * 0.08,
                ),
                blurRadius: 32,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -70 + pulse * 8,
                right: -50,
                child: const _AmbientGlow(
                  size: 190,
                  color: Color(0x334A8CFF),
                ),
              ),
              Positioned(
                bottom: -80 - pulse * 6,
                left: -55,
                child: const _AmbientGlow(
                  size: 180,
                  color: Color(0x222FC9FF),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: _SceneArtwork(
                    kind: widget.kind,
                    phase: phase,
                    pulse: pulse,
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

class _SceneArtwork extends StatelessWidget {
  final _UpdatePreviewKind kind;
  final double phase;
  final double pulse;

  const _SceneArtwork({
    required this.kind,
    required this.phase,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      _UpdatePreviewKind.employee => _employee(),
      _UpdatePreviewKind.route => _route(),
      _UpdatePreviewKind.procurement => _procurement(),
      _UpdatePreviewKind.employment => _employment(),
      _UpdatePreviewKind.documents => _documents(),
      _UpdatePreviewKind.flights => _flights(),
      _UpdatePreviewKind.brand => _brand(),
      _UpdatePreviewKind.performance => _performance(),
      _UpdatePreviewKind.bugs => _bugs(),
    };
  }

  Widget _employee() {
    return Center(
      child: Transform.translate(
        offset: Offset(0, math.sin(phase * math.pi * 2) * 3),
        child: Container(
          width: 172,
          height: 212,
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 12),
          decoration: _deviceDecoration(),
          child: Column(
            children: <Widget>[
              const Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Color(0xFF2A3B55),
                    child: Icon(Icons.person_rounded, size: 15, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Expanded(child: _Line(widthFactor: 0.72)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: Transform.scale(
                    scale: 0.94 + pulse * 0.08,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFF4A8CFF), Color(0xFF2468D8)],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: Color(0x664A8CFF), blurRadius: 26),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Icon(Icons.home_rounded, size: 18, color: Color(0xFF75A9FF)),
                  Icon(Icons.task_alt_rounded, size: 18, color: Color(0xFF7C8798)),
                  Icon(Icons.person_rounded, size: 18, color: Color(0xFF7C8798)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _route() {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: CustomPaint(painter: _RoutePainter(progress: phase))),
        Positioned(
          top: 8,
          left: 8,
          child: _MiniPill(
            icon: Icons.location_on_rounded,
            label: 'Объект',
            highlighted: true,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: _MiniPill(
            icon: Icons.schedule_rounded,
            label: 'точка / 10 мин',
            highlighted: false,
          ),
        ),
      ],
    );
  }

  Widget _procurement() {
    final lift = math.sin(phase * math.pi * 2) * 4;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Transform.translate(
            offset: Offset(0, lift),
            child: const _ProcessCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Заявка',
            ),
          ),
          const _FlowArrow(),
          Transform.translate(
            offset: Offset(0, -lift),
            child: const _ProcessCard(
              icon: Icons.storefront_outlined,
              label: 'Поставщик',
            ),
          ),
          const _FlowArrow(),
          Transform.translate(
            offset: Offset(0, lift),
            child: const _ProcessCard(
              icon: Icons.local_shipping_outlined,
              label: 'Доставка',
            ),
          ),
        ],
      ),
    );
  }

  Widget _employment() {
    final progress = _stagger(phase, 0.08, 0.64);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: -0.08,
            child: Transform.translate(
              offset: Offset(-34 + progress * 8, 10),
              child: const _DocumentCard(label: 'Паспорт'),
            ),
          ),
          Transform.rotate(
            angle: 0.08,
            child: Transform.translate(
              offset: Offset(34 - progress * 8, 10),
              child: const _DocumentCard(label: 'Договор'),
            ),
          ),
          Transform.scale(
            scale: 0.92 + progress * 0.08,
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF4A8CFF), Color(0xFF245FC1)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x664A8CFF), blurRadius: 28),
                ],
              ),
              child: const Icon(Icons.extension_rounded, size: 48, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documents() {
    final edit = _stagger(phase, 0.18, 0.70);
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 184,
            height: 190,
            padding: const EdgeInsets.all(18),
            decoration: _paperDecoration(),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.description_rounded, color: Color(0xFF75A9FF)),
                    SizedBox(width: 8),
                    Expanded(child: _Line(widthFactor: 0.72)),
                  ],
                ),
                SizedBox(height: 20),
                _Line(widthFactor: 0.94),
                SizedBox(height: 10),
                _Line(widthFactor: 0.78),
                SizedBox(height: 10),
                _Line(widthFactor: 0.88),
                Spacer(),
                Row(
                  children: <Widget>[
                    _VersionChip(label: 'v1'),
                    SizedBox(width: 6),
                    _VersionChip(label: 'v2'),
                    SizedBox(width: 6),
                    _VersionChip(label: 'v3', active: true),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: -18 + edit * 5,
            top: 42 - edit * 14,
            child: Transform.rotate(
              angle: -0.55 + edit * 0.08,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A8CFF),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Color(0x664A8CFF), blurRadius: 22),
                  ],
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flights() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final x = 18 + (constraints.maxWidth - 78) * phase;
        final y = 76 - math.sin(phase * math.pi) * 42;
        return Stack(
          children: <Widget>[
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                width: 146,
                height: 138,
                padding: const EdgeInsets.all(14),
                decoration: _glassDecoration(),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('АВГУСТ', style: _smallLabelStyle),
                    SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        _CalendarDay(label: '12'),
                        SizedBox(width: 8),
                        _CalendarDay(label: '13', active: true),
                        SizedBox(width: 8),
                        _CalendarDay(label: '14'),
                      ],
                    ),
                    Spacer(),
                    _Line(widthFactor: 0.82),
                    SizedBox(height: 8),
                    _Line(widthFactor: 0.56),
                  ],
                ),
              ),
            ),
            Positioned(
              left: x,
              top: y,
              child: Transform.rotate(
                angle: -0.18,
                child: const Icon(
                  Icons.flight_rounded,
                  size: 46,
                  color: Color(0xFF75A9FF),
                  shadows: <Shadow>[
                    Shadow(color: Color(0x994A8CFF), blurRadius: 18),
                  ],
                ),
              ),
            ),
            const Positioned(
              right: 12,
              bottom: 12,
              child: _MiniPill(
                icon: Icons.notifications_active_rounded,
                label: 'Напомнить',
                highlighted: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _brand() {
    final first = _stagger(phase, 0.02, 0.26);
    final second = _stagger(phase, 0.14, 0.40);
    final third = _stagger(phase, 0.26, 0.52);
    final text = _stagger(phase, 0.46, 0.78);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 112,
            height: 132,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _Building(height: 66 * first + 4, width: 26),
                  const SizedBox(width: 7),
                  _Building(height: 104 * second + 4, width: 30),
                  const SizedBox(width: 7),
                  _Building(height: 82 * third + 4, width: 28),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Opacity(
            opacity: text,
            child: Transform.translate(
              offset: Offset(18 * (1 - text), 0),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AppСтрой',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'планируй • строй • управляй',
                    style: TextStyle(
                      color: Color(0xFF9EABC0),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _performance() {
    final wave = 0.55 + pulse * 0.35;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 128,
            height: 164,
            padding: const EdgeInsets.all(16),
            decoration: _glassDecoration(),
            child: Column(
              children: <Widget>[
                const Icon(Icons.battery_5_bar_rounded, size: 52, color: Color(0xFF75A9FF)),
                const SizedBox(height: 10),
                const Text(
                  'Экономнее',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: wave,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: const Color(0xFF293449),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A8CFF)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 148,
            height: 164,
            padding: const EdgeInsets.all(16),
            decoration: _glassDecoration(),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '10',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'минут',
                  style: TextStyle(
                    color: Color(0xFF9EABC0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'между маршрутными точками',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFC7CFDB),
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bugs() {
    final vanish = 1 - _stagger(phase, 0.05, 0.56);
    final solved = _stagger(phase, 0.45, 0.78);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          for (final item in const <(double, double, IconData)>[
            (-88, -52, Icons.error_outline_rounded),
            (82, -58, Icons.warning_amber_rounded),
            (-96, 54, Icons.close_rounded),
            (92, 48, Icons.bug_report_outlined),
          ])
            Transform.translate(
              offset: Offset(item.$1, item.$2),
              child: Opacity(
                opacity: _clamp01(vanish),
                child: Transform.scale(
                  scale: 0.7 + vanish * 0.3,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0x33FF667D),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$3, color: const Color(0xFFFF7D91)),
                  ),
                ),
              ),
            ),
          Transform.scale(
            scale: 0.72 + solved * 0.28,
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF4A8CFF), Color(0xFF2567D4)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF4A8CFF).withValues(alpha: 0.24 + solved * 0.20),
                    blurRadius: 34,
                  ),
                ],
              ),
              child: Opacity(
                opacity: _clamp01(solved),
                child: const Icon(Icons.check_rounded, size: 66, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final double progress;

  _RoutePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.42,
        size.width * 0.38,
        size.height * 0.82,
        size.width * 0.52,
        size.height * 0.54,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.26,
        size.width * 0.76,
        size.height * 0.60,
        size.width * 0.90,
        size.height * 0.28,
      );

    final shadow = Paint()
      ..color = const Color(0x554A8CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = const Color(0xFF75A9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, line);

    for (final point in <Offset>[
      Offset(size.width * 0.12, size.height * 0.72),
      Offset(size.width * 0.52, size.height * 0.54),
      Offset(size.width * 0.90, size.height * 0.28),
    ]) {
      canvas.drawCircle(point, 7, Paint()..color = const Color(0xFF0D141F));
      canvas.drawCircle(point, 4.5, Paint()..color = const Color(0xFF75A9FF));
    }

    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        13,
        Paint()..color = const Color(0x554A8CFF),
      );
      canvas.drawCircle(
        tangent.position,
        7,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _DialogNavigation extends StatelessWidget {
  final int currentIndex;
  final int count;
  final bool isLast;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final ValueChanged<int> onSelected;

  const _DialogNavigation({
    required this.currentIndex,
    required this.count,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Назад',
          onPressed: onBack,
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFF566172),
            backgroundColor: const Color(0x171FFFFFF),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PageDots(
            count: count,
            selectedIndex: currentIndex,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4A8CFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded),
          label: Text(isLast ? 'Готово' : 'Далее'),
        ),
      ],
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5,
      runSpacing: 5,
      children: List<Widget>.generate(count, (index) {
        final selected = index == selectedIndex;
        return InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(99),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: selected ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF4A8CFF)
                  : const Color(0xFF455166),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;

  const _MiniPill({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0x264A8CFF) : const Color(0xB30E151F),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: highlighted ? const Color(0x554A8CFF) : const Color(0x223FFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: highlighted ? const Color(0xFF75A9FF) : const Color(0xFFB8C1CE)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE0E6EF),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProcessCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: _glassDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 35, color: const Color(0xFF75A9FF)),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF617087), size: 18),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String label;

  const _DocumentCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 148,
      padding: const EdgeInsets.all(13),
      decoration: _paperDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.description_outlined, color: Color(0xFF75A9FF)),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _Line(widthFactor: 0.9),
          const SizedBox(height: 8),
          const _Line(widthFactor: 0.68),
          const Spacer(),
          const Align(
            alignment: Alignment.bottomRight,
            child: Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF75A9FF)),
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String label;
  final bool active;

  const _VersionChip({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0x334A8CFF) : const Color(0x151FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF75A9FF) : const Color(0xFF8995A8),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final String label;
  final bool active;

  const _CalendarDay({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4A8CFF) : const Color(0x181FFFFFF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Building extends StatelessWidget {
  final double height;
  final double width;

  const _Building({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF9FC2FF), Color(0xFF4A8CFF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x554A8CFF), blurRadius: 16),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final double widthFactor;

  const _Line({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF344258),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

const TextStyle _smallLabelStyle = TextStyle(
  color: Color(0xFF91A0B5),
  fontSize: 10.5,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.1,
);

BoxDecoration _deviceDecoration() => BoxDecoration(
  color: const Color(0xD90A0F17),
  borderRadius: BorderRadius.circular(27),
  border: Border.all(color: const Color(0x445A6A82)),
  boxShadow: const <BoxShadow>[
    BoxShadow(color: Color(0x77000000), blurRadius: 28, offset: Offset(0, 16)),
  ],
);

BoxDecoration _paperDecoration() => BoxDecoration(
  color: const Color(0xE8141C28),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0x334A8CFF)),
  boxShadow: const <BoxShadow>[
    BoxShadow(color: Color(0x55000000), blurRadius: 22, offset: Offset(0, 12)),
  ],
);

BoxDecoration _glassDecoration() => BoxDecoration(
  color: const Color(0xA9121A26),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0x2EFFFFFF)),
  boxShadow: const <BoxShadow>[
    BoxShadow(color: Color(0x44000000), blurRadius: 20, offset: Offset(0, 12)),
  ],
);

double _stagger(double value, double start, double end) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  final t = (value - start) / (end - start);
  return Curves.easeOutCubic.transform(t);
}

double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();
