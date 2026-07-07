import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8F9499),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8FA),
          foregroundColor: Color(0xFF1F2328),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1F2328),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
