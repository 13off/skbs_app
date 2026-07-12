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
      duration: const Duration(milliseconds: 2200),
      value: widget.animate ? 0 : 1,
    );

    if (widget.animate) controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PremiumBrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animate == widget.animate) return;

    if (widget.animate) {
      controller.repeat(reverse: true);
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
            return CustomPaint(
              painter: _AppStroyMarkPainter(
                animation: widget.animate ? controller.value : 0.72,
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
                      fontWeight: FontWeight.w900,
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

  @override
  void paint(Canvas canvas, Size size) {
    const viewMin = 56.0;
    const viewSize = 400.0;
    final scale = math.min(size.width, size.height) / viewSize;
    final horizontalInset = (size.width - viewSize * scale) / 2;
    final verticalInset = (size.height - viewSize * scale) / 2;
    final pulse = (math.sin(animation * math.pi * 2) + 1) / 2;

    canvas
      ..save()
      ..translate(horizontalInset, verticalInset)
      ..scale(scale)
      ..translate(-viewMin, -viewMin);

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = (light ? Colors.white : const Color(0xFF7C828A))
          .withValues(alpha: light ? 0.15 : 0.19);
    canvas
      ..drawCircle(const Offset(256, 252), 176, guidePaint)
      ..drawCircle(const Offset(314, 190), 108, guidePaint)
      ..drawCircle(const Offset(358, 286), 68, guidePaint);

    final bounds = const Rect.fromLTWH(90, 86, 340, 324);
    final navyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: light
            ? [
                Colors.white.withValues(alpha: 0.98),
                Colors.white.withValues(alpha: 0.72),
              ]
            : const [Color(0xFF101723), Color(0xFF253247)],
      ).createShader(bounds);
    final bluePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: light
            ? const [Color(0xFFDCEBFF), Color(0xFF93B9E5)]
            : const [Color(0xFF255C9D), Color(0xFF123B70)],
      ).createShader(bounds);
    final goldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE4C98C), Color(0xFFA98545)],
      ).createShader(bounds);

    canvas.drawPath(
      Path()
        ..moveTo(105, 386)
        ..lineTo(245, 92)
        ..lineTo(274, 92)
        ..lineTo(187, 386)
        ..close(),
      navyPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(205, 386)
        ..lineTo(205, 244)
        ..lineTo(253, 205)
        ..lineTo(253, 386)
        ..close(),
      bluePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(268, 386)
        ..lineTo(268, 137)
        ..lineTo(318, 174)
        ..lineTo(318, 386)
        ..close(),
      navyPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(323, 386)
        ..lineTo(323, 252)
        ..lineTo(361, 281)
        ..lineTo(361, 386)
        ..close(),
      bluePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(352, 386)
        ..cubicTo(402, 350, 405, 286, 357, 245)
        ..lineTo(383, 226)
        ..cubicTo(450, 281, 442, 367, 390, 402)
        ..lineTo(352, 402)
        ..close(),
      bluePaint,
    );

    final curvePaint = Paint()
      ..shader = bluePaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(151, 327)
        ..cubicTo(123, 253, 154, 171, 224, 135),
      curvePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(237, 226)
        ..lineTo(267, 195)
        ..lineTo(267, 229)
        ..lineTo(245, 248)
        ..close(),
      goldPaint,
    );

    final glowPaint = Paint()
      ..shader = goldPaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + pulse * 2);
    canvas.drawLine(const Offset(91, 404), const Offset(421, 404), glowPaint);

    final basePaint = Paint()
      ..shader = goldPaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(91, 404), const Offset(421, 404), basePaint)
      ..restore();
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
