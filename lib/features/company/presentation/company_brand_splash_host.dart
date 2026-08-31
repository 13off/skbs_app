import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  StreamSubscription<AuthState>? _authSubscription;
  String _companyId = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
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
      if (_companyId.isNotEmpty) setState(() => _companyId = '');
      return;
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
        // При отсутствии сети не задерживаем вход в приложение.
      }
    }

    if (!mounted || generation != _generation || companyId == _companyId) return;
    setState(() => _companyId = companyId);
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) return widget.child;
    return SmoothCompanyBrandSplashGate(
      key: ValueKey<String>('company-brand-splash:$_companyId'),
      companyId: _companyId,
      child: widget.child,
    );
  }
}
