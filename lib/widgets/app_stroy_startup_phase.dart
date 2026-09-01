import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';

/// Flutter-продолжение первой заставки AppСтрой.
///
/// На Web/PWA первую заставку рисует `web/index.html`, поэтому Flutter здесь
/// оставляет только фон до готовности второго этапа и не создаёт её копию.
/// На Android/iOS этот экран остаётся полноценной первой Flutter-заставкой.
class AppStroyStartupPhase extends StatelessWidget {
  const AppStroyStartupPhase({super.key});

  double _contentScaleCompensation(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    final devicePixelRatio = view.devicePixelRatio;
    if (devicePixelRatio <= 0 || mediaQuery.size.width <= 0) return 1;

    final logicalViewportWidth = view.physicalSize.width / devicePixelRatio;
    if (logicalViewportWidth <= 0) return 1;

    final inheritedViewportScale =
        logicalViewportWidth / mediaQuery.size.width;
    if (!inheritedViewportScale.isFinite || inheritedViewportScale <= 0) {
      return 1;
    }
    return 1 / inheritedViewportScale;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(backgroundColor: AppAdaptivePalette.background);
    }

    final dark = AppAdaptivePalette.isDark;
    final contentScale = _contentScaleCompensation(context);

    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.18),
            radius: 1.12,
            colors: [
              AppAdaptivePalette.surfaceSoft.withValues(
                alpha: dark ? 0.78 : 0.54,
              ),
              AppAdaptivePalette.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Transform.scale(
              scale: contentScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 164,
                    height: 164,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dark
                            ? const [Color(0xFF1F2C3A), Color(0xFF17212B)]
                            : const [Color(0xFFFFFFFF), Color(0xFFE9E7E2)],
                      ),
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(
                        color: dark
                            ? AppAdaptivePalette.border
                            : Colors.white.withValues(alpha: 0.96),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.36 : 0.14,
                          ),
                          blurRadius: 42,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: const SizedBox.square(
                      dimension: 132,
                      child: CustomPaint(painter: _AppStroyMetalMarkPainter()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'AppСтрой',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 37,
                      height: 1,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -2.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'планируй. строй. управляй.',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.75,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppStroyMetalMarkPainter extends CustomPainter {
  const _AppStroyMetalMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 240;
    final scaleY = size.height / 240;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final rect = const Rect.fromLTWH(0, 0, 240, 240);
    final dark = AppAdaptivePalette.isDark;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFFF5F7FA), Color(0xFFB8C5D1), Color(0xFF708499)]
            : const [Color(0xFFD8D8D8), Color(0xFFA3A4A6), Color(0xFF77797C)],
        stops: const [0, 0.47, 1],
      ).createShader(rect);

    canvas.drawPath(_leftTower(), paint);
    canvas.drawPath(_centerTower(), paint);
    canvas.drawPath(_rightTower(), paint);
    canvas.restore();
  }

  Path _leftTower() => Path()
    ..moveTo(38, 204)
    ..lineTo(38, 146)
    ..cubicTo(38, 130, 48, 119, 61, 114)
    ..lineTo(72, 110)
    ..cubicTo(79, 107, 86, 112, 86, 120)
    ..lineTo(86, 204)
    ..close();

  Path _centerTower() => Path()
    ..moveTo(96, 204)
    ..lineTo(96, 82)
    ..cubicTo(96, 61, 109, 45, 128, 39)
    ..lineTo(139, 36)
    ..cubicTo(146, 34, 153, 39, 153, 47)
    ..lineTo(153, 204)
    ..close();

  Path _rightTower() => Path()
    ..moveTo(163, 204)
    ..lineTo(163, 110)
    ..cubicTo(163, 97, 174, 88, 187, 91)
    ..cubicTo(211, 96, 225, 109, 225, 129)
    ..lineTo(225, 204)
    ..close();

  @override
  bool shouldRepaint(covariant _AppStroyMetalMarkPainter oldDelegate) => false;
}
