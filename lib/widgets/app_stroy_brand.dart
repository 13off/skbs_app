import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_stroy_brand_assets.dart';

final Uint8List _appStroyDarkIconBytes = base64Decode(
  appStroyDarkIconWebpBase64,
);
final Uint8List _appStroyLightIconBytes = base64Decode(
  appStroyLightIconWebpBase64,
);

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
    final image = Image.memory(
      useDarkArtwork ? _appStroyDarkIconBytes : _appStroyLightIconBytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
    );

    if (!animate ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return image;
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
      child: image,
    );
  }
}

class AppStroyAnimatedBrand extends StatefulWidget {
  final double logoSize;
  final bool showProgress;
  final String semanticsLabel;

  const AppStroyAnimatedBrand({
    super.key,
    this.logoSize = 104,
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final responsiveLogoSize = widget.logoSize;

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
                              size: responsiveLogoSize,
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
                                offset: Offset(-18 * (1 - textProgress), 0),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 22),
                                  child: SizedBox(
                                    width: 300,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AppСтрой',
                                          maxLines: 1,
                                          style: theme.textTheme.displaySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -1.7,
                                                height: 0.98,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Opacity(
                                          opacity: quoteProgress,
                                          child: Transform.translate(
                                            offset: Offset(
                                              -10 * (1 - quoteProgress),
                                              0,
                                            ),
                                            child: Text(
                                              'планируй. строй. управляй.',
                                              maxLines: 1,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.4,
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
                      const SizedBox(height: 28),
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
              : const [Color(0xFFFFFFFF), Color(0xFFF2F2F2)],
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
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
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
              width: 6,
              height: 6,
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
