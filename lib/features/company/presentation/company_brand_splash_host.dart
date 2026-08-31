import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../auth/data/offline_profile_store.dart';
import '../../auth/data/user_repository.dart';
import 'company_brand_splash_gate_smooth.dart';

class CompanyBrandSplashHost extends StatefulWidget {
  final Widget child;

  const CompanyBrandSplashHost({super.key, required this.child});

  @override
  State<CompanyBrandSplashHost> createState() => _CompanyBrandSplashHostState();
}

class _CompanyBrandSplashHostState extends State<CompanyBrandSplashHost> {
  static const Duration _minimumAppStroyPhase = Duration(milliseconds: 1200);

  StreamSubscription<AuthState>? _authSubscription;
  String _companyId = '';
  String _resolvedUserId = '';
  int _generation = 0;
  bool _resolvingCompany = false;

  @override
  void initState() {
    super.initState();
    _resolvingCompany = UserRepository.currentUser != null;
    unawaited(_resolveCompany());
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => unawaited(_resolveCompany()),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _generation++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolveCompany() async {
    final generation = ++_generation;
    final user = UserRepository.currentUser;
    if (user == null) {
      if (!mounted || generation != _generation) return;
      if (_companyId.isNotEmpty ||
          _resolvedUserId.isNotEmpty ||
          _resolvingCompany) {
        setState(() {
          _companyId = '';
          _resolvedUserId = '';
          _resolvingCompany = false;
        });
      }
      return;
    }

    final showStartupPhase =
        _companyId.isEmpty && _resolvedUserId != user.id;
    final startedAt = DateTime.now();

    if (showStartupPhase && !_resolvingCompany && mounted) {
      setState(() => _resolvingCompany = true);
    }

    String companyId = '';
    final memoryProfile = UserRepository.cachedProfile;
    if (memoryProfile?.id == user.id) {
      companyId = memoryProfile!.activeCompanyId.trim();
    }

    if (companyId.isEmpty) {
      final offlineProfile = await OfflineProfileStore.read(user.id);
      if (offlineProfile?.id == user.id) {
        companyId = offlineProfile!.activeCompanyId.trim();
      }
    }

    if (companyId.isEmpty) {
      try {
        final row = await Supabase.instance.client
            .from('user_profiles')
            .select('active_company_id')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 2));
        companyId = row?['active_company_id']?.toString().trim() ?? '';
      } catch (_) {
        // При отсутствии сети используем кэш профиля, если он есть.
      }
    }

    if (showStartupPhase) {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumAppStroyPhase - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }

    if (!mounted || generation != _generation) return;
    if (companyId == _companyId &&
        _resolvedUserId == user.id &&
        !_resolvingCompany) {
      return;
    }

    setState(() {
      _companyId = companyId;
      _resolvedUserId = user.id;
      _resolvingCompany = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingCompany) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: true,
            child: TickerMode(enabled: false, child: widget.child),
          ),
          const Positioned.fill(child: _AppStroyStartupPhase()),
        ],
      );
    }

    if (_companyId.isEmpty) return widget.child;
    return SmoothCompanyBrandSplashGate(
      key: ValueKey<String>('company-brand-splash:$_companyId'),
      companyId: _companyId,
      child: widget.child,
    );
  }
}

class _AppStroyStartupPhase extends StatelessWidget {
  const _AppStroyStartupPhase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: SafeArea(
        child: DecoratedBox(
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
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                final scale = 0.94 + (0.06 * progress);
                return Opacity(
                  opacity: progress,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 154,
                    height: 154,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppAdaptivePalette.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(46),
                      border: Border.all(
                        color: AppAdaptivePalette.border.withValues(alpha: 0.78),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 38,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: Image.asset(
                        'web/icons/AppStroy-512-v2.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'AppСтрой',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppAdaptivePalette.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
