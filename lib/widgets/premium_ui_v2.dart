import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';

class PremiumPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double pressedScale;
  final bool enableHaptics;

  const PremiumPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.pressedScale = 0.972,
    this.enableHaptics = true,
  });

  @override
  State<PremiumPressable> createState() => _PremiumPressableState();
}

class _PremiumPressableState extends State<PremiumPressable> {
  bool isPressed = false;
  bool isHovered = false;

  bool get isEnabled => widget.onTap != null;

  void updatePressed(bool value) {
    if (!mounted || isPressed == value) return;
    setState(() => isPressed = value);
  }

  void handleTapDown(TapDownDetails details) {
    if (!isEnabled) return;
    updatePressed(true);

    if (widget.enableHaptics &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = isPressed
        ? widget.pressedScale
        : isHovered && isEnabled
        ? 1.003
        : 1.0;

    final hoverShadow = isHovered && isEnabled && !isPressed
        ? <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF17191C).withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ]
        : const <BoxShadow>[];

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) setState(() => isHovered = true);
      },
      onExit: (_) {
        if (!mounted) return;
        setState(() {
          isHovered = false;
          isPressed = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? handleTapDown : null,
        onTapCancel: isEnabled ? () => updatePressed(false) : null,
        onTapUp: isEnabled ? (_) => updatePressed(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: isPressed ? AppMotion.pressIn : AppMotion.pressOut,
          curve: isPressed ? Curves.easeOut : AppMotion.springCurve,
          child: AnimatedContainer(
            duration: AppMotion.regular,
            curve: AppMotion.enterCurve,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: hoverShadow,
            ),
            child: AnimatedOpacity(
              opacity: isEnabled ? (isPressed ? 0.94 : 1) : 0.46,
              duration: AppMotion.fast,
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PremiumActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumPressable(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(20),
      pressedScale: 0.982,
      child: Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2D31), Color(0xFF17191C)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF15171A).withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.regular,
          switchInCurve: AppMotion.enterCurve,
          switchOutCurve: AppMotion.exitCurve,
          child: isLoading
              ? const Center(
                  key: ValueKey('loading'),
                  child: PremiumDots(color: Colors.white),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F8F5), Color(0xFFECEAE4)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -110,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PremiumBrandMark extends StatefulWidget {
  final double size;
  final bool animate;
  final bool light;

  const PremiumBrandMark({
    super.key,
    this.size = 78,
    this.animate = true,
    this.light = false,
  });

  @override
  State<PremiumBrandMark> createState() => _PremiumBrandMarkState();
}

class _PremiumBrandMarkState extends State<PremiumBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
      value: widget.animate ? 0 : 1,
    );

    if (widget.animate) controller.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumBrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animate == widget.animate) return;

    if (widget.animate) {
      controller.forward(from: 0);
    } else {
      controller.stop();
      controller.value = 1;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.light
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.72);

    return RepaintBoundary(
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: EdgeInsets.all(widget.size * 0.12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(widget.size * 0.28),
          border: Border.all(
            color: widget.light
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.90),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF17191C,
              ).withValues(alpha: widget.light ? 0.26 : 0.15),
              blurRadius: widget.size * 0.42,
              offset: Offset(0, widget.size * 0.20),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final disableAnimations =
                MediaQuery.maybeOf(context)?.disableAnimations ?? false;

            return CustomPaint(
              painter: _AppStroyMarkPainter(
                animation: widget.animate && !disableAnimations
                    ? controller.value
                    : 1,
                light: widget.light,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class PremiumWorkBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumWorkBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF9F6), Color(0xFFECE9E2)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -140,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.94),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PremiumWorkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? tint;

  const PremiumWorkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = 26,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        gradient: tint == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.91),
                  Colors.white.withValues(alpha: 0.72),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.94)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17191C).withValues(alpha: 0.075),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.78),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PremiumLoadingScreen extends StatelessWidget {
  final String message;

  const PremiumLoadingScreen({
    super.key,
    this.message = 'Собираем рабочее пространство',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumBrandMark(size: 92),
                  const SizedBox(height: 28),
                  Text(
                    'AppСтрой',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const PremiumDots(color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumDots extends StatefulWidget {
  final Color color;

  const PremiumDots({super.key, required this.color});

  @override
  State<PremiumDots> createState() => _PremiumDotsState();
}

class _PremiumDotsState extends State<PremiumDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (index) {
            final phase = (controller.value - index * 0.16) % 1.0;
            final wave = (math.sin(phase * math.pi * 2) + 1) / 2;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -2.5 * wave),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.34 + wave * 0.66),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _AppStroyMarkPainter extends CustomPainter {
  final double animation;
  final bool light;

  const _AppStroyMarkPainter({
    required this.animation,
    required this.light,
  });

  static double _staggered(double value, double start, double end) {
    final normalized = ((value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(normalized);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const viewSize = 240.0;
    final scale = math.min(size.width, size.height) / viewSize;
    final horizontalInset = (size.width - viewSize * scale) / 2;
    final verticalInset = (size.height - viewSize * scale) / 2;

    canvas
      ..save()
      ..translate(horizontalInset, verticalInset)
      ..scale(scale);

    final leftTower = Path()
      ..moveTo(38, 204)
      ..lineTo(38, 146)
      ..cubicTo(38, 130, 48, 119, 61, 114)
      ..lineTo(72, 110)
      ..cubicTo(79, 107, 86, 112, 86, 120)
      ..lineTo(86, 204)
      ..close();

    final centerTower = Path()
      ..moveTo(96, 204)
      ..lineTo(96, 82)
      ..cubicTo(96, 61, 109, 45, 128, 39)
      ..lineTo(139, 36)
      ..cubicTo(146, 34, 153, 39, 153, 47)
      ..lineTo(153, 204)
      ..close();

    final rightTower = Path()
      ..moveTo(163, 204)
      ..lineTo(163, 110)
      ..cubicTo(163, 97, 174, 88, 187, 91)
      ..cubicTo(211, 96, 225, 109, 225, 129)
      ..lineTo(225, 204)
      ..close();

    final markBounds = const Rect.fromLTWH(34, 30, 196, 178);
    final metalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.47, 1],
        colors: light
            ? const [
                Color(0xFFFFFFFF),
                Color(0xFFD8DDE1),
                Color(0xFFAEB4BA),
              ]
            : const [
                Color(0xFFD7D7D7),
                Color(0xFFA3A4A6),
                Color(0xFF77797C),
              ],
      ).createShader(markBounds);

    void drawTower(Path path, Rect bounds, double progress) {
      if (progress <= 0) return;

      canvas
        ..save()
        ..clipRect(
          Rect.fromLTRB(
            bounds.left - 3,
            bounds.bottom - (bounds.height + 3) * progress,
            bounds.right + 3,
            bounds.bottom + 3,
          ),
        )
        ..drawPath(path, metalPaint)
        ..restore();
    }

    drawTower(
      leftTower,
      const Rect.fromLTWH(38, 107, 48, 97),
      _staggered(animation, 0.04, 0.48),
    );
    drawTower(
      centerTower,
      const Rect.fromLTWH(96, 34, 57, 170),
      _staggered(animation, 0.16, 0.64),
    );
    drawTower(
      rightTower,
      const Rect.fromLTWH(163, 88, 62, 116),
      _staggered(animation, 0.29, 0.77),
    );

    final shineProgress = _staggered(animation, 0.70, 1);
    if (shineProgress > 0) {
      final markPath = Path()
        ..addPath(leftTower, Offset.zero)
        ..addPath(centerTower, Offset.zero)
        ..addPath(rightTower, Offset.zero);
      final shineX = -58 + 344 * shineProgress;
      final shineOpacity = math
          .sin(shineProgress * math.pi)
          .clamp(0.0, 1.0)
          .toDouble();
      final shinePath = Path()
        ..moveTo(shineX - 34, 214)
        ..lineTo(shineX + 12, 25)
        ..lineTo(shineX + 38, 25)
        ..lineTo(shineX - 8, 214)
        ..close();

      final shinePaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (light ? 0.50 : 0.38) * shineOpacity,
        );

      canvas
        ..save()
        ..clipPath(markPath)
        ..drawPath(shinePath, shinePaint)
        ..restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppStroyMarkPainter oldDelegate) {
    return animation != oldDelegate.animation || light != oldDelegate.light;
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF25282C).withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const step = 34.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
