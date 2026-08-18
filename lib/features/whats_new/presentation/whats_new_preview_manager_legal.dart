part of 'role_aware_whats_new_gate.dart';

class _ManagerTodosScene extends StatelessWidget {
  final double phase;

  const _ManagerTodosScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final first = _whatsNewStagger(phase, 0.02, 0.30);
    final second = _whatsNewStagger(phase, 0.18, 0.48);
    final third = _whatsNewStagger(phase, 0.34, 0.64);
    return Center(
      child: SizedBox(
        width: 300,
        height: 190,
        child: Stack(
          children: <Widget>[
            _TodoPreviewCard(
              top: 0,
              opacity: first,
              icon: Icons.assignment_outlined,
              title: 'Взять объяснительные',
              meta: '08:00 · автоматически',
            ),
            _TodoPreviewCard(
              top: 62,
              opacity: second,
              icon: Icons.receipt_long_outlined,
              title: 'Проверить чеки',
              meta: 'Отчёт за вчера',
            ),
            _TodoPreviewCard(
              top: 124,
              opacity: third,
              icon: Icons.warning_amber_rounded,
              title: 'Закрыть риск по сроку',
              meta: 'Напоминание включено',
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoPreviewCard extends StatelessWidget {
  final double top;
  final double opacity;
  final IconData icon;
  final String title;
  final String meta;

  const _TodoPreviewCard({
    required this.top,
    required this.opacity,
    required this.icon,
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 12 + (1 - opacity) * 28,
      right: 12,
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: _whatsNewGlassDecoration(radius: 17),
          child: Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF75A9FF), size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8F9CAF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF728099),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinesScene extends StatelessWidget {
  final double phase;

  const _FinesScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final explanation = _whatsNewStagger(phase, 0.05, 0.34);
    final act = _whatsNewStagger(phase, 0.22, 0.52);
    final confirm = _whatsNewStagger(phase, 0.48, 0.76);
    return Center(
      child: SizedBox(
        width: 310,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              left: 10,
              top: 42,
              child: _FineDocumentBadge(
                label: 'Объяснительная',
                icon: Icons.description_outlined,
                progress: explanation,
              ),
            ),
            Positioned(
              right: 10,
              top: 42,
              child: _FineDocumentBadge(
                label: 'Подписанный акт',
                icon: Icons.fact_check_outlined,
                progress: act,
              ),
            ),
            Positioned(
              bottom: 4,
              child: Transform.scale(
                scale: 0.88 + confirm * 0.12,
                child: Opacity(
                  opacity: confirm,
                  child: Container(
                    width: 170,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF4A8CFF), Color(0xFF2768D3)],
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x554A8CFF), blurRadius: 24),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.gavel_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          '10 000 ₽',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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

class _FineDocumentBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final double progress;

  const _FineDocumentBadge({
    required this.label,
    required this.icon,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * 18),
        child: Container(
          width: 134,
          height: 76,
          padding: const EdgeInsets.all(12),
          decoration: _whatsNewGlassDecoration(radius: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: const Color(0xFF75A9FF), size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalScene extends StatelessWidget {
  final double phase;

  const _LegalScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final timeline = _whatsNewStagger(phase, 0.18, 0.82);
    return Column(
      children: <Widget>[
        const Row(
          children: <Widget>[
            _WhatsNewTabPill(label: 'Сегодня', active: true),
            SizedBox(width: 6),
            _WhatsNewTabPill(label: 'База'),
            SizedBox(width: 6),
            _WhatsNewTabPill(label: 'Документы'),
            SizedBox(width: 6),
            _WhatsNewTabPill(label: 'Дела'),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: _whatsNewGlassDecoration(radius: 22),
            child: Row(
              children: <Widget>[
                const Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ООО «СКБС»',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Юридическое досье',
                        style: TextStyle(
                          color: Color(0xFF93A1B6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      _WhatsNewMiniLine(width: 0.92),
                      SizedBox(height: 8),
                      _WhatsNewMiniLine(width: 0.70),
                      SizedBox(height: 8),
                      _WhatsNewMiniLine(width: 0.82),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var i = 0; i < 4; i++) ...<Widget>[
                        _WhatsNewTimelineDot(active: i / 3 <= timeline),
                        if (i != 3)
                          Container(
                            width: 2,
                            height: 22,
                            color: const Color(0x334A8CFF),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WhatsNewTabPill extends StatelessWidget {
  final String label;
  final bool active;

  const _WhatsNewTabPill({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0x224A8CFF) : const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0x554A8CFF) : const Color(0x18FFFFFF),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? const Color(0xFF91BAFF) : const Color(0xFF8D98AA),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _WhatsNewMiniLine extends StatelessWidget {
  final double width;

  const _WhatsNewMiniLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF506079),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _WhatsNewTimelineDot extends StatelessWidget {
  final bool active;

  const _WhatsNewTimelineDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF4A8CFF) : const Color(0xFF334056),
        border: Border.all(
          color: const Color(0xFF7EAFFF),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? const <BoxShadow>[
                BoxShadow(color: Color(0x774A8CFF), blurRadius: 12),
              ]
            : null,
      ),
    );
  }
}
