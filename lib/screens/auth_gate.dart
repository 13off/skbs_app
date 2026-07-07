import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/user_repository.dart';
import '../models/app_user_profile.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? authSubscription;

  AppUserProfile? profile;

  bool isLoading = true;
  String? errorText;

  int _loadToken = 0;
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();

    loadCurrentUser(showLoading: true);

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      final currentUserId = UserRepository.currentUser?.id;

      if (currentUserId != null &&
          currentUserId == _lastLoadedUserId &&
          profile != null &&
          errorText == null) {
        return;
      }

      loadCurrentUser(showLoading: profile == null);
    });
  }

  @override
  void dispose() {
    _loadToken++;
    authSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadCurrentUser({
    bool forceRefresh = false,
    bool showLoading = false,
  }) async {
    final token = ++_loadToken;
    final session = UserRepository.currentSession;

    if (session == null) {
      UserRepository.clearProfileCache();

      if (!mounted || token != _loadToken) return;

      setState(() {
        profile = null;
        _lastLoadedUserId = null;
        isLoading = false;
        errorText = null;
      });

      return;
    }

    final currentUserId = UserRepository.currentUser?.id;

    if (!forceRefresh &&
        currentUserId != null &&
        currentUserId == _lastLoadedUserId &&
        profile != null &&
        errorText == null) {
      if (!mounted || token != _loadToken) return;

      if (isLoading) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    if (showLoading || profile == null) {
      if (!mounted || token != _loadToken) return;

      setState(() {
        isLoading = true;
        errorText = null;
      });
    } else {
      if (!mounted || token != _loadToken) return;

      setState(() {
        errorText = null;
      });
    }

    try {
      final loadedProfile = await UserRepository.fetchCurrentProfile(
        forceRefresh: forceRefresh,
      );

      if (!mounted || token != _loadToken) return;

      setState(() {
        profile = loadedProfile;
        _lastLoadedUserId = currentUserId;
        errorText = null;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;

      setState(() {
        errorText = 'Ошибка загрузки профиля: $e';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> signOut() async {
    UserRepository.clearProfileCache();
    await UserRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = UserRepository.currentSession;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (session == null) {
      return const LoginScreen();
    }

    if (errorText != null) {
      return _AuthMessageScreen(
        title: 'Ошибка входа',
        message: errorText!,
        icon: Icons.error_outline,
        actionText: 'Повторить',
        onAction: () {
          loadCurrentUser(forceRefresh: true, showLoading: true);
        },
        secondActionText: 'Выйти',
        onSecondAction: () {
          signOut();
        },
      );
    }

    final currentProfile = profile;

    if (currentProfile == null) {
      return _AuthMessageScreen(
        title: 'Профиль не найден',
        message:
            'Пользователь вошёл, но для него нет записи в таблице user_profiles. Добавь профиль в Supabase.',
        icon: Icons.person_off_outlined,
        actionText: 'Обновить',
        onAction: () {
          loadCurrentUser(forceRefresh: true, showLoading: true);
        },
        secondActionText: 'Выйти',
        onSecondAction: () {
          signOut();
        },
      );
    }

    if (!currentProfile.isActive) {
      return _AuthMessageScreen(
        title: 'Доступ отключён',
        message: 'Этот пользователь отключён администратором.',
        icon: Icons.lock_outline,
        actionText: 'Выйти',
        onAction: () {
          signOut();
        },
      );
    }

    return MainScreen(profile: currentProfile);
  }
}

class _AuthMessageScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String actionText;
  final VoidCallback onAction;
  final String? secondActionText;
  final VoidCallback? onSecondAction;

  const _AuthMessageScreen({
    required this.title,
    required this.message,
    required this.icon,
    required this.actionText,
    required this.onAction,
    this.secondActionText,
    this.onSecondAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48, color: const Color(0xFF7B8087)),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2328),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6F747A),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: onAction,
                        child: Text(actionText),
                      ),
                    ),
                    if (secondActionText != null && onSecondAction != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: onSecondAction,
                          child: Text(secondActionText!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
