import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'premium_ui_v2.dart' show PremiumBrandMark, PremiumDots;

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
          colors: [Color(0xFFFAF9F6), Color(0xFFE9E6DE)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -80,
            right: -55,
            child: _GlassDrop(size: 270, opacity: 0.72),
          ),
          const Positioned(
            left: -70,
            bottom: 70,
            child: _GlassDrop(size: 190, opacity: 0.46),
          ),
          const Positioned(
            right: 42,
            bottom: -58,
            child: _GlassDrop(size: 132, opacity: 0.36),
          ),
          child,
        ],
      ),
    );
  }
}

class PremiumLoadingScreen extends StatelessWidget {
  final String message;

  const PremiumLoadingScreen({
    super.key,
    this.message = 'Подготавливаем рабочее пространство',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.94),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17191C).withValues(alpha: 0.12),
                    blurRadius: 46,
                    spreadRadius: -14,
                    offset: const Offset(0, 26),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.88),
                    blurRadius: 18,
                    spreadRadius: -10,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumBrandMark(size: 98),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 22),
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

class _GlassDrop extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlassDrop({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.36, -0.42),
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: opacity * 0.22),
              const Color(0xFFD5D0C4).withValues(alpha: opacity * 0.10),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity * 0.72),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF202328).withValues(alpha: opacity * 0.10),
              blurRadius: size * 0.20,
              spreadRadius: -size * 0.08,
              offset: Offset(0, size * 0.10),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldenRatioLogoPainter extends CustomPainter {
  const _GoldenRatioLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const phi = 1.61803398875;
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF3E4C0), Color(0xFFB78C49)],
      ).createShader(Offset.zero & size);
    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFBF3), Color(0xFFD7C8A8)],
      ).createShader(Offset.zero & size);

    final unit = size.width / (phi + 1);
    final left = Rect.fromLTWH(0, size.height * 0.40, unit, size.height * 0.42);
    final tower = Rect.fromLTWH(
      unit * 1.06,
      size.height * 0.14,
      size.width - unit * 1.06,
      size.height * 0.68,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(left, Radius.circular(size.width * 0.05)),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tower, Radius.circular(size.width * 0.05)),
      stone,
    );

    final roof = Path()
      ..moveTo(size.width * 0.13, size.height * 0.82)
      ..lineTo(size.width * 0.50, size.height * 0.18)
      ..lineTo(size.width * 0.87, size.height * 0.82)
      ..lineTo(size.width * 0.66, size.height * 0.82)
      ..lineTo(size.width * 0.50, size.height * 0.52)
      ..lineTo(size.width * 0.34, size.height * 0.82)
      ..close();
    canvas.drawPath(roof, gold);

    final door = Rect.fromLTWH(
      size.width * 0.44,
      size.height * 0.68,
      size.width * 0.12,
      size.height * 0.18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(door, Radius.circular(size.width * 0.02)),
      Paint()..color = const Color(0xFF17191C),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.88, size.width, size.height * 0.045),
        Radius.circular(size.width * 0.02),
      ),
      gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
