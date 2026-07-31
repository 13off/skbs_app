import 'package:flutter/material.dart';

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
  late final AnimationController edgePulseController;
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
      duration: const Duration(milliseconds: 2100),
    );
    edgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    syncIdlePulse();
  }

  @override
  void didUpdateWidget(covariant PremiumRoundWorkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncIdlePulse();
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

  void setPressed(bool value) {
    if (!mounted || pressed == value) return;
    setState(() => pressed = value);
  }

  void triggerTap() {
    setPressed(false);
    if (!animationsDisabled) {
      edgePulseController.forward(from: 0);
    }
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    idlePulseController.dispose();
    edgePulseController.dispose();
    super.dispose();
  }

  String formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final dimension = width < 390 ? 232.0 : 256.0;
    final canvasSize = dimension + 64;
    final actionColor = widget.active
        ? const Color(0xFFFF6B4A)
        : const Color(0xFF339CF0);

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
                edgePulseController,
              ]),
              builder: (context, _) {
                final idlePulse = canIdlePulse
                    ? Curves.easeInOutCubic.transform(
                        idlePulseController.value,
                      )
                    : 0.0;
                final edgePulse = Curves.easeOutCubic.transform(
                  edgePulseController.value,
                );
                final delayedEdgePulse = ((edgePulse - 0.20) / 0.80)
                    .clamp(0.0, 1.0)
                    .toDouble();
                final buttonScale = pressed
                    ? 0.94
                    : 1 + (idlePulse * 0.012);

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.scale(
                      scale: 1 + (idlePulse * 0.055),
                      child: Opacity(
                        opacity: 0.18 + (idlePulse * 0.10),
                        child: Container(
                          width: dimension + 16,
                          height: dimension + 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: actionColor,
                              width: 2.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (edgePulse > 0)
                      Transform.scale(
                        scale: 1 + (edgePulse * 0.24),
                        child: Opacity(
                          opacity: (1 - edgePulse) * 0.88,
                          child: Container(
                            width: dimension + 12,
                            height: dimension + 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: actionColor,
                                width: 4.5 - (edgePulse * 2.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (delayedEdgePulse > 0)
                      Transform.scale(
                        scale: 1 + (delayedEdgePulse * 0.34),
                        child: Opacity(
                          opacity: (1 - delayedEdgePulse) * 0.56,
                          child: Container(
                            width: dimension + 8,
                            height: dimension + 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    AnimatedScale(
                      scale: buttonScale,
                      duration: Duration(milliseconds: pressed ? 75 : 260),
                      curve: pressed
                          ? Curves.easeOutCubic
                          : Curves.easeOutBack,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: canPress ? (_) => setPressed(true) : null,
                        onTapUp: canPress ? (_) => setPressed(false) : null,
                        onTapCancel: canPress ? () => setPressed(false) : null,
                        onTap: canPress ? triggerTap : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: dimension,
                          height: dimension,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: widget.active
                                  ? const [
                                      Color(0xFFFFA05C),
                                      Color(0xFFE8483F),
                                    ]
                                  : const [
                                      Color(0xFF63C7FF),
                                      Color(0xFF1777CC),
                                    ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: dark ? 0.24 : 0.76,
                              ),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: actionColor.withValues(
                                  alpha: 0.38 + (idlePulse * 0.14),
                                ),
                                blurRadius: 34 + (idlePulse * 16),
                                spreadRadius: -7 + (idlePulse * 2),
                                offset: Offset(0, pressed ? 10 : 20),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: 0.22 + (idlePulse * 0.06),
                                ),
                                blurRadius: 18,
                                spreadRadius: -8,
                                offset: const Offset(-8, -10),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.34, -0.42),
                                  radius: 1.12,
                                  colors: widget.active
                                      ? const [
                                          Color(0xFFFF9161),
                                          Color(0xFFD93C38),
                                        ]
                                      : const [
                                          Color(0xFF55B8F5),
                                          Color(0xFF1267AF),
                                        ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  width: 1.4,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned(
                                    top: 42,
                                    right: 46,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 52,
                                    left: 48,
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      width: dimension * 0.43,
                                      height: dimension * 0.43,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(alpha: 0.34),
                                            Colors.white.withValues(alpha: 0.12),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.32,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.14,
                                            ),
                                            blurRadius: 20,
                                            spreadRadius: -8,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: widget.loading
                                          ? const Center(
                                              child: SizedBox.square(
                                                dimension: 42,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 4,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              widget.active
                                                  ? Icons.stop_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: widget.active ? 62 : 70,
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
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
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
