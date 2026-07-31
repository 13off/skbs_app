import 'dart:async';
import 'dart:math' as math;

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
      duration: const Duration(milliseconds: 2050),
    );
    shazamWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
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
        period: const Duration(milliseconds: 1180),
      );
    }
  }

  void scheduleWaveStop() {
    waveStopTimer?.cancel();
    waveStopTimer = Timer(const Duration(milliseconds: 920), () {
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
    final dimension = width < 390 ? 244.0 : 272.0;
    final canvasSize = width < 390 ? 370.0 : 404.0;
    final actionColor = widget.active
        ? const Color(0xFFFF6E52)
        : const Color(0xFF25A8F5);
    final palette = widget.active
        ? const _ButtonPalette(
            shellTop: Color(0xFFFFC39A),
            shellMiddle: Color(0xFFF06448),
            shellBottom: Color(0xFF8A2227),
            faceTop: Color(0xFFFF936B),
            faceMiddle: Color(0xFFD9483A),
            faceBottom: Color(0xFF741C25),
            depth: Color(0xFF4A1119),
            emblemTop: Color(0xFFFFF4E8),
            emblemBottom: Color(0xFFFFC3AD),
          )
        : const _ButtonPalette(
            shellTop: Color(0xFFB9E9FF),
            shellMiddle: Color(0xFF319EDC),
            shellBottom: Color(0xFF064D84),
            faceTop: Color(0xFF5BC2EF),
            faceMiddle: Color(0xFF147FBD),
            faceBottom: Color(0xFF063F6C),
            depth: Color(0xFF032A4B),
            emblemTop: Color(0xFFFFFFFF),
            emblemBottom: Color(0xFFA9E3FF),
          );

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
                final waveRunning = shazamWaveController.isAnimating;
                final energy = waveRunning
                    ? (math.sin(waveValue * math.pi * 2) + 1) / 2
                    : 0.0;
                final firstWave = staggeredWave(waveValue, 0);
                final secondWave = staggeredWave(waveValue, 0.16);
                final thirdWave = staggeredWave(waveValue, 0.32);
                final fourthWave = staggeredWave(waveValue, 0.48);
                final vibrationStrength = widget.loading
                    ? 2.6
                    : (waveRunning ? 0.9 : 0.0);
                final vibrationOffset = Offset(
                  math.sin(waveValue * math.pi * 14) * vibrationStrength,
                  math.cos(waveValue * math.pi * 18) *
                      vibrationStrength *
                      0.55,
                );
                final buttonScale = pressed
                    ? 0.925
                    : 1 +
                        (idlePulse * 0.020) +
                        (energy * (widget.loading ? 0.038 : 0.014));

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.scale(
                      scale: 1 +
                          (idlePulse * 0.085) +
                          (energy * (waveRunning ? 0.105 : 0)),
                      child: Container(
                        width: dimension + 34,
                        height: dimension + 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              actionColor.withValues(
                                alpha: 0.18 + (energy * 0.10),
                              ),
                              actionColor.withValues(alpha: 0.035),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: actionColor.withValues(
                                alpha: 0.28 +
                                    (idlePulse * 0.16) +
                                    (energy * 0.18),
                              ),
                              blurRadius:
                                  52 + (idlePulse * 26) + (energy * 24),
                              spreadRadius:
                                  4 + (idlePulse * 7) + (energy * 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ShazamWaveRing(
                      progress: firstWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.82,
                      expansion: 0.54,
                      strokeWidth: 6,
                    ),
                    _ShazamWaveRing(
                      progress: secondWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.68,
                      expansion: 0.66,
                      strokeWidth: 5,
                    ),
                    _ShazamWaveRing(
                      progress: thirdWave,
                      dimension: dimension,
                      color: Colors.white,
                      opacity: 0.48,
                      expansion: 0.78,
                      strokeWidth: 3.8,
                    ),
                    _ShazamWaveRing(
                      progress: fourthWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.34,
                      expansion: 0.90,
                      strokeWidth: 2.8,
                    ),
                    Transform.translate(
                      offset: vibrationOffset,
                      child: AnimatedScale(
                        scale: buttonScale,
                        duration:
                            Duration(milliseconds: pressed ? 65 : 230),
                        curve: pressed
                            ? Curves.easeOutCubic
                            : Curves.easeOutBack,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown:
                              canPress ? (_) => setPressed(true) : null,
                          onTapUp:
                              canPress ? (_) => setPressed(false) : null,
                          onTapCancel:
                              canPress ? () => setPressed(false) : null,
                          onTap: canPress ? triggerTap : null,
                          child: _PremiumButtonBody(
                            dimension: dimension,
                            active: widget.active,
                            loading: widget.loading,
                            pressed: pressed,
                            dark: dark,
                            waveRunning: waveRunning,
                            waveValue: waveValue,
                            energy: energy,
                            idlePulse: idlePulse,
                            actionColor: actionColor,
                            palette: palette,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
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

class _PremiumButtonBody extends StatelessWidget {
  final double dimension;
  final bool active;
  final bool loading;
  final bool pressed;
  final bool dark;
  final bool waveRunning;
  final double waveValue;
  final double energy;
  final double idlePulse;
  final Color actionColor;
  final _ButtonPalette palette;

  const _PremiumButtonBody({
    required this.dimension,
    required this.active,
    required this.loading,
    required this.pressed,
    required this.dark,
    required this.waveRunning,
    required this.waveValue,
    required this.energy,
    required this.idlePulse,
    required this.actionColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final faceOffset = pressed ? 7.0 : -4.0;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.shellBottom,
                    palette.depth,
                    Color.lerp(palette.depth, Colors.black, 0.35) ??
                        palette.depth,
                  ],
                  stops: const [0, 0.68, 1],
                ),
                border: Border.all(
                  color: Colors.black.withValues(
                    alpha: dark ? 0.56 : 0.30,
                  ),
                  width: 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: dark ? 0.58 : 0.34,
                    ),
                    blurRadius: 34,
                    spreadRadius: -4,
                    offset: const Offset(0, 29),
                  ),
                  BoxShadow(
                    color: actionColor.withValues(alpha: 0.28),
                    blurRadius: 32 + (energy * 18),
                    spreadRadius: -8,
                    offset: const Offset(0, 17),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSlide(
            offset: Offset(0, faceOffset / dimension),
            duration: Duration(milliseconds: pressed ? 65 : 210),
            curve: pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: Container(
              width: dimension,
              height: dimension,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: const Alignment(-0.72, -0.90),
                  end: const Alignment(0.72, 0.92),
                  colors: [
                    palette.shellTop,
                    palette.shellMiddle,
                    palette.shellBottom,
                  ],
                  stops: const [0.02, 0.46, 1],
                ),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: dark ? 0.38 : 0.88,
                  ),
                  width: 2.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: dark ? 0.18 : 0.42,
                    ),
                    blurRadius: 18,
                    spreadRadius: -8,
                    offset: const Offset(-10, -12),
                  ),
                  BoxShadow(
                    color: actionColor.withValues(
                      alpha: 0.42 +
                          (idlePulse * 0.12) +
                          (energy * 0.14),
                    ),
                    blurRadius: 38 + (energy * 22),
                    spreadRadius: -8,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: const Alignment(-0.66, -0.88),
                    end: const Alignment(0.70, 0.88),
                    colors: [
                      palette.faceTop,
                      palette.faceMiddle,
                      palette.faceBottom,
                    ],
                    stops: const [0, 0.50, 1],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 20,
                      spreadRadius: -9,
                      offset: const Offset(0, 13),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12),
                      blurRadius: 12,
                      spreadRadius: -7,
                      offset: const Offset(-7, -8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.42, -0.60),
                            radius: 0.92,
                            colors: [
                              Colors.white.withValues(
                                alpha: 0.23 + (energy * 0.10),
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.70],
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: waveValue * math.pi * 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(
                                  alpha: waveRunning ? 0.20 : 0.06,
                                ),
                                Colors.transparent,
                                Colors.transparent,
                              ],
                              stops: const [0, 0.12, 0.26, 1],
                            ),
                          ),
                        ),
                      ),
                      if (waveRunning)
                        Positioned(
                          left: -dimension * 0.42 +
                              (waveValue * dimension * 1.62),
                          top: -dimension * 0.18,
                          bottom: -dimension * 0.18,
                          child: Transform.rotate(
                            angle: -0.36,
                            child: Container(
                              width: dimension * 0.20,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(
                                      alpha: 0.22 + (energy * 0.20),
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: Transform.scale(
                          scale: 1 + (energy * (loading ? 0.095 : 0.045)),
                          child: _WorkEmblem(
                            dimension: dimension,
                            active: active,
                            loading: loading,
                            energy: energy,
                            actionColor: actionColor,
                            palette: palette,
                          ),
                        ),
                      ),
                      Positioned(
                        top: dimension * 0.075,
                        left: dimension * 0.20,
                        right: dimension * 0.20,
                        child: Container(
                          height: dimension * 0.06,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(
                                  alpha: 0.34 + (energy * 0.16),
                                ),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: 0.16 + (energy * 0.10),
                                ),
                                blurRadius: 12,
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
          ),
        ],
      ),
    );
  }
}

class _WorkEmblem extends StatelessWidget {
  final double dimension;
  final bool active;
  final bool loading;
  final double energy;
  final Color actionColor;
  final _ButtonPalette palette;

  const _WorkEmblem({
    required this.dimension,
    required this.active,
    required this.loading,
    required this.energy,
    required this.actionColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active ? Icons.stop_rounded : Icons.construction_rounded;
    final iconSize = active ? dimension * 0.25 : dimension * 0.30;
    final emblemSize = dimension * 0.50;

    return Container(
      width: emblemSize,
      height: emblemSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: const Alignment(-0.72, -0.86),
          end: const Alignment(0.72, 0.90),
          colors: [
            Color.lerp(actionColor, Colors.white, 0.34) ?? actionColor,
            Color.lerp(actionColor, Colors.black, 0.14) ?? actionColor,
            Color.lerp(actionColor, Colors.black, 0.46) ?? actionColor,
          ],
          stops: const [0, 0.46, 1],
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.42 + (energy * 0.16),
          ),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.18),
            blurRadius: 12,
            spreadRadius: -6,
            offset: const Offset(-6, -7),
          ),
          BoxShadow(
            color: actionColor.withValues(
              alpha: 0.34 + (energy * 0.26),
            ),
            blurRadius: 24 + (energy * 18),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, loading ? 8 : 7),
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.black.withValues(alpha: 0.42),
            ),
          ),
          Transform.translate(
            offset: const Offset(-1.5, -2.5),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.emblemTop,
                  palette.emblemBottom,
                  Colors.white.withValues(alpha: 0.82),
                ],
                stops: const [0, 0.62, 1],
              ).createShader(bounds),
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            top: emblemSize * 0.15,
            left: emblemSize * 0.23,
            right: emblemSize * 0.23,
            child: Container(
              height: emblemSize * 0.055,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(
                  alpha: 0.30 + (energy * 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
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
    final visibleOpacity =
        progress <= 0 ? 0.0 : (1 - curved) * opacity;

    return IgnorePointer(
      child: Transform.scale(
        scale: 1 + (curved * expansion),
        child: Opacity(
          opacity: visibleOpacity.clamp(0.0, 1.0),
          child: Container(
            width: dimension + 14,
            height: dimension + 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: visibleOpacity * 0.055),
              border: Border.all(
                color: color,
                width:
                    strokeWidth - (curved * (strokeWidth * 0.62)),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(
                    alpha: visibleOpacity * 0.86,
                  ),
                  blurRadius: 20 + (curved * 32),
                  spreadRadius: 2 + (curved * 6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPalette {
  final Color shellTop;
  final Color shellMiddle;
  final Color shellBottom;
  final Color faceTop;
  final Color faceMiddle;
  final Color faceBottom;
  final Color depth;
  final Color emblemTop;
  final Color emblemBottom;

  const _ButtonPalette({
    required this.shellTop,
    required this.shellMiddle,
    required this.shellBottom,
    required this.faceTop,
    required this.faceMiddle,
    required this.faceBottom,
    required this.depth,
    required this.emblemTop,
    required this.emblemBottom,
  });
}
