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
  final double hoverScale;
  final bool enableHaptics;

  const PremiumPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.pressedScale = AppMotion.pressedScale,
    this.hoverScale = AppMotion.hoverScale,
    this.enableHaptics = true,
  });

  @override
  State<PremiumPressable> createState() => _PremiumPressableState();
}

class _PremiumPressableState extends State<PremiumPressable>
    with SingleTickerProviderStateMixin {
  static const Duration _pressDuration = Duration(milliseconds: 38);
  static const Duration _hoverDuration = Duration(milliseconds: 85);
  static const Duration _releaseDuration = Duration(milliseconds: 190);
  static const Duration _glowDuration = Duration(milliseconds: 430);

  late final AnimationController glowController;

  bool isPressed = false;
  bool isHovered = false;
  bool isFocused = false;
  Offset? glowOrigin;

  bool get isEnabled => widget.onTap != null;

  bool get supportsHover {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    glowController = AnimationController(vsync: this, duration: _glowDuration);
  }

  @override
  void dispose() {
    glowController.dispose();
    super.dispose();
  }

  void updatePressed(bool value) {
    if (!mounted || isPressed == value) return;
    setState(() => isPressed = value);
  }

  void triggerGlow(Offset origin) {
    if (!mounted) return;
    setState(() => glowOrigin = origin);
    glowController.forward(from: 0);
  }

  void handleTapDown(TapDownDetails details) {
    if (!isEnabled) return;
    updatePressed(true);
    triggerGlow(details.localPosition);

    if (widget.enableHaptics && !kIsWeb) {
      final platform = defaultTargetPlatform;
      if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void invokeAction() {
    if (!isEnabled) return;
    final renderBox = context.findRenderObject();
    if (renderBox is RenderBox && renderBox.hasSize) {
      triggerGlow(renderBox.size.center(Offset.zero));
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final activeHover = supportsHover && isHovered && isEnabled && !isPressed;
    final showFocusRing = isFocused && isEnabled;
    final scale = isPressed
        ? widget.pressedScale
        : activeHover
        ? widget.hoverScale
        : 1.0;
    final duration = animationsDisabled
        ? Duration.zero
        : isPressed
        ? _pressDuration
        : activeHover
        ? _hoverDuration
        : _releaseDuration;
    final curve = animationsDisabled
        ? Curves.linear
        : isPressed
        ? Curves.easeOut
        : activeHover
        ? AppMotion.interactionCurve
        : Curves.easeOutBack;

    return Semantics(
      button: true,
      enabled: isEnabled,
      child: FocusableActionDetector(
        enabled: isEnabled,
        mouseCursor: isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) {
          if (!mounted || isHovered == value) return;
          setState(() => isHovered = value);
        },
        onShowFocusHighlight: (value) {
          if (!mounted || isFocused == value) return;
          setState(() => isFocused = value);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              invokeAction();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: isEnabled ? handleTapDown : null,
          onTapCancel: isEnabled ? () => updatePressed(false) : null,
          onTapUp: isEnabled ? (_) => updatePressed(false) : null,
          onTap: widget.onTap,
          child: AnimatedSlide(
            offset: activeHover ? const Offset(0, -0.012) : Offset.zero,
            duration: duration,
            curve: curve,
            child: AnimatedScale(
              scale: scale,
              duration: duration,
              curve: curve,
              child: AnimatedContainer(
                duration: duration,
                curve: curve,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: isPressed
                        ? primary.withValues(alpha: 0.24)
                        : showFocusRing
                        ? primary.withValues(alpha: 0.35)
                        : Colors.transparent,
                    width: isPressed ? 1.35 : 1,
                  ),
                  boxShadow: activeHover
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF17191C,
                            ).withValues(alpha: 0.10),
                            blurRadius: 24,
                            spreadRadius: -8,
                            offset: const Offset(0, 11),
                          ),
                        ]
                      : isPressed
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.10),
                            blurRadius: 16,
                            spreadRadius: -7,
                          ),
                        ]
                      : const [],
                ),
                child: AnimatedOpacity(
                  opacity: isEnabled ? (isPressed ? 0.96 : 1) : 0.46,
                  duration: duration,
                  child: ClipRRect(
                    borderRadius: widget.borderRadius,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        widget.child,
                        if (isEnabled && !animationsDisabled)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: AnimatedBuilder(
                                  animation: glowController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _TouchGlowPainter(
                                        progress: glowController.value,
                                        origin: glowOrigin,
                                        color: primary,
                                      ),
                                    );
                                  },
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
          ),
        ),
      ),
    );
  }
}

class _TouchGlowPainter extends CustomPainter {
  final double progress;
  final Offset? origin;
  final Color color;

  const _TouchGlowPainter({
    required this.progress,
    required this.origin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || size.isEmpty) return;

    final center = Offset(
      (origin?.dx ?? size.width / 2).clamp(0.0, size.width),
      (origin?.dy ?? size.height / 2).clamp(0.0, size.height),
    );
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = math.pow(1 - progress, 1.7).toDouble();
    final radius = 18 + math.max(size.width, size.height) * 0.92 * eased;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.22 * fade),
          color.withValues(alpha: 0.13 * fade),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.38, 1],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _TouchGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.color != color;
  }
}
