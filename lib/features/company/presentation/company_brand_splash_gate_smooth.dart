import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_adaptive_palette.dart';
import '../data/company_branding_repository.dart';
import 'stroy_na_veka_logo_scene_smooth.dart';

class SmoothCompanyBrandSplashGate extends StatefulWidget {
  final String companyId;
  final Widget child;

  const SmoothCompanyBrandSplashGate({
    super.key,
    required this.companyId,
    required this.child,
  });

  @override
  State<SmoothCompanyBrandSplashGate> createState() =>
      _SmoothCompanyBrandSplashGateState();
}

class _SmoothCompanyBrandSplashGateState
    extends State<SmoothCompanyBrandSplashGate>
    with SingleTickerProviderStateMixin {
  static final Set<String> _shownForCompany = <String>{};
  static const Duration _remoteTimeout = Duration(seconds: 2);
  static const Duration _animationDuration = Duration(milliseconds: 2800);
  static const Duration _fallbackDuration = Duration(milliseconds: 3400);

  late final AnimationController _controller;
  CompanyBranding? _branding;
  Timer? _fallbackTimer;
  bool _complete = false;
  bool _didPrecache = false;

  String get _cachePrefix => 'appstroy_company_brand_v1_${widget.companyId}';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    unawaited(
      precacheImage(
        const AssetImage('web/icons/AppStroy-512-v2.png'),
        context,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SmoothCompanyBrandSplashGate oldWidget) {
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
      if (_branding != remote) setState(() => _branding = remote);
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
      // Кэш брендинга никогда не должен задерживать запуск приложения.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.child;

    final branding = _branding;
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashBackground(),
            if (branding == null)
              const Center(child: _AppStroyIdentity(size: 82))
            else ...[
              _AppStroyPhase(animation: _controller),
              _CompanyPhase(animation: _controller, branding: branding),
            ],
          ],
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 1.12,
          colors: [
            AppAdaptivePalette.surfaceSoft.withValues(alpha: 0.92),
            AppAdaptivePalette.background,
          ],
        ),
      ),
    );
  }
}

class _AppStroyPhase extends StatelessWidget {
  final Animation<double> animation;

  const _AppStroyPhase({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        child: const RepaintBoundary(child: _AppStroyIdentity(size: 86)),
        builder: (context, child) {
          final t = animation.value;
          if (t >= 0.50) return const SizedBox.shrink();
          final phase = _clamp01(t / 0.50);
          final intro = _interval(phase, 0.00, 0.30);
          final exit = _interval(phase, 0.70, 1.00);
          final drop = Curves.easeInCubic.transform(exit);
          final scale = 0.86 + (0.14 * intro) - (0.10 * drop);
          final opacity = 1 - _interval(exit, 0.55, 1.00);

          return Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, 170 * drop),
                child: Transform.scale(
                  scaleX: scale,
                  scaleY: scale * (1 - (0.12 * drop)),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompanyPhase extends StatelessWidget {
  final Animation<double> animation;
  final CompanyBranding branding;

  const _CompanyPhase({
    required this.animation,
    required this.branding,
  });

  @override
  Widget build(BuildContext context) {
    final isStroyNaVeka =
        branding.name.trim().toLowerCase() == 'строй на века';

    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 290,
          height: 348,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isStroyNaVeka)
                SmoothStroyNaVekaLogoScene(animation: animation)
              else
                _GenericCompanyLogoPhase(
                  animation: animation,
                  branding: branding,
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: _AppStroyFooter(animation: animation),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenericCompanyLogoPhase extends StatelessWidget {
  final Animation<double> animation;
  final CompanyBranding branding;

  const _GenericCompanyLogoPhase({
    required this.animation,
    required this.branding,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = CompanyBrandingRepository.publicLogoUrl(branding);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = _clamp01((animation.value - 0.50) / 0.50);
        if (phase <= 0) return const SizedBox.shrink();
        final reveal = _interval(phase, 0.00, 0.44);
        final title = _interval(phase, 0.42, 0.78);
        final scale = 0.72 + (0.28 * Curves.easeOutBack.transform(reveal));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: reveal,
              child: Transform.scale(
                scale: scale,
                child: _GenericLogoImage(logoUrl: logoUrl),
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: title,
              child: Text(
                branding.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppAdaptivePalette.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GenericLogoImage extends StatelessWidget {
  final String? logoUrl;

  const _GenericLogoImage({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 142,
      height: 142,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Icon(
        Icons.apartment_rounded,
        size: 62,
        color: AppAdaptivePalette.textPrimary,
      ),
    );
    if (logoUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        width: 150,
        height: 150,
        child: Image.network(
          logoUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _AppStroyFooter extends StatelessWidget {
  final Animation<double> animation;

  const _AppStroyFooter({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: const _PoweredByAppStroy(),
      builder: (context, child) {
        final phase = _clamp01((animation.value - 0.50) / 0.50);
        final reveal = _interval(phase, 0.72, 1.00);
        return Opacity(
          opacity: reveal,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - reveal)),
            child: child,
          ),
        );
      },
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
            filterQuality: FilterQuality.medium,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'web/icons/AppStroy-512-v2.png',
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Компания в AppСтрой',
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.05,
          ),
        ),
      ],
    );
  }
}

double _interval(double value, double begin, double end) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return Curves.easeOutCubic.transform((value - begin) / (end - begin));
}

double _clamp01(double value) {
  if (value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}