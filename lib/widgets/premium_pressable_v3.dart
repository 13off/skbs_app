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

class _PremiumPressableState extends State<PremiumPressable> {
  bool isPressed = false;
  bool isHovered = false;
  bool isFocused = false;

  bool get isEnabled => widget.onTap != null;

  bool get supportsHover {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

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

  void invokeAction() {
    if (!isEnabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final activeHover = supportsHover && isHovered && isEnabled && !isPressed;
    final showFocusRing = isFocused && isEnabled;
    final scale = isPressed
        ? widget.pressedScale
        : activeHover
        ? widget.hoverScale
        : 1.0;
    final duration = isPressed ? AppMotion.pressIn : AppMotion.hover;
    final curve = isPressed ? Curves.easeOut : AppMotion.interactionCurve;

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
                duration: AppMotion.regular,
                curve: AppMotion.interactionCurve,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: showFocusRing
                        ? AppColors.accent.withValues(alpha: 0.35)
                        : Colors.transparent,
                    width: 1,
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
                      : const [],
                ),
                child: AnimatedOpacity(
                  opacity: isEnabled ? (isPressed ? 0.95 : 1) : 0.46,
                  duration: AppMotion.fast,
                  child: ClipRRect(
                    borderRadius: widget.borderRadius,
                    child: widget.child,
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
