import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_theme.dart';
import 'app/premium_depth_theme.dart';
import 'app/premium_scroll_behavior.dart';
import 'navigation/web_back_navigation.dart';
import 'screens/auth_gate.dart';

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

  Object? startupError;

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    ).timeout(const Duration(seconds: 15));
  } catch (error) {
    startupError = error;
  }

  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.manrope(),
      GoogleFonts.manrope(fontWeight: FontWeight.w600),
      GoogleFonts.manrope(fontWeight: FontWeight.w700),
      GoogleFonts.manrope(fontWeight: FontWeight.w800),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {
    // При недоступности сервиса шрифтов приложение использует системный fallback.
  }

  runApp(SkbsApp(startupError: startupError));
}

class SkbsApp extends StatelessWidget {
  final Object? startupError;

  const SkbsApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppСтрой',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [AppWebHistoryObserver()],
      scrollBehavior: const PremiumScrollBehavior(),
      theme: PremiumDepthTheme.apply(AppTheme.light),
      home: startupError == null
          ? const AppBrowserBackBridge(child: AuthGate())
          : _StartupErrorScreen(error: startupError!),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final Object error;

  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: Color(0xFF1F2328),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Сервер временно недоступен',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1F2328),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Закрой приложение и открой снова. Если ошибка повторяется, проверь интернет-соединение.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6B7075),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SelectableText(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8A4B46),
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
