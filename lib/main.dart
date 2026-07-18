import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_dark_theme.dart';
import 'app/app_theme.dart';
import 'app/premium_depth_theme.dart';
import 'app/premium_scroll_behavior.dart';
import 'app/theme_controller.dart';
import 'navigation/web_back_navigation.dart';
import 'screens/auth_gate.dart';
import 'screens/notifications_screen.dart';
import 'services/push_notification_service.dart';

const String _defaultSupabaseUrl =
    'https://dxbrhsefgxcaxzmrbfrb.supabase.co';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppThemeController.instance.initialize();

  Object? startupError;

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    ).timeout(const Duration(milliseconds: 4500));
  } catch (error) {
    startupError = error;
  }

  if (startupError == null) {
    try {
      await PushNotificationService.initialize().timeout(
        const Duration(milliseconds: 4500),
      );
    } catch (_) {
      // Push работает поверх приложения и не блокирует его запуск.
    }
  }

  runApp(SkbsApp(startupError: startupError));
}

class SkbsApp extends StatefulWidget {
  final Object? startupError;

  const SkbsApp({super.key, this.startupError});

  @override
  State<SkbsApp> createState() => _SkbsAppState();
}

class _SkbsAppState extends State<SkbsApp> {
  @override
  void initState() {
    super.initState();
    PushNotificationService.navigationRequest.addListener(
      _handlePushNavigation,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePushNavigation();
    });
  }

  @override
  void dispose() {
    PushNotificationService.navigationRequest.removeListener(
      _handlePushNavigation,
    );
    super.dispose();
  }

  void _handlePushNavigation() {
    final request = PushNotificationService.takeNavigationRequest();
    if (request == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = appNavigatorKey.currentContext;
      if (context == null || Supabase.instance.client.auth.currentUser == null) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsScreen(
            focusNotificationId: request.notificationId,
          ),
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
          theme: PremiumDepthTheme.apply(AppTheme.light),
          darkTheme: AppDarkTheme.theme,
          themeMode: themeController.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 220),
          themeAnimationCurve: Curves.easeOutCubic,
          home: widget.startupError == null
              ? const AppBrowserBackBridge(child: AuthGate())
              : _StartupErrorScreen(error: widget.startupError!),
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;

  const _StartupErrorScreen({required this.error});

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
                    color: dark
                        ? theme.colorScheme.outline
                        : Colors.white,
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
                      'Закрой приложение и открой снова. Если ошибка повторяется, проверь интернет-соединение.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SelectableText(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
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
