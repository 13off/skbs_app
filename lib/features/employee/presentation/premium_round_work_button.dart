import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
      duration: const Duration(milliseconds: 4200),
    );
    shazamWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
        period: const Duration(milliseconds: 2400),
      );
    }
  }

  void scheduleWaveStop() {
    waveStopTimer?.cancel();
    waveStopTimer = Timer(const Duration(milliseconds: 2200), () {
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
    unawaited(HapticFeedback.mediumImpact());
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
        ? const Color(0xFFE97967)
        : const Color(0xFF5CB4DD);
    final palette = widget.active
        ? const _ButtonPalette(
            shellTop: Color(0xB8F29A88),
            shellMiddle: Color(0xB8C65B4E),
            shellBottom: Color(0xD17C3137),
            faceTop: Color(0xA8F6B0A2),
            faceMiddle: Color(0xA8C96055),
            faceBottom: Color(0xC46D2C33),
            depth: Color(0xFF2D1519),
            emblemTop: Color(0xFFFDE8E2),
            emblemBottom: Color(0xFFECA99B),
          )
        : const _ButtonPalette(
            shellTop: Color(0xA890CBE4),
            shellMiddle: Color(0xB85A94B0),
            shellBottom: Color(0xD1265870),
            faceTop: Color(0x998CC7DF),
            faceMiddle: Color(0xA84F8CA7),
            faceBottom: Color(0xC323536A),
            depth: Color(0xFF0B1C25),
            emblemTop: Color(0xFFF4FBFE),
            emblemBottom: Color(0xFFB5DDEB),
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
                    ? Curves.easeInOutSine.transform(
                        idlePulseController.value,
                      )
                    : 0.0;
                final waveValue = shazamWaveController.value;
                final waveRunning = shazamWaveController.isAnimating;
                final energy = waveRunning
                    ? (1 - math.cos(waveValue * math.pi * 2)) / 2
                    : 0.0;
                final surge = waveRunning
                    ? math.pow(math.sin(waveValue * math.pi), 2).toDouble()
                    : 0.0;
                final firstWave = staggeredWave(waveValue, 0);
                final secondWave = staggeredWave(waveValue, 0.14);
                final thirdWave = staggeredWave(waveValue, 0.28);
                final fourthWave = staggeredWave(waveValue, 0.42);
                final fifthWave = staggeredWave(waveValue, 0.56);
                final vibrationStrength = widget.loading
                    ? 0.72
                    : (waveRunning ? 0.20 : 0.0);
                final vibrationOffset = Offset(
                  math.sin(waveValue * math.pi * 4) * vibrationStrength,
                  math.sin(waveValue * math.pi * 3) *
                      vibrationStrength *
                      0.45,
                );
                final buttonScale = pressed
                    ? 0.955
                    : 1 +
                        (idlePulse * 0.012) +
                        (surge * (widget.loading ? 0.024 : 0.010));

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.scale(
                      scale: 1 +
                          (idlePulse * 0.050) +
                          (surge * (waveRunning ? 0.075 : 0)),
                      child: Container(
                        width: dimension + 38,
                        height: dimension + 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              actionColor.withValues(
                                alpha: 0.12 + (surge * 0.07),
                              ),
                              actionColor.withValues(alpha: 0.015),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: actionColor.withValues(
                                alpha: 0.18 +
                                    (idlePulse * 0.10) +
                                    (surge * 0.12),
                              ),
                              blurRadius:
                                  58 + (idlePulse * 24) + (surge * 24),
                              spreadRadius:
                                  1 + (idlePulse * 5) + (surge * 4),
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
                      expansion: 0.58,
                      strokeWidth: 5.0,
                      fillOpacity: 0.032,
                    ),
                    _ShazamWaveRing(
                      progress: secondWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.50,
                      expansion: 0.72,
                      strokeWidth: 4.2,
                      fillOpacity: 0.025,
                    ),
                    _ShazamWaveRing(
                      progress: thirdWave,
                      dimension: dimension,
                      color: Colors.white,
                      opacity: 0.30,
                      expansion: 0.86,
                      strokeWidth: 3.2,
                      fillOpacity: 0.016,
                    ),
                    _ShazamWaveRing(
                      progress: fourthWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.24,
                      expansion: 1.00,
                      strokeWidth: 2.5,
                      fillOpacity: 0.012,
                    ),
                    _ShazamWaveRing(
                      progress: fifthWave,
                      dimension: dimension,
                      color: actionColor,
                      opacity: 0.16,
                      expansion: 1.14,
                      strokeWidth: 1.9,
                      fillOpacity: 0.008,
                    ),
                    Transform.translate(
                      offset: vibrationOffset,
                      child: AnimatedScale(
                        scale: buttonScale,
                        duration:
                            Duration(milliseconds: pressed ? 140 : 520),
                        curve: Curves.easeInOutCubic,
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
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
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
    final faceOffset = pressed ? 4.5 : -2.0;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.shellBottom,
                    palette.depth,
                    Color.lerp(palette.depth, Colors.black, 0.36) ??
                        palette.depth,
                  ],
                  stops: const [0, 0.66, 1],
                ),
                border: Border.all(
                  color: Colors.black.withValues(
                    alpha: dark ? 0.46 : 0.28,
                  ),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: dark ? 0.54 : 0.34,
                    ),
                    blurRadius: 42,
                    spreadRadius: -3,
                    offset: const Offset(0, 30),
                  ),
                  BoxShadow(
                    color: actionColor.withValues(
                      alpha: 0.14 + (surge * 0.10),
                    ),
                    blurRadius: 44 + (surge * 18),
                    spreadRadius: -8,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSlide(
            offset: Offset(0, faceOffset / dimension),
            duration: Duration(milliseconds: pressed ? 140 : 520),
            curve: Curves.easeInOutCubic,
            child: Container(
              width: dimension,
              height: dimension,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: const Alignment(-0.72, -0.92),
                  end: const Alignment(0.74, 0.94),
                  colors: [
                    palette.shellTop,
                    palette.shellMiddle,
                    palette.shellBottom,
                  ],
                  stops: const [0.02, 0.52, 1],
                ),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: dark ? 0.24 : 0.32,
                  ),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: dark ? 0.08 : 0.14,
                    ),
                    blurRadius: 20,
                    spreadRadius: -10,
                    offset: const Offset(-7, -9),
                  ),
                  BoxShadow(
                    color: actionColor.withValues(
                      alpha: 0.22 +
                          (idlePulse * 0.08) +
                          (surge * 0.12),
                    ),
                    blurRadius: 46 + (surge * 20),
                    spreadRadius: -9,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: const Alignment(-0.62, -0.86),
                        end: const Alignment(0.68, 0.90),
                        colors: [
                          palette.faceTop,
                          palette.faceMiddle,
                          palette.faceBottom,
                        ],
                        stops: const [0, 0.58, 1],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: dark ? 0.16 : 0.22,
                        ),
                        width: 1.2,
                      ),
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
                                center: const Alignment(-0.40, -0.55),
                                radius: 1.06,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: 0.12 + (surge * 0.04),
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.76],
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
                                          ? 0.075 + (surge * 0.045)
                                          : 0.018,
                                    ),
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.11, 0.28, 1],
                                ),
                              ),
                            ),
                          ),
                          if (waveRunning)
                            Positioned(
                              left: -dimension * 0.60 +
                                  (waveValue * dimension * 1.90),
                              top: -dimension * 0.24,
                              bottom: -dimension * 0.24,
                              child: Transform.rotate(
                                angle: -0.30,
                                child: Container(
                                  width: dimension * 0.28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(
                                          alpha: 0.07 + (surge * 0.06),
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
                              scale: 1 +
                                  (surge * (loading ? 0.060 : 0.025)),
                              child: _WorkEmblem(
                                dimension: dimension,
                                active: active,
                                energy: energy,
                                surge: surge,
                                actionColor: actionColor,
                                palette: palette,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
  final double energy;
  final double surge;
  final Color actionColor;
  final _ButtonPalette palette;

  const _WorkEmblem({
    required this.dimension,
    required this.active,
    required this.energy,
    required this.surge,
    required this.actionColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active ? Icons.stop_rounded : Icons.construction_rounded;
    final iconSize = active ? dimension * 0.24 : dimension * 0.29;
    final emblemSize = dimension * 0.48;

    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: emblemSize,
          height: emblemSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: const Alignment(-0.66, -0.82),
              end: const Alignment(0.72, 0.88),
              colors: [
                actionColor.withValues(alpha: 0.62),
                (Color.lerp(actionColor, Colors.black, 0.18) ?? actionColor)
                    .withValues(alpha: 0.72),
                (Color.lerp(actionColor, Colors.black, 0.42) ?? actionColor)
                    .withValues(alpha: 0.86),
              ],
              stops: const [0, 0.56, 1],
            ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.20 + (surge * 0.08),
              ),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 30,
                spreadRadius: -7,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: actionColor.withValues(
                  alpha: 0.18 + (surge * 0.14),
                ),
                blurRadius: 30 + (surge * 16),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, 6),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: Colors.black.withValues(alpha: 0.42),
                ),
              ),
              Transform.translate(
                offset: const Offset(-1, -2),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.emblemTop,
                      palette.emblemBottom,
                      Colors.white.withValues(alpha: 0.74),
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
                left: emblemSize * 0.28,
                right: emblemSize * 0.28,
                child: Container(
                  height: emblemSize * 0.020,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(
                      alpha: 0.14 + (energy * 0.05),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final curved = Curves.easeInOutSine.transform(progress);
    final fade = math.pow(1 - curved, 1.18).toDouble();
    final visibleOpacity = progress <= 0 ? 0.0 : fade * opacity;

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
                width: strokeWidth - (curved * (strokeWidth * 0.72)),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(
                    alpha: visibleOpacity * 0.66,
                  ),
                  blurRadius: 28 + (curved * 42),
                  spreadRadius: 1 + (curved * 6),
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
      ..color = Colors.white.withValues(alpha: dark ? 0.018 : 0.024);
    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: active ? 0.018 : 0.014);

    for (var index = 0; index < 96; index++) {
      final x = ((index * 47) % 113) / 112 * size.width;
      final y = ((index * 71) % 127) / 126 * size.height;
      final radius = 0.35 + ((index % 5) * 0.08);
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
          Colors.white.withValues(alpha: 0.028),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.018),
        ],
        stops: const [0, 0.52, 1],
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
