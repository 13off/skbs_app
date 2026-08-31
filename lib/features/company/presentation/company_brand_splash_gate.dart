import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_adaptive_palette.dart';
import '../data/company_branding_repository.dart';
import 'stroy_na_veka_logo_scene.dart';

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
  static const Duration _fallbackDuration = Duration(milliseconds: 4300);

  late final AnimationController _controller;
  CompanyBranding? _branding;
  Timer? _fallbackTimer;
  bool _complete = false;

  String get _cachePrefix => 'appstroy_company_brand_v1_${widget.companyId}';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3650),
    )..addStatusListener((status) {
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
      // Кэш оформления компании не должен ломать запуск приложения.
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

  @override
  Widget build(BuildContext context) {
    final isStroyNaVeka =
        branding.name.trim().toLowerCase() == 'строй на века';

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final appIntro = _interval(t, 0.00, 0.17);
        final companyIntro = _interval(t, 0.12, 0.30);
        final shield = _interval(t, 0.20, 0.43);
        final wall = _interval(t, 0.30, 0.61);
        final towers = _interval(t, 0.40, 0.72);
        final roofs = _interval(t, 0.58, 0.78);
        final title = _interval(t, 0.70, 0.88);
        final settle = _interval(t, 0.84, 1.00);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.18),
                    radius: 1.16,
                    colors: [
                      AppAdaptivePalette.surfaceSoft.withValues(alpha: 0.94),
                      AppAdaptivePalette.background,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.10 * companyIntro * (1 - (settle * 0.55)),
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
                      offset: Offset(0, -16 * companyIntro),
                      child: Transform.scale(
                        scale: 0.92 + (0.08 * appIntro) - (0.28 * companyIntro),
                        child: Opacity(
                          opacity: 1 - (0.42 * companyIntro),
                          child: const _AppStroyIdentity(size: 80),
                        ),
                      ),
                    ),
                    SizedBox(height: 6 + (4 * companyIntro)),
                    Opacity(
                      opacity: companyIntro,
                      child: Transform.scale(
                        scale: 0.94 + (0.06 * companyIntro),
                        child: isStroyNaVeka
                            ? StroyNaVekaLogoScene(
                                shieldProgress: shield,
                                wallProgress: wall,
                                towerProgress: towers,
                                roofProgress: roofs,
                                titleProgress: title,
                                settleProgress: settle,
                              )
                            : _GenericCompanyLogo(
                                branding: branding,
                                reveal: title,
                              ),
                      ),
                    ),
                    if (!isStroyNaVeka) ...[
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: title,
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
                    ],
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 7 * (1 - title)),
                        child: const _PoweredByAppStroy(),
                      ),
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

    final logo = logoUrl == null
        ? fallback
        : ClipRRect(
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

    return Opacity(
      opacity: reveal,
      child: Transform.scale(
        scale: 0.94 + (0.06 * reveal),
        child: logo,
      ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.asset(
            'web/icons/AppStroy-512-v2.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
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

class _PoweredByAppStroy extends StatelessWidget {
  const _PoweredByAppStroy();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'web/icons/AppStroy-512-v2.png',
              width: 22,
              height: 22,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Компания в AppСтрой',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _BlueprintGridPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.20 * progress)
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

double _interval(double value, double begin, double end) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return Curves.easeOutCubic.transform((value - begin) / (end - begin));
}
