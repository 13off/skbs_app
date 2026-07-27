import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_ui_tokens.dart';
import 'app_page.dart';
import 'liquid_glass.dart';
import 'premium_ui_v2.dart' show PremiumBrandMark;

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceBackdrop(child: child);
  }
}

class AppConstructionLoader extends StatefulWidget {
  final double width;
  final double height;
  final Color? color;

  const AppConstructionLoader({
    super.key,
    this.width = 112,
    this.height = 70,
    this.color,
  });

  @override
  State<AppConstructionLoader> createState() => _AppConstructionLoaderState();
}

class _AppConstructionLoaderState extends State<AppConstructionLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled == animationsDisabled) return;
    animationsDisabled = disabled;
    if (disabled) {
      controller.stop();
      controller.value = 0.56;
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = widget.color ?? theme.colorScheme.primary;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ConstructionLoaderPainter(
                progress: controller.value,
                color: resolvedColor,
                dark: theme.brightness == Brightness.dark,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConstructionLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool dark;

  const _ConstructionLoaderPainter({
    required this.progress,
    required this.color,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 8;
    final left = size.width * 0.18;
    final right = size.width * 0.82;
    final beamWidth = math.max(5.0, size.width * 0.07);
    final structureColor = color.withValues(alpha: dark ? 0.23 : 0.16);
    final activeColor = color.withValues(alpha: dark ? 0.88 : 0.78);
    final linePaint = Paint()
      ..color = structureColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final basePaint = Paint()
      ..color = structureColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left - 8, baseY), Offset(right + 8, baseY), basePaint);

    final xs = <double>[left, size.width * 0.5, right];
    final heightFactors = <double>[0.58, 0.88, 0.69];
    final tops = <Offset>[];

    for (var index = 0; index < xs.length; index++) {
      final wave = math.sin((progress * math.pi * 2) - index * 0.72);
      final height = size.height * heightFactors[index] + wave * 2.2;
      final top = baseY - height;
      tops.add(Offset(xs[index], top));

      final frameRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xs[index] - beamWidth / 2, top, beamWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(frameRect, Paint()..color = structureColor);

      final pulse = 0.56 + 0.44 * math.sin(
        (progress * math.pi * 2) - index * 0.9,
      ).abs();
      final fillHeight = height * pulse;
      final activeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          xs[index] - beamWidth / 2,
          baseY - fillHeight,
          beamWidth,
          fillHeight,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        activeRect,
        Paint()..color = activeColor.withValues(alpha: 0.42 + 0.36 * pulse),
      );
    }

    canvas.drawLine(tops[0], tops[1], linePaint);
    canvas.drawLine(tops[1], tops[2], linePaint);
    canvas.drawLine(Offset(xs[0], baseY), tops[1], linePaint);
    canvas.drawLine(tops[1], Offset(xs[2], baseY), linePaint);

    final scanX = -24 + (size.width + 48) * Curves.easeInOut.transform(progress);
    final scanRect = Rect.fromLTWH(scanX - 20, 0, 40, size.height);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: dark ? 0.04 : 0.10),
          color.withValues(alpha: dark ? 0.24 : 0.18),
          Colors.transparent,
        ],
        stops: const [0, 0.36, 0.52, 1],
      ).createShader(scanRect);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(scanRect, scanPaint);
    canvas.restore();

    final sparkCenter = Offset(
      scanX.clamp(left - 4, right + 4).toDouble(),
      size.height * 0.24,
    );
    canvas.drawCircle(
      sparkCenter,
      2.4,
      Paint()..color = color.withValues(alpha: 0.72),
    );
    canvas.drawCircle(
      sparkCenter,
      8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sparkCenter, radius: 8)),
    );
  }

  @override
  bool shouldRepaint(covariant _ConstructionLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.dark != dark;
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: 332,
              child: LiquidGlassSurface(
                blur: true,
                blurSigma: 18,
                radius: 34,
                padding: const EdgeInsets.fromLTRB(30, 28, 30, 27),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumBrandMark(size: 74, light: dark),
                    const SizedBox(height: 18),
                    AppConstructionLoader(
                      color: dark ? theme.colorScheme.primary : textColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AppСтрой',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 38,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppUi.gap4),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.16),
                            theme.colorScheme.primary.withValues(alpha: 0.72),
                            theme.colorScheme.primary.withValues(alpha: 0.16),
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
      ),
    );
  }
}
