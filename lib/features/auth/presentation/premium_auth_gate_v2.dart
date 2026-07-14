import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/main_screen.dart';
import '../../../screens/private_data_import_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../company/presentation/company_onboarding_screen.dart';
import 'set_invitation_password_screen.dart';

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

  int loadToken = 0;
  String? lastLoadedUserId;

  @override
  void initState() {
    super.initState();

    profile = UserRepository.cachedProfile;
    lastLoadedUserId = profile?.id;

    loadCurrentUser(showLoading: profile == null);
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      handleAuthStateChange,
      onError: (_) {
        if (!mounted) return;
        loadCurrentUser(forceRefresh: true, showLoading: profile == null);
      },
    );
  }

  @override
  void dispose() {
    loadToken++;
    authSubscription?.cancel();
    super.dispose();
  }

  void handleAuthStateChange(AuthState state) {
    if (!mounted) return;

    final session = state.session;
    final currentUserId = session?.user.id;

    if (session == null) {
      loadCurrentUser(showLoading: false);
      return;
    }

    final shouldRefresh =
        state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.passwordRecovery ||
        state.event == AuthChangeEvent.tokenRefreshed ||
        currentUserId != lastLoadedUserId ||
        profile == null;

    if (!shouldRefresh && errorText == null) return;

    loadCurrentUser(forceRefresh: shouldRefresh, showLoading: profile == null);
  }

  Future<void> loadCurrentUser({
    bool forceRefresh = false,
    bool showLoading = false,
  }) async {
    final token = ++loadToken;

    try {
      await UserRepository.verifyPendingInvitationLink();
    } catch (error) {
      if (!mounted || token != loadToken) return;
      setState(() {
        profile = null;
        lastLoadedUserId = null;
        errorText = 'Ошибка приглашения: $error';
        isLoading = false;
      });
      return;
    }

    if (!mounted || token != loadToken) return;
    final session = UserRepository.currentSession;

    if (session == null) {
      UserRepository.clearProfileCache();

      if (!mounted || token != loadToken) return;

      setState(() {
        profile = null;
        lastLoadedUserId = null;
        isLoading = false;
        errorText = null;
      });
      return;
    }

    final currentUserId = session.user.id;

    if (!forceRefresh &&
        currentUserId == lastLoadedUserId &&
        profile != null &&
        errorText == null) {
      if (!mounted || token != loadToken) return;
      if (isLoading) setState(() => isLoading = false);
      return;
    }

    if (!mounted || token != loadToken) return;

    setState(() {
      if (showLoading || profile == null) isLoading = true;
      errorText = null;
    });

    try {
      await UserRepository.applyPendingInvitationCompany();
      final loadedProfile = await UserRepository.fetchCurrentProfile(
        forceRefresh: forceRefresh,
      );

      if (!mounted || token != loadToken) return;

      setState(() {
        profile = loadedProfile;
        lastLoadedUserId = currentUserId;
        errorText = null;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted || token != loadToken) return;

      setState(() {
        errorText = 'Ошибка загрузки профиля: $error';
        isLoading = false;
      });
    }
  }

  Future<void> signOut() async {
    UserRepository.clearProfileCache();
    await UserRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = UserRepository.currentSession;
    final currentProfile = profile;

    late final String screenKey;
    late final Widget screen;

    if (isLoading) {
      screenKey = 'loading';
      screen = const SizedBox.expand();
    } else if (session == null) {
      screenKey = 'login';
      screen = LoginScreen(
        onSignedIn: () {
          return loadCurrentUser(forceRefresh: true, showLoading: true);
        },
      );
    } else if (errorText != null) {
      screenKey = 'error';
      screen = _AuthMessageScreen(
        title: 'Ошибка входа',
        message: errorText!,
        icon: Icons.error_outline_rounded,
        actionText: 'Повторить',
        onAction: () {
          loadCurrentUser(forceRefresh: true, showLoading: true);
        },
        secondActionText: 'Выйти',
        onSecondAction: signOut,
      );
    } else if (currentProfile == null) {
      screenKey = 'missing-profile';
      screen = CompanyOnboardingScreen(
        onCompleted: () {
          return loadCurrentUser(forceRefresh: true, showLoading: true);
        },
      );
    } else if (!currentProfile.isActive) {
      screenKey = 'inactive:${currentProfile.id}';
      screen = _AuthMessageScreen(
        title: 'Доступ отключён',
        message: 'Этот пользователь отключён администратором.',
        icon: Icons.lock_outline_rounded,
        actionText: 'Выйти',
        onAction: signOut,
      );
    } else if (UserRepository.mustSetPassword) {
      screenKey = 'invitation-password:${currentProfile.id}';
      screen = SetInvitationPasswordScreen(
        onCompleted: () {
          return loadCurrentUser(forceRefresh: true, showLoading: true);
        },
      );
    } else {
      final importRequested = Uri.base.queryParameters['privateImport'] == '1';

      if (importRequested && !currentProfile.isAdmin) {
        screenKey = 'import-denied:${currentProfile.id}';
        screen = _AuthMessageScreen(
          title: 'Нет доступа',
          message: 'Импорт личных данных доступен только администратору.',
          icon: Icons.admin_panel_settings_outlined,
          actionText: 'Вернуться',
          onAction: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          },
        );
      } else if (importRequested) {
        screenKey = 'private-import:${currentProfile.id}';
        screen = PrivateDataImportScreen(profile: currentProfile);
      } else {
        screenKey =
            'main:${currentProfile.id}:${currentProfile.activeCompanyId}:${currentProfile.role}';
        screen = MainScreen(profile: currentProfile);
      }
    }

    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled ? Duration.zero : AppMotion.page;

    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: AppMotion.regular,
      switchInCurve: AppMotion.enterCurve,
      switchOutCurve: AppMotion.exitCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enterCurve,
          reverseCurve: AppMotion.exitCurve,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.992, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<String>(screenKey), child: screen),
    );
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
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17191C).withValues(alpha: 0.12),
                        blurRadius: 48,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PremiumBrandMark(size: 72, animate: false),
                      const SizedBox(height: 20),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      PremiumActionButton(
                        label: actionText,
                        icon: Icons.arrow_forward_rounded,
                        onPressed: onAction,
                      ),
                      if (secondActionText != null &&
                          onSecondAction != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
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
      ),
    );
  }
}
