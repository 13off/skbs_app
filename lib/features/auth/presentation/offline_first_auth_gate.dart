import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/main_screen.dart';
import '../data/offline_profile_store.dart';
import '../data/user_repository.dart';
import 'employee_aware_auth_gate.dart' as legacy;

class OfflineFirstAuthGate extends StatefulWidget {
  const OfflineFirstAuthGate({super.key});

  @override
  State<OfflineFirstAuthGate> createState() => _OfflineFirstAuthGateState();
}

class _OfflineFirstAuthGateState extends State<OfflineFirstAuthGate> {
  static const Duration _profileRefreshTimeout = Duration(seconds: 4);

  StreamSubscription<AuthState>? _authSubscription;
  AppUserProfile? _offlineProfile;
  String? _offlineUserId;
  bool _restoring = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreAndRefresh());
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => unawaited(_restoreAndRefresh(forceRefresh: true)),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _generation++;
    _authSubscription?.cancel();
    super.dispose();
  }

  bool get _mustUseLegacyFlow {
    if (UserRepository.mustSetPassword) return true;
    return Uri.base.queryParameters.containsKey('companyInvite') ||
        Uri.base.queryParameters.containsKey('inviteTokenHash') ||
        Uri.base.queryParameters['privateImport'] == '1';
  }

  Future<void> _restoreAndRefresh({bool forceRefresh = false}) async {
    final generation = ++_generation;
    final user = UserRepository.currentUser;

    if (user == null) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _offlineProfile = null;
        _offlineUserId = null;
        _restoring = false;
      });
      return;
    }

    if (_mustUseLegacyFlow) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _offlineProfile = null;
        _offlineUserId = user.id;
        _restoring = false;
      });
      return;
    }

    final cachedInMemory = UserRepository.cachedProfile;
    final cached = cachedInMemory?.id == user.id
        ? cachedInMemory
        : await OfflineProfileStore.read(user.id);

    if (!mounted || generation != _generation) return;
    if (cached != null && cached.isActive) {
      setState(() {
        _offlineProfile = cached;
        _offlineUserId = user.id;
        _restoring = false;
      });
    } else if (_restoring) {
      setState(() {
        _offlineProfile = null;
        _offlineUserId = user.id;
        _restoring = false;
      });
    }

    unawaited(_refreshFromServer(user.id, generation, forceRefresh));
  }

  Future<void> _refreshFromServer(
    String userId,
    int generation,
    bool forceRefresh,
  ) async {
    try {
      final refreshed = await UserRepository.fetchCurrentProfile(
        forceRefresh: forceRefresh,
      ).timeout(_profileRefreshTimeout);
      if (refreshed == null || refreshed.id != userId) return;

      await OfflineProfileStore.save(refreshed);
      if (!mounted || generation != _generation) return;
      setState(() {
        _offlineProfile = refreshed.isActive ? refreshed : null;
        _offlineUserId = userId;
        _restoring = false;
      });
    } catch (_) {
      // При полном отсутствии сети сохранённый профиль остаётся рабочим.
      // Старый auth-контур будет использован только если локального профиля нет.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserRepository.currentUser;
    final profile = _offlineProfile;

    if (_restoring) {
      return const _OfflineBootScreen();
    }

    if (!_mustUseLegacyFlow &&
        user != null &&
        profile != null &&
        profile.isActive &&
        profile.id == user.id &&
        _offlineUserId == user.id) {
      return MainScreen(profile: profile);
    }

    return const legacy.AuthGate();
  }
}

class _OfflineBootScreen extends StatelessWidget {
  const _OfflineBootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
