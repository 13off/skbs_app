part of 'role_aware_whats_new_gate.dart';

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
                    child: _AmbientGlow(
                      size: 260,
                      color: Color(0x334A8CFF),
                    ),
                  ),
                  const Positioned(
                    bottom: -100,
                    left: -80,
                    child: _AmbientGlow(
                      size: 240,
                      color: Color(0x222FC9FF),
                    ),
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
                'С 12 августа · $roleTitle · $current из $count',
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
            backgroundColor: const Color(0x17FFFFFF),
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
    _motionDisabled = MediaQuery.of(context).disableAnimations;
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
      _UpdatePreviewKind.managerTodos => _ManagerTodosScene(phase: phase),
      _UpdatePreviewKind.fines => _FinesScene(phase: phase),
      _UpdatePreviewKind.legal => _LegalScene(phase: phase),
      _UpdatePreviewKind.glass => _GlassScene(phase: phase),
      _UpdatePreviewKind.photos => _PhotosScene(phase: phase),
      _UpdatePreviewKind.stability => _StabilityScene(phase: phase),
    };
  }
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
            backgroundColor: const Color(0x17FFFFFF),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (index) {
        final selected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: selected ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF4A8CFF)
                  : const Color(0xFF455268),
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
            colors: <Color>[color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _whatsNewGlassDecoration({double radius = 20}) {
  return BoxDecoration(
    color: const Color(0x17FFFFFF),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0x334A8CFF)),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 18,
        offset: Offset(0, 9),
      ),
    ],
  );
}

double _whatsNewStagger(double phase, double start, double end) {
  if (phase <= start) return 0;
  if (phase >= end) return 1;
  final value = (phase - start) / (end - start);
  return Curves.easeOutCubic.transform(value);
}
