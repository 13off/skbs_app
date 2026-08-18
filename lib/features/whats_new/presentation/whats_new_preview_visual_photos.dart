part of 'role_aware_whats_new_gate.dart';

class _GlassScene extends StatelessWidget {
  final double phase;

  const _GlassScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * math.pi * 2);
    return Center(
      child: SizedBox(
        width: 310,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.translate(
              offset: Offset(-72, 22 + wave * 4),
              child: Transform.rotate(
                angle: -0.08,
                child: const _VisualGlassCard(
                  title: 'Сотрудники',
                  icon: Icons.groups_rounded,
                  scale: 0.78,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(72, 24 - wave * 4),
              child: Transform.rotate(
                angle: 0.08,
                child: const _VisualGlassCard(
                  title: 'Расходы',
                  icon: Icons.payments_outlined,
                  scale: 0.70,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -24 + wave * 3),
              child: const _VisualGlassCard(
                title: 'AppСтрой',
                icon: Icons.apartment_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualGlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double scale;

  const _VisualGlassCard({
    required this.title,
    required this.icon,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 164,
        height: 112,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0x4AFFFFFF), Color(0x141E2A3D)],
          ),
          border: Border.all(color: const Color(0x445E98F5)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
            BoxShadow(color: Color(0x284A8CFF), blurRadius: 22),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: const Color(0xFF86B4FF), size: 27),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotosScene extends StatelessWidget {
  final double phase;

  const _PhotosScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final progress = _whatsNewStagger(phase, 0.10, 0.82);
    final percentage = (progress * 100).round();
    final wave = math.sin(phase * math.pi * 2);
    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _PhotoStack(label: 'ДО', offset: -wave * 2),
              const SizedBox(width: 18),
              _PhotoStack(label: 'ПОСЛЕ', offset: wave * 2),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: _whatsNewGlassDecoration(radius: 18),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.cloud_upload_outlined,
                    color: Color(0xFF75A9FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Загрузка 3 фотографий',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Color(0xFF8DB8FF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFF273247),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4A8CFF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoStack extends StatelessWidget {
  final String label;
  final double offset;

  const _PhotoStack({required this.label, required this.offset});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Container(
        width: 126,
        height: 128,
        padding: const EdgeInsets.all(10),
        decoration: _whatsNewGlassDecoration(radius: 21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(child: _PhotoThumbStack()),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9FB5D8),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbStack extends StatelessWidget {
  const _PhotoThumbStack();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const <Widget>[
        Positioned(
          left: 10,
          right: 0,
          top: 4,
          bottom: 0,
          child: _PhotoThumb(alpha: 0.45),
        ),
        Positioned(
          left: 5,
          right: 5,
          top: 2,
          bottom: 4,
          child: _PhotoThumb(alpha: 0.68),
        ),
        Positioned(
          left: 0,
          right: 10,
          top: 0,
          bottom: 8,
          child: _PhotoThumb(alpha: 1),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final double alpha;

  const _PhotoThumb({required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: alpha,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF55749F), Color(0xFF1F2E43)],
          ),
          border: Border.all(color: const Color(0x445A91E8)),
        ),
        child: const Center(
          child: Icon(
            Icons.landscape_rounded,
            color: Color(0xFFB4CCF3),
            size: 31,
          ),
        ),
      ),
    );
  }
}

class _StabilityScene extends StatelessWidget {
  final double phase;

  const _StabilityScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final solved = _whatsNewStagger(phase, 0.18, 0.70);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Transform.scale(
            scale: 0.88 + solved * 0.12,
            child: Container(
              width: 118,
              height: 118,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF4A8CFF), Color(0xFF225FC5)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x664A8CFF), blurRadius: 30),
                ],
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: Colors.white.withValues(alpha: 0.65 + solved * 0.35),
                size: 58,
              ),
            ),
          ),
          const SizedBox(width: 22),
          SizedBox(
            width: 146,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _StatusPreviewRow(label: 'iPhone / PWA', ready: solved > 0.18),
                const SizedBox(height: 9),
                _StatusPreviewRow(
                  label: 'Файлы и Storage',
                  ready: solved > 0.42,
                ),
                const SizedBox(height: 9),
                _StatusPreviewRow(
                  label: 'Данные компаний',
                  ready: solved > 0.66,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPreviewRow extends StatelessWidget {
  final String label;
  final bool ready;

  const _StatusPreviewRow({required this.label, required this.ready});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: _whatsNewGlassDecoration(radius: 14),
      child: Row(
        children: <Widget>[
          Icon(
            ready ? Icons.check_circle_rounded : Icons.more_horiz_rounded,
            color: ready ? const Color(0xFF75A9FF) : const Color(0xFF65738A),
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
