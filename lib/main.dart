import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_dark_theme.dart';
import 'app/app_scale_viewport.dart';
import 'app/app_theme.dart';
import 'app/app_typography.dart';
import 'app/premium_depth_theme.dart';
import 'app/premium_scroll_behavior.dart';
import 'app/theme_controller.dart';
import 'navigation/web_back_navigation.dart';
import 'screens/auth_gate.dart';
import 'screens/notifications_screen.dart';
import 'services/push_notification_service.dart';
import 'navigation/app_page_route.dart';

const String _defaultSupabaseUrl = 'https://dxbrhsefgxcaxzmrbfrb.supabase.co';
const String _defaultSupabasePublishableKey =
    'sb_publishable_QBdH-vIQv4F_tVVNc4Ps_w_ssxwSaEm';

const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: _defaultSupabaseUrl,
);
const String supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: _defaultSupabasePublishableKey,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkbsApp());
}

class SkbsApp extends StatefulWidget {
  const SkbsApp({super.key});

  @override
  State<SkbsApp> createState() => _SkbsAppState();
}

class _SkbsAppState extends State<SkbsApp> {
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _pushNavigationScheduled = false;
  bool _isStarting = true;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    PushNotificationService.navigationRequest.addListener(
      _handlePushNavigation,
    );
    unawaited(_initializeApplication());
  }

  Future<void> _initializeApplication() async {
    try {
      await Future.wait<void>([
        initializeDateFormatting('ru_RU'),
        _initializeTheme(),
        _initializeSupabase(),
      ]);
      _attachAuthStateSubscription();
      unawaited(_initializePush());

      if (!mounted) return;
      setState(() {
        _startupError = null;
        _isStarting = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePushNavigation();
      });
    } catch (error) {
      await _disposePartialSupabaseInitialization();
      if (!mounted) return;
      setState(() {
        _startupError = error;
        _isStarting = false;
      });
    }
  }

  Future<void> _initializeTheme() async {
    try {
      await AppThemeController.instance.initialize().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      // Настройки темы не должны удерживать загрузку приложения.
    }
  }

  Future<void> _initializeSupabase() {
    return Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    ).then<void>((_) {});
  }

  Future<void> _initializePush() async {
    try {
      await PushNotificationService.initialize().timeout(
        const Duration(milliseconds: 4500),
      );
      if (!kIsWeb && Supabase.instance.client.auth.currentUser != null) {
        unawaited(
          PushNotificationService.syncForCurrentSession(
            requestPermission: true,
          ),
        );
      }
    } catch (_) {
      // Push работает поверх приложения и не блокирует его запуск.
    }
  }

  Future<void> _disposePartialSupabaseInitialization() async {
    if (!Supabase.instance.isInitialized) return;
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Исходная ошибка запуска важнее ошибки освобождения ресурсов.
    }
  }

  void _attachAuthStateSubscription() {
    if (_authStateSubscription != null) return;
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((authState) {
          if (authState.event == AuthChangeEvent.signedIn ||
              authState.event == AuthChangeEvent.initialSession ||
              authState.event == AuthChangeEvent.userUpdated ||
              authState.event == AuthChangeEvent.tokenRefreshed) {
            _handlePushNavigation();
            unawaited(
              PushNotificationService.syncForCurrentSession(
                requestPermission: !kIsWeb,
              ),
            );
          }
        });
  }

  Future<void> _retryStartup() async {
    if (_isStarting) return;
    setState(() {
      _startupError = null;
      _isStarting = true;
    });
    await _initializeApplication();
  }

  @override
  void dispose() {
    PushNotificationService.navigationRequest.removeListener(
      _handlePushNavigation,
    );
    final authStateSubscription = _authStateSubscription;
    if (authStateSubscription != null) {
      unawaited(authStateSubscription.cancel());
    }
    super.dispose();
  }

  void _handlePushNavigation() {
    if (_isStarting ||
        _startupError != null ||
        _pushNavigationScheduled ||
        PushNotificationService.navigationRequest.value == null) {
      return;
    }

    _pushNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushNavigationScheduled = false;
      if (!mounted || PushNotificationService.navigationRequest.value == null) {
        return;
      }

      final context = appNavigatorKey.currentContext;
      if (context == null) {
        _handlePushNavigation();
        return;
      }
      if (Supabase.instance.client.auth.currentUser == null) {
        // Запрос остаётся ожидающим и будет повторён после восстановления сессии.
        return;
      }

      final request = PushNotificationService.takeNavigationRequest();
      if (request == null) return;

      Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) =>
              NotificationsScreen(focusNotificationId: request.notificationId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeController.instance;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'AppСтрой',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          navigatorObservers: [AppWebHistoryObserver()],
          scrollBehavior: const PremiumScrollBehavior(),
          theme: AppTypography.apply(PremiumDepthTheme.apply(AppTheme.light)),
          darkTheme: AppTypography.apply(AppDarkTheme.theme),
          themeMode: themeController.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 220),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) => AppScaleViewport(
            scale: themeController.uiScale,
            child: child ?? const SizedBox.shrink(),
          ),
          home: _isStarting
              ? const _StartupLoadingScreen()
              : _startupError == null
              ? const AppBrowserBackBridge(child: AuthGate())
              : _StartupErrorScreen(onRetry: _retryStartup),
        );
      },
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    // Временная диагностика: первую Flutter-заставку AppСтрой не рисуем.
    // Сам AppStroyStartupPhase остаётся в проекте и будет возвращён после теста.
    return const Scaffold(body: SizedBox.shrink());
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _StartupErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: dark
                      ? theme.colorScheme.surface.withValues(alpha: 0.96)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: dark ? theme.colorScheme.outline : Colors.white,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.36 : 0.10),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Сервер временно недоступен',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Проверь интернет-соединение и попробуй подключиться ещё раз.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Повторить подключение'),
                      ),
                    ),
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
