import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/app_stroy_startup_phase.dart';
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
          const Positioned.fill(child: AppStroyStartupPhase()),
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
