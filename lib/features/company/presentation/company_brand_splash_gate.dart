import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_adaptive_palette.dart';
import '../data/company_branding_repository.dart';

class CompanyBrandSplashGate extends StatefulWidget {
  final String companyId;
  final Widget child;

  const CompanyBrandSplashGate({
    super.key,
    required this.companyId,
    required this.child,
  });

  @override
  State<CompanyBrandSplashGate> createState() => _CompanyBrandSplashGateState();
}

class _CompanyBrandSplashGateState extends State<CompanyBrandSplashGate>
    with SingleTickerProviderStateMixin {
  static final Set<String> _shownForCompany = <String>{};
  static const Duration _remoteTimeout = Duration(seconds: 2);
  static const Duration _fallbackDuration = Duration(milliseconds: 3900);

  late final AnimationController _controller;
  CompanyBranding? _branding;
  bool _complete = false;
  Timer? _fallbackTimer;

  String get _cachePrefix => 'appstroy_company_brand_v1_${widget.companyId}';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3300),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });

    if (_shownForCompany.contains(widget.companyId)) {
      _complete = true;
    } else {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant CompanyBrandSplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId == widget.companyId) return;
    _fallbackTimer?.cancel();
    _branding = null;
    _controller.reset();
    _complete = _shownForCompany.contains(widget.companyId);
    if (!_complete) unawaited(_load());
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await _readCache();
    if (!mounted) return;
    if (cached != null) {
      setState(() => _branding = cached);
      _startAnimation();
    }

    _fallbackTimer = Timer(_fallbackDuration, _finish);

    try {
      final remote = await CompanyBrandingRepository.fetch(
        widget.companyId,
      ).timeout(_remoteTimeout);
      await _writeCache(remote);
      if (!mounted) return;
      setState(() => _branding = remote);
      _startAnimation();
    } catch (_) {
      if (cached == null) _finish();
    }
  }

  void _startAnimation() {
    if (_controller.isAnimating || _controller.isCompleted) return;
    unawaited(_controller.forward());
  }

  void _finish() {
    if (!mounted || _complete) return;
    _fallbackTimer?.cancel();
    _shownForCompany.add(widget.companyId);
    setState(() => _complete = true);
  }

  Future<CompanyBranding?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString('${_cachePrefix}_name')?.trim() ?? '';
      if (name.isEmpty) return null;
      final logoPath = preferences.getString('${_cachePrefix}_logo')?.trim();
      final updatedRaw = preferences.getString('${_cachePrefix}_updated');
      return CompanyBranding(
        companyId: widget.companyId,
        name: name,
        logoPath: logoPath?.isEmpty == true ? null : logoPath,
        updatedAt: DateTime.tryParse(updatedRaw ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CompanyBranding branding) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('${_cachePrefix}_name', branding.name);
      final logoPath = branding.logoPath?.trim() ?? '';
      if (logoPath.isEmpty) {
        await preferences.remove('${_cachePrefix}_logo');
      } else {
        await preferences.setString('${_cachePrefix}_logo', logoPath);
      }
      final updatedAt = branding.updatedAt;
      if (updatedAt == null) {
        await preferences.remove('${_cachePrefix}_updated');
      } else {
        await preferences.setString(
          '${_cachePrefix}_updated',
          updatedAt.toIso8601String(),
        );
      }
    } catch (_) {
      // Кэш брендинга не должен влиять на запуск приложения.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.child;

    final branding = _branding;
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: SafeArea(
        child: branding == null
            ? const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            : _AnimatedCompanyLaunch(
                animation: _controller,
                branding: branding,
              ),
      ),
    );
  }
}

class _AnimatedCompanyLaunch extends StatelessWidget {
  final Animation<double> animation;
  final CompanyBranding branding;

  const _AnimatedCompanyLaunch({
    required this.animation,
    required this.branding,
  });

  static const String _stroyNaVekaAsset = 'assets/stroi_na_veka.webp';

  @override
  Widget build(BuildContext context) {
    final isStroyNaVeka = branding.name.trim().toLowerCase() ==
        'строй на века'.toLowerCase();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final appIntro = _interval(t, 0.00, 0.24);
        final companyIntro = _interval(t, 0.16, 0.40);
        final wallBuild = _interval(t, 0.28, 0.58);
        final towersBuild = _interval(t, 0.42, 0.74);
        final markReveal = _interval(t, 0.65, 0.84);
        final settle = _interval(t, 0.78, 1.00);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.24),
                    radius: 1.18,
                    colors: [
                      AppAdaptivePalette.surfaceSoft.withValues(alpha: 0.92),
                      AppAdaptivePalette.background,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.14 * companyIntro,
                  child: CustomPaint(
                    painter: _BlueprintGridPainter(
                      progress: companyIntro,
                      color: AppAdaptivePalette.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -18 * companyIntro),
                      child: Opacity(
                        opacity: (1 - companyIntro * 0.82).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.92 + (0.08 * appIntro),
                          child: const _AppStroyIdentity(size: 78),
                        ),
                      ),
                    ),
                    SizedBox(height: 12 + (8 * companyIntro)),
                    Opacity(
                      opacity: companyIntro,
                      child: Transform.scale(
                        scale: 0.94 + (0.06 * companyIntro),
                        child: isStroyNaVeka
                            ? _CastleBuildLogo(
                                wallProgress: wallBuild,
                                towerProgress: towersBuild,
                                finalReveal: markReveal,
                                settle: settle,
                              )
                            : _GenericCompanyLogo(
                                branding: branding,
                                reveal: markReveal,
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: markReveal,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - markReveal)),
                        child: Text(
                          branding.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppAdaptivePalette.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.45,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: settle,
                      child: const _PoweredByAppStroy(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CastleBuildLogo extends StatelessWidget {
  final double wallProgress;
  final double towerProgress;
  final double finalReveal;
  final double settle;

  const _CastleBuildLogo({
    required this.wallProgress,
    required this.towerProgress,
    required this.finalReveal,
    required this.settle,
  });

  static const String asset = 'assets/stroi_na_veka.webp';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      height: 234,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.11 + (0.12 * settle),
            child: Transform.scale(
              scale: 0.96 + (0.04 * settle),
              child: const Image(
                image: AssetImage(asset),
                fit: BoxFit.contain,
              ),
            ),
          ),
          _LogoSliceReveal(
            asset: asset,
            rect: const Rect.fromLTWH(0.26, 0.31, 0.48, 0.45),
            progress: wallProgress,
            rise: 28,
          ),
          _LogoSliceReveal(
            asset: asset,
            rect: const Rect.fromLTWH(0.05, 0.12, 0.28, 0.60),
            progress: towerProgress,
            rise: 46,
          ),
          _LogoSliceReveal(
            asset: asset,
            rect: const Rect.fromLTWH(0.68, 0.12, 0.27, 0.60),
            progress: towerProgress,
            rise: 46,
          ),
          Opacity(
            opacity: finalReveal,
            child: Transform.scale(
              scale: 0.985 + (0.015 * settle),
              child: const Image(
                image: AssetImage(asset),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - settle) * 0.32,
                child: CustomPaint(
                  painter: _ConstructionSparkPainter(
                    progress: towerProgress,
                    color: const Color(0xFF4D79C7),
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

class _LogoSliceReveal extends StatelessWidget {
  final String asset;
  final Rect rect;
  final double progress;
  final double rise;

  const _LogoSliceReveal({
    required this.asset,
    required this.rect,
    required this.progress,
    required this.rise,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    return ClipPath(
      clipper: _FractionalRectClipper(rect),
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: progress.clamp(0.01, 1.0),
          child: Transform.translate(
            offset: Offset(0, rise * (1 - progress)),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _FractionalRectClipper extends CustomClipper<Path> {
  final Rect fractionalRect;

  const _FractionalRectClipper(this.fractionalRect);

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTWH(
      fractionalRect.left * size.width,
      fractionalRect.top * size.height,
      fractionalRect.width * size.width,
      fractionalRect.height * size.height,
    );
    return Path()..addRect(rect);
  }

  @override
  bool shouldReclip(covariant _FractionalRectClipper oldClipper) {
    return oldClipper.fractionalRect != fractionalRect;
  }
}

class _GenericCompanyLogo extends StatelessWidget {
  final CompanyBranding branding;
  final double reveal;

  const _GenericCompanyLogo({required this.branding, required this.reveal});

  @override
  Widget build(BuildContext context) {
    final logoUrl = CompanyBrandingRepository.publicLogoUrl(branding);
    final fallback = Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Icon(
        Icons.apartment_rounded,
        size: 58,
        color: AppAdaptivePalette.textPrimary,
      ),
    );

    if (logoUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 146,
        height: 146,
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return fallback;
          },
        ),
      ),
    );
  }
}

class _PoweredByAppStroy extends StatelessWidget {
  const _PoweredByAppStroy();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppStroyMark(size: 22),
        const SizedBox(width: 8),
        Text(
          'AppСтрой',
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _AppStroyIdentity extends StatelessWidget {
  final double size;

  const _AppStroyIdentity({required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AppStroyMark(size: size),
        const SizedBox(height: 10),
        Text(
          'AppСтрой',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
        ),
      ],
    );
  }
}

class _AppStroyMark extends StatelessWidget {
  final double size;

  const _AppStroyMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppStroyMarkPainter(
          foreground: AppAdaptivePalette.textMuted,
          background: AppAdaptivePalette.surfaceSoft,
        ),
      ),
    );
  }
}

class _AppStroyMarkPainter extends CustomPainter {
  final Color foreground;
  final Color background;

  const _AppStroyMarkPainter({
    required this.foreground,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(126 * s),
    );
    canvas.drawRRect(outer, Paint()..color = background);

    final border = RRect.fromRectAndRadius(
      Rect.fromLTWH(9 * s, 9 * s, size.width - (18 * s), size.height - (18 * s)),
      Radius.circular(118 * s),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..color = Colors.white.withValues(alpha: 0.44),
    );

    final paint = Paint()..color = foreground;
    final path = Path();

    path
      ..moveTo(122 * s, 385 * s)
      ..lineTo(122 * s, 288 * s)
      ..cubicTo(122 * s, 261 * s, 139 * s, 242 * s, 161 * s, 234 * s)
      ..lineTo(179 * s, 227 * s)
      ..cubicTo(191 * s, 222 * s, 202 * s, 230 * s, 202 * s, 244 * s)
      ..lineTo(202 * s, 385 * s)
      ..close();
    canvas.drawPath(path, paint);

    path.reset();
    path
      ..moveTo(219 * s, 385 * s)
      ..lineTo(219 * s, 180 * s)
      ..cubicTo(219 * s, 145 * s, 241 * s, 118 * s, 273 * s, 108 * s)
      ..lineTo(291 * s, 103 * s)
      ..cubicTo(303 * s, 100 * s, 314 * s, 108 * s, 314 * s, 121 * s)
      ..lineTo(314 * s, 385 * s)
      ..close();
    canvas.drawPath(path, paint);

    path.reset();
    path
      ..moveTo(331 * s, 385 * s)
      ..lineTo(331 * s, 227 * s)
      ..cubicTo(331 * s, 205 * s, 349 * s, 190 * s, 371 * s, 195 * s)
      ..cubicTo(411 * s, 203 * s, 435 * s, 225 * s, 435 * s, 259 * s)
      ..lineTo(435 * s, 385 * s)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AppStroyMarkPainter oldDelegate) {
    return oldDelegate.foreground != foreground ||
        oldDelegate.background != background;
  }
}

class _BlueprintGridPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _BlueprintGridPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22 * progress)
      ..strokeWidth = 0.6;
    const spacing = 28.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGridPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ConstructionSparkPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ConstructionSparkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (progress * (1 - progress) * 3.2).clamp(0.0, 0.7);
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final y = size.height * (0.76 - (0.46 * progress));
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.26 + (0.095 * i));
      final spread = 7 + (i.isEven ? 3 : 0);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + spread, y - 7 - (i % 3) * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstructionSparkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

double _interval(double value, double begin, double end) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  final normalized = (value - begin) / (end - begin);
  return Curves.easeOutCubic.transform(normalized);
}
