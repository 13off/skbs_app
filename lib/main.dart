import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_theme.dart';
import 'app/premium_scroll_behavior.dart';
import 'navigation/web_back_navigation.dart';
import 'screens/auth_gate.dart';

const String supabaseUrl = 'https://dxbrhsefgxcaxzmrbfrb.supabase.co';
const String supabasePublishableKey =
    'sb_publishable_QBdH-vIQv4F_tVVNc4Ps_w_ssxwSaEm';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const SkbsApp());
}

class SkbsApp extends StatelessWidget {
  const SkbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppСтрой',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [AppWebHistoryObserver()],
      scrollBehavior: const PremiumScrollBehavior(),
      theme: AppTheme.light,
      home: const AppBrowserBackBridge(child: AuthGate()),
    );
  }
}
