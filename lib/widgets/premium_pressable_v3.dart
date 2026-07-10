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
    final activeHover = isHovered && isEnabled && !isPressed;
    final scale = isPressed
        ? widget.pressedScale
        : activeHover
        ? 1.0015
        : 1.0;

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
          duration: isPressed
              ? AppMotion.pressIn
              : const Duration(milliseconds: 220),
          curve: isPressed
              ? Curves.easeOut
              : const Cubic(0.22, 1, 0.36, 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: const Cubic(0.22, 1, 0.36, 1),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: activeHover
                    ? Colors.white.withValues(alpha: 0.82)
                    : Colors.transparent,
                width: 0.8,
              ),
              boxShadow: activeHover
                  ? [
                      BoxShadow(
                        color: const Color(0xFF111317).withValues(alpha: 0.055),
                        blurRadius: 28,
                        spreadRadius: -8,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.72),
                        blurRadius: 10,
                        spreadRadius: -5,
                        offset: const Offset(0, -2),
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedOpacity(
              opacity: isEnabled ? (isPressed ? 0.965 : 1) : 0.46,
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
