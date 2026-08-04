import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppStroyBrandIcon extends StatelessWidget {
  final double size;
  final bool? darkBackground;
  final bool animate;
  final String semanticLabel;

  const AppStroyBrandIcon({
    super.key,
    required this.size,
    this.darkBackground,
    this.animate = false,
    this.semanticLabel = 'AppСтрой',
  });

  @override
  Widget build(BuildContext context) {
    final useDarkArtwork =
        darkBackground ?? Theme.of(context).brightness == Brightness.dark;
    final mark = Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: size * 1.115,
        height: size,
        child: CustomPaint(
          painter: _AppStroyMetalMarkPainter(
            darkBackground: useDarkArtwork,
          ),
        ),
      ),
    );

    if (!animate ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return mark;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.12, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: mark,
    );
  }
}

class _AppStroyMetalMarkPainter extends CustomPainter {
  final bool darkBackground;

  const _AppStroyMetalMarkPainter({required this.darkBackground});

  static Path get _left => Path()
    ..moveTo(38, 204)
    ..lineTo(38, 146)
    ..cubicTo(38, 130, 48, 119, 61, 114)
    ..lineTo(72, 110)
    ..cubicTo(79, 107, 86, 112, 86, 120)
    ..lineTo(86, 204)
    ..close();

  static Path get _center => Path()
    ..moveTo(96, 204)
    ..lineTo(96, 82)
    ..cubicTo(96, 61, 109, 45, 128, 39)
    ..lineTo(139, 36)
    ..cubicTo(146, 34, 153, 39, 153, 47)
    ..lineTo(153, 204)
    ..close();

  static Path get _right => Path()
    ..moveTo(163, 204)
    ..lineTo(163, 110)
    ..cubicTo(163, 97, 174, 88, 187, 91)
    ..cubicTo(211, 96, 225, 109, 225, 129)
    ..lineTo(225, 204)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    const designLeft = 38.0;
    const designTop = 36.0;
    const designWidth = 187.0;
    const designHeight = 168.0;
    final scale = math.min(
      size.width / designWidth,
      size.height / designHeight,
    );
    final drawnWidth = designWidth * scale;
    final drawnHeight = designHeight * scale;

    canvas.save();
    canvas.translate(
      (size.width - drawnWidth) / 2 - designLeft * scale,
      (size.height - drawnHeight) / 2 - designTop * scale,
    );
    canvas.scale(scale);

    final fillColors = darkBackground
        ? const [
            Color(0xFFFFFFFF),
            Color(0xFFE1E2E4),
            Color(0xFFB7B9BC),
            Color(0xFF85878A),
          ]
        : const [
            Color(0xFFBFC1C4),
            Color(0xFF777A7E),
            Color(0xFF474A4E),
            Color(0xFF26282B),
          ];
    final edgeColor = darkBackground
        ? const Color(0xFF707277)
        : const Color(0xFF191B1E);
    final highlightColor = Colors.white.withValues(
      alpha: darkBackground ? 0.86 : 0.58,
    );
    final shadowColor = Colors.black.withValues(
      alpha: darkBackground ? 0.48 : 0.27,
    );

    for (final path in [_left, _center, _right]) {
      canvas.drawShadow(path, shadowColor, darkBackground ? 7 : 10, false);

      final bounds = path.getBounds();
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.34, 0.70, 1],
          colors: fillColors,
        ).createShader(bounds);
      canvas.drawPath(path, fill);

      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..color = edgeColor;
      canvas.drawPath(path, edge);

      final highlight = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.72
        ..color = highlightColor;
      canvas.drawPath(path, highlight);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppStroyMetalMarkPainter oldDelegate) {
    return oldDelegate.darkBackground != darkBackground;
  }
}

class AppStroyAnimatedBrand extends StatefulWidget {
  final double logoSize;
  final bool showProgress;
  final String semanticsLabel;

  const AppStroyAnimatedBrand({
    super.key,
    this.logoSize = 146,
    this.showProgress = false,
    this.semanticsLabel = 'AppСтрой. планируй. строй. управляй.',
  });

  @override
  State<AppStroyAnimatedBrand> createState() =>
      _AppStroyAnimatedBrandState();
}

class _AppStroyAnimatedBrandState extends State<AppStroyAnimatedBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: widget.showProgress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = animationsDisabled ? 1.0 : _controller.value;
          final logoProgress = CurvedAnimation(
            parent: AlwaysStoppedAnimation<double>(value),
            curve: const Interval(0, 0.40, curve: Curves.easeOutBack),
          ).value;
          final textProgress = CurvedAnimation(
            parent: AlwaysStoppedAnimation<double>(value),
            curve: const Interval(0.48, 0.84, curve: Curves.easeOutCubic),
          ).value;
          final quoteProgress = CurvedAnimation(
            parent: AlwaysStoppedAnimation<double>(value),
            curve: const Interval(0.68, 1, curve: Curves.easeOutCubic),
          ).value;
          final progressOpacity = CurvedAnimation(
            parent: AlwaysStoppedAnimation<double>(value),
            curve: const Interval(0.82, 1, curve: Curves.easeOut),
          ).value;

          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: logoProgress.clamp(0.0, 1.0).toDouble(),
                      child: Transform.scale(
                        scale: 0.12 + (0.88 * logoProgress),
                        child: AppStroyBrandIcon(
                          size: widget.logoSize,
                          darkBackground: dark,
                        ),
                      ),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: textProgress,
                        child: Opacity(
                          opacity: textProgress,
                          child: Transform.translate(
                            offset: Offset(-20 * (1 - textProgress), 0),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 18),
                              child: SizedBox(
                                width: 226,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AppСтрой',
                                      maxLines: 1,
                                      style: theme.textTheme.displaySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 46,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -2.0,
                                            height: 0.98,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Opacity(
                                      opacity: quoteProgress,
                                      child: Transform.translate(
                                        offset: Offset(
                                          -12 * (1 - quoteProgress),
                                          0,
                                        ),
                                        child: Text(
                                          'планируй. строй. управляй.',
                                          maxLines: 1,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.15,
                                                height: 1.1,
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
                  ],
                ),
                if (widget.showProgress) ...[
                  const SizedBox(height: 32),
                  Opacity(
                    opacity: progressOpacity,
                    child: _BrandLoadingDots(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class AppStroyBrandStage extends StatelessWidget {
  final bool showProgress;
  final String semanticsLabel;

  const AppStroyBrandStage({
    super.key,
    this.showProgress = false,
    this.semanticsLabel = 'AppСтрой. планируй. строй. управляй.',
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF111214), Color(0xFF202226)]
              : const [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -130,
            right: -90,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: 0.055),
                            Colors.transparent,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.94),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: AppStroyAnimatedBrand(
                    showProgress: showProgress,
                    semanticsLabel: semanticsLabel,
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

class AppStroyLaunchGate extends StatefulWidget {
  final Widget child;
  final Duration minimumDuration;

  const AppStroyLaunchGate({
    super.key,
    required this.child,
    this.minimumDuration = const Duration(milliseconds: 2550),
  });

  @override
  State<AppStroyLaunchGate> createState() => _AppStroyLaunchGateState();
}

class _AppStroyLaunchGateState extends State<AppStroyLaunchGate> {
  Timer? _timer;
  bool _visible = true;
  bool _mountedOverlay = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minimumDuration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_mountedOverlay)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: animationsDisabled
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (!_visible && mounted) {
                  setState(() => _mountedOverlay = false);
                }
              },
              child: const AppStroyBrandStage(),
            ),
          ),
      ],
    );
  }
}

class _BrandLoadingDots extends StatefulWidget {
  final Color color;

  const _BrandLoadingDots({required this.color});

  @override
  State<_BrandLoadingDots> createState() => _BrandLoadingDotsState();
}

class _BrandLoadingDotsState extends State<_BrandLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return _dots(0.5);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _dots(_controller.value),
    );
  }

  Widget _dots(double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (index) {
        final phase = (value - index * 0.16) % 1.0;
        final wave = (phase <= 0.5 ? phase : 1 - phase) * 2;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.translate(
            offset: Offset(0, -3 * wave),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.32 + wave * 0.68),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
