import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Единый лёгкий засвет от касания для всего приложения.
///
/// Эффект рисуется поверх интерфейса, но не перехватывает жесты. Он включается
/// только на короткое время после нажатия и не создаёт постоянной нагрузки.
class AppTouchGlowOverlay extends StatefulWidget {
  final Widget child;

  const AppTouchGlowOverlay({super.key, required this.child});

  @override
  State<AppTouchGlowOverlay> createState() => _AppTouchGlowOverlayState();
}

class _AppTouchGlowOverlayState extends State<AppTouchGlowOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _pulseDuration = Duration(milliseconds: 560);

  late final AnimationController _controller;
  late final ValueNotifier<Offset?> _origin;

  int? _activePointer;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _pulseDuration);
    _origin = ValueNotifier<Offset?>(null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    _origin.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_animationsDisabled) return;
    _activePointer = event.pointer;
    _origin.value = event.localPosition;
    _controller.forward(from: 0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_animationsDisabled || _activePointer != event.pointer) return;
    _origin.value = event.localPosition;
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_activePointer == event.pointer) {
      _activePointer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!_animationsDisabled)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _GlobalTouchGlowPainter(
                      animation: _controller,
                      origin: _origin,
                      color: theme.colorScheme.primary,
                      dark: theme.brightness == Brightness.dark,
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

class _GlobalTouchGlowPainter extends CustomPainter {
  final Animation<double> animation;
  final ValueNotifier<Offset?> origin;
  final Color color;
  final bool dark;

  _GlobalTouchGlowPainter({
    required this.animation,
    required this.origin,
    required this.color,
    required this.dark,
  }) : super(repaint: Listenable.merge([animation, origin]));

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0 || progress >= 1 || size.isEmpty) return;

    final rawOrigin = origin.value ?? size.center(Offset.zero);
    final center = Offset(
      rawOrigin.dx.clamp(0.0, size.width).toDouble(),
      rawOrigin.dy.clamp(0.0, size.height).toDouble(),
    );
    final eased = Curves.easeOutQuart.transform(progress);
    final fade = math.pow(1 - progress, 1.85).toDouble();
    final maximumRadius = math.min(
      310.0,
      math.max(size.width, size.height) * 0.24,
    );
    final radius = 30 + maximumRadius * eased;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: (dark ? 0.13 : 0.19) * fade),
          color.withValues(alpha: (dark ? 0.13 : 0.10) * fade),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.34, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = color.withValues(alpha: 0.075 * fade);
    canvas.drawCircle(center, 22 + maximumRadius * 0.66 * eased, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _GlobalTouchGlowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dark != dark;
  }
}
