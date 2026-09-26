part of 'role_aware_whats_new_gate.dart';

class _TaskMediaScene extends StatelessWidget {
  final double phase;

  const _TaskMediaScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final lift = math.sin(phase * math.pi * 2) * 4;
    final reveal = _whatsNewStagger(phase, 0.08, 0.72);
    final uploadProgress = _whatsNewStagger(phase, 0.34, 0.92);

    Widget mediaTile({
      required IconData icon,
      required String label,
      required double offset,
    }) {
      return Transform.translate(
        offset: Offset(0, offset),
        child: Container(
          width: 88,
          height: 102,
          padding: const EdgeInsets.all(11),
          decoration: _whatsNewGlassDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF365985), Color(0xFF17283F)],
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFB8D3FF),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC6D5EC),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: SizedBox(
              width: 306,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Opacity(
                    opacity: reveal,
                    child: mediaTile(
                      icon: Icons.photo_rounded,
                      label: 'Фото 1',
                      offset: lift,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Opacity(
                    opacity: reveal,
                    child: mediaTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Фото 2',
                      offset: -lift,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Opacity(
                    opacity: uploadProgress,
                    child: mediaTile(
                      icon: Icons.play_circle_fill_rounded,
                      label: 'Видео · 0:42',
                      offset: lift * 0.6,
                    ),
                  ),
                ],
              ),
            ),
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
                    Icons.cloud_done_rounded,
                    color: Color(0xFF75A9FF),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '3 файла выбраны за один раз',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${(uploadProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFF8DB8FF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: uploadProgress,
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

class _DecimalMoneyScene extends StatelessWidget {
  final double phase;

  const _DecimalMoneyScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final swap = _whatsNewStagger(phase, 0.14, 0.62);
    final verified = _whatsNewStagger(phase, 0.55, 0.86);
    final showDot = swap > 0.48;

    return Center(
      child: SizedBox(
        width: 310,
        height: 190,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
              decoration: _whatsNewGlassDecoration(radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Сумма, ₽',
                    style: TextStyle(
                      color: Color(0xFF8FA2BE),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Text(
                      showDot ? '12 500.50' : '12 500,50',
                      key: ValueKey<bool>(showDot),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DecimalOptionBadge(
                    label: '12 500,50',
                    active: !showDot,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DecimalOptionBadge(
                    label: '12 500.50',
                    active: showDot,
                  ),
                ),
                const SizedBox(width: 10),
                Transform.scale(
                  scale: 0.88 + verified * 0.12,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF244F8D).withValues(
                        alpha: 0.45 + verified * 0.55,
                      ),
                      border: Border.all(
                        color: const Color(0xFF75A9FF),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x444A8CFF), blurRadius: 18),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecimalOptionBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _DecimalOptionBadge({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active ? const Color(0x334A8CFF) : const Color(0x12FFFFFF),
        border: Border.all(
          color: active ? const Color(0x884A8CFF) : const Color(0x22FFFFFF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF8592A8),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AdvanceThirtyScene extends StatelessWidget {
  final double phase;

  const _AdvanceThirtyScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final enabled = _whatsNewStagger(phase, 0.18, 0.45) > 0.52;
    final amountProgress = enabled
        ? _whatsNewStagger(phase, 0.40, 0.78)
        : 0.0;
    final amount = 100000 - (70000 * amountProgress);

    return Center(
      child: SizedBox(
        width: 310,
        height: 194,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: enabled
                        ? const Color(0xFF2C6DD2)
                        : const Color(0x18FFFFFF),
                    border: Border.all(
                      color: enabled
                          ? const Color(0xFF75A9FF)
                          : const Color(0x28FFFFFF),
                    ),
                    boxShadow: enabled
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x554A8CFF),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.percent_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        enabled ? '30% аванс включён' : '30% аванс',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'ОПЛАТА',
                  style: TextStyle(
                    color: Color(0xFF7E8DA5),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: _whatsNewGlassDecoration(radius: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      enabled ? 'Аванс 30% к выплате' : 'Всего к выплате',
                      style: const TextStyle(
                        color: Color(0xFF93A1B6),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_whatsNewMoney(amount)} ₽',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        _AdvanceMiniAmount(
                          name: 'Иванов',
                          amount: enabled ? '15 000' : '50 000',
                        ),
                        const SizedBox(width: 8),
                        _AdvanceMiniAmount(
                          name: 'Петров',
                          amount: enabled ? '15 000' : '50 000',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvanceMiniAmount extends StatelessWidget {
  final String name;
  final String amount;

  const _AdvanceMiniAmount({
    required this.name,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0x12FFFFFF),
          border: Border.all(color: const Color(0x20FFFFFF)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9BA9BD),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$amount ₽',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSplitScene extends StatelessWidget {
  final double phase;

  const _PaymentSplitScene({required this.phase});

  @override
  Widget build(BuildContext context) {
    final warning = _whatsNewStagger(phase, 0.05, 0.30);
    final split = _whatsNewStagger(phase, 0.28, 0.70);
    final receipt = _whatsNewStagger(phase, 0.62, 0.92);

    final augustAmount = 100000 - (5000 * split);
    final septemberAmount = 5000 * split;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                decoration: _whatsNewGlassDecoration(radius: 18),
                child: Row(
                  children: <Widget>[
                    Transform.scale(
                      scale: 0.86 + warning * 0.14,
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFFC66D),
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Переплата за август',
                            style: TextStyle(
                              color: Color(0xFFAAB7CA),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_whatsNewMoney(5000 * warning)} ₽',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFC66D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x55FFC66D)),
                      ),
                      child: const Text(
                        'ПЕРЕНЕСТИ',
                        style: TextStyle(
                          color: Color(0xFFFFD795),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SplitPeriodCard(
                      title: 'Август 2026',
                      subtitle: 'Было к выплате 95 000 ₽',
                      amount: '${_whatsNewMoney(augustAmount)} ₽',
                      highlighted: split > 0.55,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SplitPeriodCard(
                      title: 'Сентябрь 2026',
                      subtitle: 'Осталось выплатить 27 350 ₽',
                      amount: '${_whatsNewMoney(septemberAmount)} ₽',
                      highlighted: split > 0.55,
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(
                      -0.55 + split * 1.10,
                      -0.10,
                    ),
                    child: Transform.scale(
                      scale: 0.82 + split * 0.18,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2F73DB),
                          border: Border.all(
                            color: const Color(0xFF8EBBFF),
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x664A8CFF),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: receipt,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: _whatsNewGlassDecoration(radius: 16),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF75A9FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Один чек для обеих частей выплаты',
                    style: TextStyle(
                      color: Color(0xFFD4DCE8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.link_rounded,
                  color: Color.lerp(
                    const Color(0xFF61718A),
                    const Color(0xFF75A9FF),
                    receipt,
                  ),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SplitPeriodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final bool highlighted;

  const _SplitPeriodCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        color: highlighted
            ? const Color(0x264A8CFF)
            : const Color(0x13FFFFFF),
        border: Border.all(
          color: highlighted
              ? const Color(0x774A8CFF)
              : const Color(0x22FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8F9DB2),
              fontSize: 8.8,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFFCFE0FF),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _whatsNewMoney(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    if (index > 0 && (rounded.length - index) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(rounded[index]);
  }
  return buffer.toString();
}
