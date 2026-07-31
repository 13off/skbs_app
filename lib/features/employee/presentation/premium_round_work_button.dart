import 'dart:async';

import 'package:flutter/material.dart';

class PremiumRoundWorkButton extends StatefulWidget {
  final bool active;
  final bool loading;
  final DateTime? startedAt;
  final VoidCallback? onPressed;

  const PremiumRoundWorkButton({
    super.key,
    required this.active,
    required this.loading,
    required this.startedAt,
    required this.onPressed,
  });

  @override
  State<PremiumRoundWorkButton> createState() =>
      _PremiumRoundWorkButtonState();
}

class _PremiumRoundWorkButtonState extends State<PremiumRoundWorkButton>
    with TickerProviderStateMixin {
  late final AnimationController idlePulseController;
  late final AnimationController shazamWaveController;
  Timer? waveStopTimer;
  bool pressed = false;
  bool animationsDisabled = false;

  bool get canPress => widget.onPressed != null;
  bool get canIdlePulse => canPress && !widget.loading && !animationsDisabled;

  String get actionLabel {
    if (widget.loading) {
      return widget.active ? 'Завершаем…' : 'Запускаем…';
    }
    return widget.active ? 'Завершить работу' : 'Начать работу';
  }

  @override
  void initState() {
    super.initState();
    idlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );
    shazamWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (animationsDisabled) {
      stopShazamWaves();
    }
    syncIdlePulse();
  }

  @override
  void didUpdateWidget(covariant PremiumRoundWorkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncIdlePulse();

    if (!oldWidget.loading && widget.loading && !animationsDisabled) {
      startShazamWaves();
    } else if (oldWidget.loading && !widget.loading) {
      scheduleWaveStop();
    }
  }

  void syncIdlePulse() {
    if (canIdlePulse) {
      if (!idlePulseController.isAnimating) {
        idlePulseController.repeat(reverse: true);
      }
      return;
    }

    idlePulseController
      ..stop()
      ..value = 0;
  }

  void startShazamWaves() {
    waveStopTimer?.cancel();
    if (!shazamWaveController.isAnimating) {
      shazamWaveController.repeat(
        period: const Duration(milliseconds: 1450),
      );
    }
  }

  void scheduleWaveStop() {
    waveStopTimer?.cancel();
    waveStopTimer = Timer(const Duration(milliseconds: 1050), () {
      if (!mounted || widget.loading) return;
      stopShazamWaves();
    });
  }

  void stopShazamWaves() {
    waveStopTimer?.cancel();
    shazamWaveController
      ..stop()
      ..value = 0;
  }

  void setPressed(bool value) {
    if (!mounted || pressed == value) return;
    setState(() => pressed = value);
  }

  void triggerTap() {
    setPressed(false);
    if (!animationsDisabled) {
      startShazamWaves();
      scheduleWaveStop();
    }
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    waveStopTimer?.cancel();
    idlePulseController.dispose();
    shazamWaveController.dispose();
    super.dispose();
  }

  String formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  double staggeredWave(double value, double delay) {
    if (value <= delay) return 0;
    return ((value - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final dimension = width < 390 ? 232.0 : 256.0;
    final canvasSize = dimension + 120;
    final actionColor = widget.active
        ? const Color(0xFFFF6848)
        : const Color(0xFF2D9CF0);
    final shellTop = widget.active
        ? const Color(0xFFFFA26B)
        : const Color(0xFF72CDFF);
    final shellBottom = widget.active
        ? const Color(0xFFB92E2F)
        : const Color(0xFF07548F);
    final faceTop = widget.active
        ? const Color(0xFFFF8158)
        : const Color(0xFF43B1F5);
    final faceBottom = widget.active
        ? const Color(0xFFCE3534)
        : const Color(0xFF0B63A8);

    return Semantics(
      button: true,
      enabled: canPress,
      label: actionLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: canvasSize,
            height: canvasSize,
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                idlePulseController,
                shazamWaveController,
              ]),
              builder: (context, _) {
                final idlePulse = canIdlePulse
                    ? Curves.easeInOutCubic.transform(
                        idlePulseController.value,
                      )
                    : 0.0;
                final waveValue = shazamWaveController.value;
                final firstWave = staggeredWave(waveValue, 0);
                final secondWave = staggeredWave(waveValue, 0.22);
                final thirdWave = staggeredWave(waveValue, 0.44);
                final buttonScale = pressed
                    ? 0.955
                    : 1 + (idlePulse * 0.008);

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.scale(
                      scale: 1 + (idlePulse * 0.045),
                      child: Container(
                        width: dimension + 24,
                        height: dimension + 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: actionColor.withValues(
                            alpha: 0.08 + (idlePulse * 0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: actionColor.withValues(
                                alpha: 0.16 + (idlePulse * 0.10),
                              ),
                              blurRadius: 42 + (idlePulse * 18),
                              spreadRadius: 2 + (idlePulse * 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ShazamWaveRing(
                      progress: firstWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.62,
                      expansion: 0.42,
                      strokeWidth: 4.5,
                    ),
                    _ShazamWaveRing(
                      progress: secondWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.46,
                      expansion: 0.48,
                      strokeWidth: 3.4,
                    ),
                    _ShazamWaveRing(
                      progress: thirdWave,
                      dimension: dimension,
                      color: Colors.white,
                      opacity: 0.28,
                      expansion: 0.54,
                      strokeWidth: 2.4,
                    ),
                    AnimatedScale(
                      scale: buttonScale,
                      duration: Duration(milliseconds: pressed ? 70 : 250),
                      curve: pressed
                          ? Curves.easeOutCubic
                          : Curves.easeOutBack,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: canPress ? (_) => setPressed(true) : null,
                        onTapUp: canPress ? (_) => setPressed(false) : null,
                        onTapCancel: canPress ? () => setPressed(false) : null,
                        onTap: canPress ? triggerTap : null,
                        child: SizedBox(
                          width: dimension,
                          height: dimension,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                top: 14,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        shellBottom.withValues(alpha: 0.96),
                                        Color.lerp(
                                              shellBottom,
                                              Colors.black,
                                              dark ? 0.42 : 0.28,
                                            ) ??
                                            shellBottom,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.black.withValues(
                                        alpha: dark ? 0.34 : 0.18,
                                      ),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: dark ? 0.46 : 0.25,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: -6,
                                        offset: const Offset(0, 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSlide(
                                offset: Offset(0, pressed ? 0.035 : -0.018),
                                duration: Duration(
                                  milliseconds: pressed ? 70 : 220,
                                ),
                                curve: pressed
                                    ? Curves.easeOutCubic
                                    : Curves.easeOutBack,
                                child: Container(
                                  width: dimension,
                                  height: dimension,
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [shellTop, shellBottom],
                                      stops: const [0.08, 0.92],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: dark ? 0.34 : 0.82,
                                      ),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: dark ? 0.16 : 0.30,
                                        ),
                                        blurRadius: 16,
                                        spreadRadius: -8,
                                        offset: const Offset(-9, -11),
                                      ),
                                      BoxShadow(
                                        color: actionColor.withValues(
                                          alpha: 0.34 + (idlePulse * 0.10),
                                        ),
                                        blurRadius: 32 + (idlePulse * 10),
                                        spreadRadius: -8,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: const Alignment(-0.65, -0.85),
                                        end: const Alignment(0.65, 0.85),
                                        colors: [faceTop, faceBottom],
                                        stops: const [0.02, 0.98],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.20,
                                        ),
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.22,
                                          ),
                                          blurRadius: 18,
                                          spreadRadius: -10,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              center: const Alignment(
                                                -0.38,
                                                -0.58,
                                              ),
                                              radius: 0.88,
                                              colors: [
                                                Colors.white.withValues(
                                                  alpha: 0.20,
                                                ),
                                                Colors.transparent,
                                              ],
                                              stops: const [0, 0.74],
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Container(
                                            width: dimension * 0.43,
                                            height: dimension * 0.43,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.30,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.10,
                                                  ),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.30,
                                                ),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(
                                                    alpha: 0.22,
                                                  ),
                                                  blurRadius: 22,
                                                  spreadRadius: -8,
                                                  offset: const Offset(0, 12),
                                                ),
                                                BoxShadow(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  blurRadius: 10,
                                                  spreadRadius: -5,
                                                  offset: const Offset(-5, -6),
                                                ),
                                              ],
                                            ),
                                            child: widget.loading
                                                ? const Center(
                                                    child: SizedBox.square(
                                                      dimension: 42,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 4,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : Icon(
                                                    widget.active
                                                        ? Icons.stop_rounded
                                                        : Icons
                                                            .play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: widget.active ? 62 : 70,
                                                    shadows: const [
                                                      Shadow(
                                                        color: Color(0x3D000000),
                                                        blurRadius: 10,
                                                        offset: Offset(0, 5),
                                                      ),
                                                    ],
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
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            child: Text(
              actionLabel,
              key: ValueKey<String>(actionLabel),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
                fontSize: width < 390 ? 20 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
          ),
          if (widget.active && widget.startedAt != null) ...[
            const SizedBox(height: 7),
            Text(
              'Работа идёт с ${formatTime(widget.startedAt!)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShazamWaveRing extends StatelessWidget {
  final double progress;
  final double dimension;
  final Color color;
  final double opacity;
  final double expansion;
  final double strokeWidth;

  const _ShazamWaveRing({
    required this.progress,
    required this.dimension,
    required this.color,
    required this.opacity,
    required this.expansion,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final curved = Curves.easeOutCubic.transform(progress);
    final visibleOpacity = progress <= 0
        ? 0.0
        : (1 - curved) * opacity;

    return IgnorePointer(
      child: Transform.scale(
        scale: 1 + (curved * expansion),
        child: Opacity(
          opacity: visibleOpacity.clamp(0.0, 1.0),
          child: Container(
            width: dimension + 12,
            height: dimension + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: strokeWidth - (curved * (strokeWidth * 0.58)),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: visibleOpacity * 0.72),
                  blurRadius: 16 + (curved * 24),
                  spreadRadius: 1 + (curved * 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
