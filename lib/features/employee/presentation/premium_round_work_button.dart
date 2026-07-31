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
    with SingleTickerProviderStateMixin {
  late final AnimationController pulseController;
  bool pressed = false;
  bool animationsDisabled = false;

  bool get canPress => widget.onPressed != null;
  bool get canPulse =>
      canPress && !widget.active && !widget.loading && !animationsDisabled;

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    syncPulse();
  }

  @override
  void didUpdateWidget(covariant PremiumRoundWorkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPulse();
  }

  void syncPulse() {
    if (canPulse) {
      if (!pulseController.isAnimating) {
        pulseController.repeat(reverse: true);
      }
      return;
    }

    pulseController
      ..stop()
      ..value = 0;
  }

  void setPressed(bool value) {
    if (!mounted || pressed == value) return;
    setState(() => pressed = value);
  }

  @override
  void dispose() {
    pulseController.dispose();
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
    final dimension = width < 390 ? 244.0 : 272.0;
    final foreground = widget.active ? scheme.onSurface : Colors.white;

    return Semantics(
      button: !widget.active,
      enabled: canPress,
      label: widget.active ? 'Рабочий день идёт' : 'Начать работу',
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final pulse = canPulse
              ? Curves.easeInOutCubic.transform(pulseController.value)
              : 0.0;
          final pulseScale = 1 + (pulse * 0.018);
          final glowAlpha = widget.active ? 0.28 : 0.34 + (pulse * 0.16);
          final glowBlur = widget.active ? 38.0 : 42 + (pulse * 18);

          return AnimatedScale(
            scale: pressed ? 0.965 : 1,
            duration: Duration(milliseconds: pressed ? 75 : 240),
            curve: pressed ? Curves.easeOutCubic : Curves.easeOutBack,
            child: Transform.scale(
              scale: pulseScale,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: canPress ? (_) => setPressed(true) : null,
                onTapUp: canPress ? (_) => setPressed(false) : null,
                onTapCancel: canPress ? () => setPressed(false) : null,
                onTap: canPress
                    ? () {
                        setPressed(false);
                        widget.onPressed?.call();
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: dimension,
                  height: dimension,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.active
                          ? (dark
                              ? const [Color(0xFF38434D), Color(0xFF171E25)]
                              : const [Color(0xFFFFFFFF), Color(0xFFDDE4EB)])
                          : const [Color(0xFF50B7FF), Color(0xFF0862AA)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: dark ? 0.18 : 0.72,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.active
                            ? Colors.black.withValues(alpha: dark ? 0.38 : 0.16)
                            : scheme.primary.withValues(alpha: glowAlpha),
                        blurRadius: glowBlur,
                        spreadRadius: widget.active ? -12 : -8 + (pulse * 3),
                        offset: Offset(0, pressed ? 13 : 22),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: widget.active ? 0.10 : 0.20 + (pulse * 0.10),
                        ),
                        blurRadius: 18,
                        spreadRadius: -9,
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
                          center: const Alignment(-0.32, -0.38),
                          radius: 1.12,
                          colors: widget.active
                              ? (dark
                                  ? const [Color(0xFF303B45), Color(0xFF131A20)]
                                  : const [
                                      Color(0xFFF8FAFC),
                                      Color(0xFFD4DDE5),
                                    ])
                              : const [Color(0xFF369FEA), Color(0xFF07538F)],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: widget.active
                                ? (dark ? 0.10 : 0.78)
                                : 0.22 + (pulse * 0.12),
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Container(
                              width: dimension * (0.70 + pulse * 0.02),
                              height: dimension * (0.70 + pulse * 0.02),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: widget.active
                                        ? 0.05
                                        : 0.10 + (pulse * 0.08),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.loading)
                                  const SizedBox.square(
                                    dimension: 48,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 4,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    widget.active
                                        ? Icons.work_history_rounded
                                        : Icons.play_arrow_rounded,
                                    size: widget.active ? 58 : 72,
                                    color: foreground,
                                  ),
                                const SizedBox(height: 14),
                                Text(
                                  widget.loading
                                      ? 'Запускаем…'
                                      : widget.active
                                          ? 'Работа идёт'
                                          : 'Начать работу',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: width < 390 ? 22 : 24,
                                    height: 1.05,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.45,
                                  ),
                                ),
                                if (widget.active &&
                                    widget.startedAt != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'с ${formatTime(widget.startedAt!)}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ],
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
        },
      ),
    );
  }
}
