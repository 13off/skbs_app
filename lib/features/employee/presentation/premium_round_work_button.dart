import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      duration: const Duration(milliseconds: 2240),
    );
    shazamWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1040),
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
        period: const Duration(milliseconds: 1040),
      );
    }
  }

  void scheduleWaveStop() {
    waveStopTimer?.cancel();
    waveStopTimer = Timer(const Duration(milliseconds: 980), () {
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
    unawaited(HapticFeedback.heavyImpact());
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
        ? const Color(0xFFE96B58)
        : const Color(0xFF4AA6D1);
    final palette = widget.active
        ? const _ButtonPalette(
            shellTop: Color(0xFFE98570),
            shellMiddle: Color(0xFFC95042),
            shellBottom: Color(0xFF792B31),
            faceTop: Color(0xFFDC725E),
            faceMiddle: Color(0xFFB7463E),
            faceBottom: Color(0xFF63242B),
            depth: Color(0xFF2D1217),
            emblemTop: Color(0xFFFFE5DC),
            emblemBottom: Color(0xFFF4A994),
          )
        : const _ButtonPalette(
            shellTop: Color(0xFF5A9BBC),
            shellMiddle: Color(0xFF2E7193),
            shellBottom: Color(0xFF183D57),
            faceTop: Color(0xFF4A89A8),
            faceMiddle: Color(0xFF2B6685),
            faceBottom: Color(0xFF16364D),
            depth: Color(0xFF0A1924),
            emblemTop: Color(0xFFEAF7FC),
            emblemBottom: Color(0xFF9BC9DC),
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
                final surge = waveRunning
                    ? math.pow(
                        math.sin(waveValue * math.pi).abs(),
                        0.72,
                      ).toDouble()
                    : 0.0;
                final firstWave = staggeredWave(waveValue, 0);
                final secondWave = staggeredWave(waveValue, 0.16);
                final thirdWave = staggeredWave(waveValue, 0.32);
                final fourthWave = staggeredWave(waveValue, 0.48);
                final fifthWave = staggeredWave(waveValue, 0.64);
                final vibrationStrength = widget.loading
                    ? 3.8
                    : (waveRunning ? 1.35 : 0.0);
                final vibrationOffset = Offset(
                  math.sin(waveValue * math.pi * 14) * vibrationStrength,
                  math.cos(waveValue * math.pi * 19) *
                      vibrationStrength *
                      0.62,
                );
                final buttonScale = pressed
                    ? 0.91
                    : 1 +
                        (idlePulse * 0.018) +
                        (surge * (widget.loading ? 0.058 : 0.030));
                final bodyTilt = widget.loading
                    ? math.sin(waveValue * math.pi * 4) * 0.012
                    : 0.0;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.scale(
                      scale: 1 +
                          (idlePulse * 0.074) +
                          (surge * (waveRunning ? 0.165 : 0)),
                      child: Container(
                        width: dimension + 36,
                        height: dimension + 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              actionColor.withValues(
                                alpha: 0.15 + (surge * 0.12),
                              ),
                              actionColor.withValues(alpha: 0.025),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: actionColor.withValues(
                                alpha: 0.24 +
                                    (idlePulse * 0.14) +
                                    (surge * 0.24),
                              ),
                              blurRadius:
                                  48 + (idlePulse * 24) + (surge * 36),
                              spreadRadius:
                                  2 + (idlePulse * 7) + (surge * 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ShazamWaveRing(
                      progress: firstWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.76,
                      expansion: 0.62,
                      strokeWidth: 6.4,
                      fillOpacity: 0.040,
                    ),
                    _ShazamWaveRing(
                      progress: secondWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.62,
                      expansion: 0.76,
                      strokeWidth: 5.2,
                      fillOpacity: 0.032,
                    ),
                    _ShazamWaveRing(
                      progress: thirdWave,
                      dimension: dimension,
                      color: Colors.white,
                      opacity: 0.40,
                      expansion: 0.90,
                      strokeWidth: 4.0,
                      fillOpacity: 0.022,
                    ),
                    _ShazamWaveRing(
                      progress: fourthWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.31,
                      expansion: 1.04,
                      strokeWidth: 3.0,
                      fillOpacity: 0.018,
                    ),
                    _ShazamWaveRing(
                      progress: fifthWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.20,
                      expansion: 1.18,
                      strokeWidth: 2.2,
                      fillOpacity: 0.012,
                    ),
                    Transform.translate(
                      offset: vibrationOffset,
                      child: Transform.rotate(
                        angle: bodyTilt,
                        child: AnimatedScale(
                          scale: buttonScale,
                          duration:
                              Duration(milliseconds: pressed ? 60 : 220),
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
                              surge: surge,
                              idlePulse: idlePulse,
                              actionColor: actionColor,
                              palette: palette,
                            ),
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
  final double surge;
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
    required this.surge,
    required this.idlePulse,
    required this.actionColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final faceOffset = pressed ? 9.0 : -5.0;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.shellBottom,
                    palette.depth,
                    Color.lerp(palette.depth, Colors.black, 0.42) ??
                        palette.depth,
                  ],
                  stops: const [0, 0.62, 1],
                ),
                border: Border.all(
                  color: Colors.black.withValues(
                    alpha: dark ? 0.56 : 0.34,
                  ),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: dark ? 0.62 : 0.39,
                    ),
                    blurRadius: 38,
                    spreadRadius: -2,
                    offset: const Offset(0, 32),
                  ),
                  BoxShadow(
                    color: actionColor.withValues(
                      alpha: 0.18 + (surge * 0.16),
                    ),
                    blurRadius: 36 + (surge * 24),
                    spreadRadius: -6,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSlide(
            offset: Offset(0, faceOffset / dimension),
            duration: Duration(milliseconds: pressed ? 60 : 205),
            curve: pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: Container(
              width: dimension,
              height: dimension,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: const Alignment(-0.68, -0.92),
                  end: const Alignment(0.72, 0.94),
                  colors: [
                    palette.shellTop,
                    palette.shellMiddle,
                    palette.shellBottom,
                  ],
                  stops: const [0.02, 0.50, 1],
                ),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: dark ? 0.16 : 0.23,
                  ),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 8,
                    spreadRadius: -4,
                    offset: const Offset(-4, -5),
                  ),
                  BoxShadow(
                    color: actionColor.withValues(
                      alpha: 0.30 +
                          (idlePulse * 0.10) +
                          (surge * 0.22),
                    ),
                    blurRadius: 40 + (surge * 28),
                    spreadRadius: -7,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: const Alignment(-0.60, -0.84),
                    end: const Alignment(0.66, 0.88),
                    colors: [
                      palette.faceTop,
                      palette.faceMiddle,
                      palette.faceBottom,
                    ],
                    stops: const [0, 0.56, 1],
                  ),
                  border: Border.all(
                    color: Colors.black.withValues(
                      alpha: dark ? 0.18 : 0.12,
                    ),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 24,
                      spreadRadius: -8,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: -7,
                      offset: const Offset(-6, -7),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _MatteTexturePainter(
                          dark: dark,
                          active: active,
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.36, -0.52),
                            radius: 1.04,
                            colors: [
                              Colors.white.withValues(
                                alpha: 0.07 + (surge * 0.05),
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.74],
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
                                  alpha: waveRunning
                                      ? 0.10 + (surge * 0.08)
                                      : 0.025,
                                ),
                                Colors.transparent,
                                Colors.transparent,
                              ],
                              stops: const [0, 0.10, 0.23, 1],
                            ),
                          ),
                        ),
                      ),
                      if (waveRunning)
                        Positioned(
                          left: -dimension * 0.54 +
                              (waveValue * dimension * 1.82),
                          top: -dimension * 0.22,
                          bottom: -dimension * 0.22,
                          child: Transform.rotate(
                            angle: -0.34,
                            child: Container(
                              width: dimension * 0.24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(
                                      alpha: 0.10 + (surge * 0.14),
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: Transform.rotate(
                          angle: loading
                              ? math.sin(waveValue * math.pi * 2) * 0.055
                              : 0,
                          child: Transform.scale(
                            scale:
                                1 + (surge * (loading ? 0.14 : 0.075)),
                            child: _WorkEmblem(
                              dimension: dimension,
                              active: active,
                              loading: loading,
                              energy: energy,
                              surge: surge,
                              actionColor: actionColor,
                              palette: palette,
                            ),
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
  final double surge;
  final Color actionColor;
  final _ButtonPalette palette;

  const _WorkEmblem({
    required this.dimension,
    required this.active,
    required this.loading,
    required this.energy,
    required this.surge,
    required this.actionColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active ? Icons.stop_rounded : Icons.construction_rounded;
    final iconSize = active ? dimension * 0.25 : dimension * 0.30;
    final emblemSize = dimension * 0.49;

    return Container(
      width: emblemSize,
      height: emblemSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: const Alignment(-0.62, -0.80),
          end: const Alignment(0.70, 0.88),
          colors: [
            Color.lerp(actionColor, Colors.white, 0.14) ?? actionColor,
            Color.lerp(actionColor, Colors.black, 0.20) ?? actionColor,
            Color.lerp(actionColor, Colors.black, 0.48) ?? actionColor,
          ],
          stops: const [0, 0.54, 1],
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.14 + (surge * 0.10),
          ),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.44),
            blurRadius: 28,
            spreadRadius: -5,
            offset: const Offset(0, 17),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -6,
            offset: const Offset(-5, -6),
          ),
          BoxShadow(
            color: actionColor.withValues(
              alpha: 0.24 + (surge * 0.24),
            ),
            blurRadius: 28 + (surge * 22),
            spreadRadius: -4,
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
              color: Colors.black.withValues(alpha: 0.52),
            ),
          ),
          Transform.translate(
            offset: const Offset(-1.2, -2.6),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.emblemTop,
                  palette.emblemBottom,
                  Colors.white.withValues(alpha: 0.66),
                ],
                stops: const [0, 0.68, 1],
              ).createShader(bounds),
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            top: emblemSize * 0.16,
            left: emblemSize * 0.27,
            right: emblemSize * 0.27,
            child: Container(
              height: emblemSize * 0.025,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(
                  alpha: 0.12 + (energy * 0.08),
                ),
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
  final double fillOpacity;

  const _ShazamWaveRing({
    required this.progress,
    required this.dimension,
    required this.color,
    required this.opacity,
    required this.expansion,
    required this.strokeWidth,
    required this.fillOpacity,
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
              color: color.withValues(
                alpha: visibleOpacity * fillOpacity,
              ),
              border: Border.all(
                color: color,
                width:
                    strokeWidth - (curved * (strokeWidth * 0.66)),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(
                    alpha: visibleOpacity * 0.82,
                  ),
                  blurRadius: 22 + (curved * 38),
                  spreadRadius: 2 + (curved * 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatteTexturePainter extends CustomPainter {
  final bool dark;
  final bool active;

  const _MatteTexturePainter({
    required this.dark,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = Colors.white.withValues(alpha: dark ? 0.030 : 0.038);
    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: active ? 0.030 : 0.026);

    for (var index = 0; index < 116; index++) {
      final x = ((index * 47) % 113) / 112 * size.width;
      final y = ((index * 71) % 127) / 126 * size.height;
      final radius = 0.45 + ((index % 5) * 0.11);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        index.isEven ? lightPaint : darkPaint,
      );
    }

    final hazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.035),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.025),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, hazePaint);
  }

  @override
  bool shouldRepaint(covariant _MatteTexturePainter oldDelegate) {
    return dark != oldDelegate.dark || active != oldDelegate.active;
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
